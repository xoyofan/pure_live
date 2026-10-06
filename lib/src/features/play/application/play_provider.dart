/// 播放页编排:播放器单例、快照流与房间播放控制器。
/// 编排规则:解析房间 → 维持选中画质/线路 → 驱动 LivePlayer 开流;
/// 所有竞态用 generation fence 防护,Widget 不直接触碰播放器。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/domains/live/domain/live_input_playback_binder.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/domains/live/data/stream/flv_splice_relay.dart';
import 'package:pure_live/domains/live/data/stream/playback_source_transport.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart' show Sites;
import 'package:pure_live/shared/platforms/live_site.dart' show LivePlayLeaseMetadata;

import '../../../platforms/common/playback/idle_releasing_live_player.dart';
import '../../../platforms/common/playback/live_player.dart';
import '../../../platforms/common/playback/local_stream_proxy.dart';
import '../../../platforms/common/playback/media_kit_live_player.dart';
import '../../../platforms/common/playback/playback_retry.dart';
import '../../../platforms/common/playback/playback_log.dart';
import '../../../shared/application/browse_source.dart';
import '../../../shared/application/providers.dart';
import '../../../app/app_router.dart';
import '../../follow/application/settings_provider.dart';
import 'host_avoidlist.dart';
import 'play_selection.dart';
import 'recovery_lines.dart';
import 'room_volume_provider.dart';

/// 共享播放器上的最新开流操作 token。不同房间的 family controller 共用同一
/// `LivePlayer`，局部 generation 只能保护单个 controller，不能阻止旧房间的
/// open 收尾覆盖新房间；因此在播放器编排层再加一层全局 token。
int _latestPlayerOpenToken = 0;

/// 本地流代理单例:app 启动即 bind 127.0.0.1 随机端口(失败则播放退回
/// mpv 直连,[MediaKitLivePlayer.streamProxy] 对未运行的代理自动降级)。
final streamProxyProvider = Provider<LocalStreamProxy>((ref) {
  final proxy = LocalStreamProxy();
  unawaited(proxy.start());
  ref.onDispose(() => unawaited(proxy.stop()));
  return proxy;
});

/// 播放器单例:app 生命周期内复用,不随页面销毁。
/// dispose 由根 ProviderContainer 统一触发(仅 app 退出时执行)。
final playerProvider = Provider<LivePlayer>((ref) {
  final proxy = ref.watch(streamProxyProvider);
  final player = IdleReleasingLivePlayer(
    createPlayer: () => MediaKitLivePlayer(
      videoHardwareAccelerationEnabled: ref.read(settingsProvider).videoHardwareAcceleration,
      // 单线路源卡顿升级:无内部回退线路时,重开同一死 URL 无意义,早一点
      // re-resolve(换节点 / 降画质)逃出被钉死的链路。实测斗鱼 room9999 的
      // hwa.douyucdn2.cn 断供,旧逻辑拖满 6 次退避阶梯(8→30s)才 re-resolve,
      // 用户被卡 50~90s。开启后最坏等待压到 ~4s 第 2 次重开即升级。
      policy: const PlaybackRetryPolicy(escalateSingleLine: true),
      // 本地流代理:FLV 直链经它转发,URL 预刷新热切换对 mpv 无感
      // (对齐官方桌面端 DySDKController 架构;详见 local_stream_proxy.dart)。
      streamProxy: proxy,
    ),
  );
  ref.listen<bool>(settingsProvider.select((settings) => settings.videoHardwareAcceleration), (_, enabled) {
    if (player case IdleReleasingLivePlayer idlePlayer) {
      final inner = idlePlayer.currentPlayer;
      if (inner case final VideoHardwareAccelerationAware aware) {
        aware.setVideoHardwareAcceleration(enabled);
      }
    }
  });
  ref.onDispose(player.dispose);
  return player;
});

/// 播放快照流:控制条/舞台 overlay 用它驱动 UI。
final playerSnapshotProvider = StreamProvider<PlayerSnapshot>((ref) => ref.watch(playerProvider).snapshots);

/// 播放控制器入参:(site, roomId)。
typedef PlayParams = ({String site, String roomId});

/// 播放页状态:解析结果 + 选中画质/线路 + 代际计数。
class PlayState {
  const PlayState({this.payload, this.quality, this.line, this.generation = 0, this.showDanmaku = true});

  final RoomPayload? payload;
  final StreamQuality? quality;
  final StreamLine? line;

  /// 代际计数:切房/重解析/切换画质或线路时 +1,
  /// 旧异步回调回来后 generation 不匹配即丢弃。
  final int generation;

  /// 舞台弹幕叠加层开关:由控制条/快捷键切换,舞台据此挂载 overlay。
  final bool showDanmaku;

  /// fixture 数据不进真实播放器,舞台显示占位。
  bool get isFixture => payload?.source == 'fixture';

  PlayState copyWith({
    RoomPayload? payload,
    StreamQuality? quality,
    StreamLine? line,
    int? generation,
    bool? showDanmaku,
  }) {
    return PlayState(
      payload: payload ?? this.payload,
      quality: quality ?? this.quality,
      line: line ?? this.line,
      generation: generation ?? this.generation,
      showDanmaku: showDanmaku ?? this.showDanmaku,
    );
  }
}

/// 播放页控制器:family by (site, roomId);autoDispose 随页面离开释放状态,
/// 但全局播放器实例不在此销毁。
final playControllerProvider = AsyncNotifierProvider.autoDispose.family<PlayController, PlayState, PlayParams>(
  PlayController.new,
);

/// 后台预取的档位上限、并发数与首批错开间隔。
///
/// 预取是「锦上添花」:首档已可播,其余档位慢几秒无感;但若不限速,它会与
/// 起播/切房争抢代理连接(2026-09-21 Twitch 卡慢的成因)。上限之外的档位
/// 仍可点击 —— 切档时按需解析。
///
/// 并发 2:斗鱼/B站/YY/SOOP 每档 1~2 个请求,串行会把 4 档拖到 4~6s;
/// 并发 2 约减半,再高就会抢首帧带宽。
const int kPrefetchQualityLimit = 4;
const int kPrefetchConcurrency = 2;
const Duration kPrefetchStagger = Duration(milliseconds: 800);

class PlayController extends AsyncNotifier<PlayState> {
  PlayController(this.params);

  final PlayParams params;

  int _generation = 0;

  /// owned-input 播放配方开出的活座位(niconico 等)。同一时刻至多一个:
  /// 新座位接管前先 close 旧座位;provider 离场经 [ref.onDispose] 兜底释放,
  /// 防止座位(websocket keepalive/本地中继)泄漏。
  PlaybackInputLease? _ownedLease;
  bool _ownedLeaseDisposerInstalled = false;

  /// 开 owned-input 座位并把本地中继地址包装成可开线路。返回 null 表示
  /// 配方不可得/代际已过期——调用方回落 open_skip。
  Future<StreamLine?> _openOwnedInput(OwnedInputResolver? resolver, String? preferredQuality, int generation) async {
    if (resolver == null) return null;
    if (!_ownedLeaseDisposerInstalled) {
      _ownedLeaseDisposerInstalled = true;
      ref.onDispose(() {
        final lease = _ownedLease;
        _ownedLease = null;
        unawaited(lease?.close());
      });
    }
    try {
      final recipe = await resolver
          .resolveOwnedInputRecipe(site: params.site, roomIdOrUrl: params.roomId, preferredQuality: preferredQuality)
          .timeout(const Duration(seconds: 45));
      if (recipe == null || !ref.mounted || generation != _generation) return null;
      // 播放策略 = purelive 绑定:配方 → OwnedPlaybackSource → 座位/本地中继。
      final lease = await bindLiveInputForPlayback(recipe)
          .createInput(CancelToken())
          .timeout(const Duration(seconds: 30));
      if (!ref.mounted || generation != _generation) {
        unawaited(lease.close());
        return null;
      }
      final previous = _ownedLease;
      _ownedLease = lease;
      unawaited(previous?.close());
      PlaybackLog.write('owned_seat_open', {
        'site': params.site,
        'room': params.roomId,
        'recipe': recipe.identity,
        'uri_host': lease.uri.host,
      });
      return StreamLine(name: '配方线路', format: 'hls', url: lease.uri.toString(), headers: const {});
    } catch (error) {
      PlaybackLog.write('owned_seat_fail', {
        'site': params.site,
        'room': params.roomId,
        'reason': '$error'.substring(0, '$error'.length > 120 ? 120 : '$error'.length),
      });
      return null;
    }
  }

  /// 用户手动切档后的偏好覆盖(懒取流):切换到的档位若未预取线路,以此档
  /// 重新解析,解析侧只取该档,避免整房全档取流。
  String? _qualityOverride;

  /// 后台预取到的档位线路,切档时优先复用。
  final Map<String, StreamQuality> _prefetchedQualities = {};

  /// 预取代际:只在「重新解析房间」(build/retry)时推进。
  ///
  /// 不能复用 [_generation]:切画质/切线路都会推进它,那会把还在跑的
  /// 后台预取全部作废(用户口径 2026-09-21:其他线路必须后台加载完)。
  int _prefetchToken = 0;

  /// 死节点负缓存(host → 失败 epoch ms),磁盘加载、逃离时写入。
  /// 见 [host_avoidlist.dart]:跨重启避让首撞死节点。
  Map<String, int>? _hostAvoidlist;

  /// URL 寿命预刷新计时器:在流 URL 的 `expire`(斗鱼实测 300s)到点前
  /// 主动重签,消除"token 过期 → CDN reset → 卡顿 → 升级换线"的整段
  /// 被动恢复。任何一次 open 成功后按新 URL 重新排期。

  Map<String, int> _loadHostAvoidlist({bool refresh = false}) {
    final cached = _hostAvoidlist;
    if (!refresh && cached != null) {
      return pruneHostAvoidlist(cached, nowMs: _nowMs());
    }
    Map<String, int> loaded = {};
    try {
      loaded = decodeHostAvoidlist(File(hostAvoidlistFilePath()).readAsStringSync());
    } catch (_) {
      // 读不到/读失败:按无负缓存处理,不影响正常选线。
    }
    return _hostAvoidlist = loaded;
  }

  /// 逃离死节点:记录失败 host 并异步落盘(乐观记录,口径见库文档)。
  void _avoidFailedHost(String? failedUrl) {
    final host = Uri.tryParse(failedUrl ?? '')?.host ?? '';
    if (host.isEmpty) return;
    final avoidlist = _loadHostAvoidlist()..[host] = _nowMs();
    _hostAvoidlist = avoidlist;
    PlaybackLog.write('host_avoid_recorded', {'host': host});
    unawaited(() async {
      try {
        final file = File(hostAvoidlistFilePath());
        await file.parent.create(recursive: true);
        await file.writeAsString(encodeHostAvoidlist(pruneHostAvoidlist(avoidlist, nowMs: _nowMs())));
      } catch (error) {
        PlaybackLog.write('host_avoid_persist_error', {'error': '$error'});
      }
    }());
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  FutureOr<PlayState> build() async {
    final generation = ++_generation;
    final prefetchToken = ++_prefetchToken;
    // 离开播放页(autoDispose 触发)→ 停止全局播放器:直播不得在后台继续出声/出画。
    // 仅卸载媒体源,不 dispose 实例(下次进房复用同一 Player)。捕获实例而非在
    // 回调里 ref.read,避免 provider 销毁期再去读依赖。
    final player = ref.read(playerProvider);
    final token = player is IdleReleasingLivePlayer ? player.enterRoom() : null;
    ref.onDispose(() {
      // 先注销恢复回调再 stop:回调是播放器持有的**指向本 controller** 的活引用,
      // autoDispose 后播放器仍可能在自动重连里调用它,而那时 ref/state 已失效
      // (`_recoverLines` 读 state 会报 “Cannot use Ref after dispose”)。
      // 回调只能在本层注销 —— 播放器不知道宿主已离场。
      if (player is IdleReleasingLivePlayer && token != null) {
        player.clearLineRecovery(token);
        player.clearLeaseRelay(token);
      } else if (player case LineRecoveryAware aware) {
        aware.setLineRecovery(null);
      }
      final stopWatch = Stopwatch()..start();
      final fields = <String, Object?>{'site': params.site, 'room': params.roomId};
      PlaybackLog.writeResourceSample('room_release_start', fields);
      if (token != null && player is IdleReleasingLivePlayer) {
        unawaited(
          player.leaveRoom(token).whenComplete(() {
            stopWatch.stop();
            PlaybackLog.writeResourceSample('room_release_end', {
              ...fields,
              'elapsed_ms': stopWatch.elapsedMilliseconds,
            });
          }),
        );
      } else {
        unawaited(_stopAndSampleRelease(player, stopWatch, fields));
      }
    });
    // 数据源端口变化(G1 换真实解析)时自动重建,Widget 无感。
    final source = ref.watch(roomSourceProvider);
    // 默认画质:平台单独配置 > 平台默认档 > 全平台默认(设置页可改)。
    // select 以「该平台生效值」为 key,只有它变化才重建本 family;
    // 房间缺该档时 _pickQuality 回退 streams.first(「没有才退」)。
    final settingsQuality = ref.watch(
      settingsProvider.select((settings) => settings.effectiveDefaultQuality(params.site)),
    );
    // 线路格式偏好(auto/hls/flv):设置页可改,进房/重解析时都按它选线。
    final preferredFormat = ref.watch(settingsProvider.select((settings) => settings.preferredLineFormat.value));
    final preferredQuality = _qualityOverride ?? StartupRoute.qualityOverride ?? settingsQuality;
    final resolveWatch = Stopwatch()..start();
    // 整链截止(2026-09-29 斗鱼网络故障实测):半开连接(TCP 通、响应永不到)
    // 下单请求超时可能不触发,build 会无限 await —— 页面既不出错也不重试,
    // 表现为"冻住"。45s 上限兜底:超时按解析失败处理,回到错误/重试路径,
    // 重试循环得以在网络恢复前持续存活。解析包内部超时不受影响,先到先抛。
    final RoomPayload payload;
    try {
      payload = await source
          .resolveRoom(site: params.site, roomIdOrUrl: params.roomId, preferredQuality: preferredQuality)
          .timeout(const Duration(seconds: 45));
    } catch (error) {
      PlaybackLog.write('resolve_fail', {
        'site': params.site,
        'room': params.roomId,
        'reason': error is TimeoutException ? 'deadline_45s' : '$error',
      });
      // 解析失败自动重试(2026-09-29 斗鱼故障期实测):此前重试由间接触发,
      // 会静默停摆 —— 页面停在错误态直到用户手动刷新,「网络恢复自动起播」
      // 不可达。这里失败后自排 20s 重试(代际守卫:被新指令顶掉即让位),
      // 与既有自动重连节奏一致;错误卡片 UI 照常展示。
      unawaited(
        Future<void>.delayed(const Duration(seconds: 20)).then((_) {
          if (ref.mounted && generation == _generation) ref.invalidateSelf();
        }),
      );
      rethrow;
    }
    resolveWatch.stop();
    // 进房解析耗时落盘:此前只有失败才有日志,"打开慢"缺的正是这段度量。
    // qualities 顺带落档位清单(2026-09-29):控制栏画质菜单渲染
    // availableQualities,巡检不截屏也能从日志核对"多档是否解析出来"
    // (B 站中小房常只有原画单档,是服务端事实,不是解析缺档)。
    PlaybackLog.write('resolve_ms', {
      'ms': resolveWatch.elapsedMilliseconds,
      'site': params.site,
      'room': params.roomId,
      'qualities': [for (final option in payload.availableQualities) option.name].join(','),
      'streams': payload.streams.length,
    });

    // generation fence:等待期间出现了更新的代际(retry 等),丢弃本次结果。
    if (generation != _generation) {
      return state.value ?? PlayState(generation: generation);
    }
    // 离场 fence(2026-10-03 切房竞态):控制器已被 autoDispose(切房
    // pushReplacement)时,迟到的解析结果不得继续驱动共享播放器——
    // 此前依赖"dispose 后碰 state 抛错"的隐式兜底,显式短路更稳。
    if (!ref.mounted) {
      PlaybackLog.write('resolve_discarded', {
        'site': params.site,
        'room': params.roomId,
        'reason': 'controller_disposed',
      });
      return state.value ?? PlayState(generation: generation);
    }
    final quality = _pickPlayableQuality(payload, preferredQuality);
    // 传入 site:白名单站点 auto 起播优选 FLV(首帧提速,见 play_selection)。
    final picked = pickStreamLine(quality, preferredFormat, site: params.site);
    // 自动进房选线避开负缓存内的死节点(只作用于自动选线;用户手动切线/切档
    // 不经过这里,2026-09-26「不偷换用户线路」口径不受影响)。
    final line = avoidFlaggedLine(picked, quality?.lines ?? const [], _loadHostAvoidlist(), nowMs: _nowMs());
    if (picked != null && line != picked) {
      PlaybackLog.write('host_avoid_applied', {
        'from': Uri.tryParse(picked.url)?.host,
        'to': Uri.tryParse(line?.url ?? '')?.host,
      });
    }
    final next = PlayState(payload: payload, quality: quality, line: line, generation: generation);

    if (!next.isFixture && line != null) {
      // 开流不阻塞状态落地;错误经快照流呈现在舞台 overlay。
      // 同画质其余线路作回退送进播放器,断流时 mpv 自动跳下一条(pure_live 式)。
      // 必须走 _open:首次进房就要装上恢复回调,否则签名平台地址过期后,
      // 播放器在放弃分支拿不到"重新解析"的新地址。
      _open(line, _fallbackLines(quality, line));
      // 首帧落地后才预取其他画质(pure_live 进房不做任何预取):开流握手的
      // 1~3s 是最敏感窗口,此刻并发补档会与它抢带宽,表现为「打开很慢」。
      unawaited(_prefetchAfterFirstFrame(payload, source, prefetchToken));
    } else if (!next.isFixture) {
      // 解析成功但选不出可开线路:owned-input 平台(niconico/bigo/fc2)的
      // getPlayUrls 有意返回空,取流走 purelive 播放绑定(配方→座位→本地
      // 中继,2026-10-02 用户口径「播放策略用 purelive 的」)。配方不可得时
      // 落 open_skip 供诊断归因(此前完全静默)。
      final ownedLine = await _openOwnedInput(ref.watch(ownedInputProvider), preferredQuality, generation);
      if (ownedLine != null && !next.isFixture && generation == _generation && ref.mounted) {
        // owned 输入无并行回退线路(单座位);断流走既有恢复链 → 重解析 →
        // 本分支重开新座位。预取对配方平台无意义(档位无 URL),不触发。
        _open(ownedLine, const []);
      } else if (generation == _generation) {
        PlaybackLog.write('open_skip', {
          'site': params.site,
          'room': params.roomId,
          'qualities': payload.availableQualities.length,
          'streams': payload.streams.length,
        });
      }
    }
    return next;
  }

  /// 离房后等全局播放器真正卸载旧源,再落一条释放后 RSS 样本。
  Future<void> _stopAndSampleRelease(LivePlayer player, Stopwatch stopWatch, Map<String, Object?> fields) async {
    try {
      await player.stop();
    } catch (error) {
      PlaybackLog.writeResourceSample('room_release_error', {...fields, 'error': error});
    } finally {
      stopWatch.stop();
      PlaybackLog.writeResourceSample('room_release_end', {...fields, 'elapsed_ms': stopWatch.elapsedMilliseconds});
    }
  }

  /// 等首个出帧事件后再启动画质预取。
  ///
  /// 保留本仓「切画质即开」的能力,但把时机推到首帧之后 —— 参考实现
  /// (pure_live)在进房时根本不预取,先帧优先是它开流快的一个原因。
  /// 首帧迟迟不来(15s 超时)则放弃预取:首帧都没来,切画质本就走懒取流。
  Future<void> _prefetchAfterFirstFrame(RoomPayload payload, RoomSource source, int prefetchToken) async {
    final player = ref.read(playerProvider);
    try {
      await player.snapshots
          .firstWhere((snapshot) => snapshot.playing && !snapshot.buffering)
          .timeout(const Duration(seconds: 15));
    } on Object {
      return; // 超时 / 流关闭:放弃预取,不阻塞任何路径。
    }
    if (prefetchToken != _prefetchToken || !ref.mounted) return;
    unawaited(_prefetchQualities(payload, source, prefetchToken));
  }

  Future<void> _prefetchQualities(RoomPayload initial, RoomSource source, int prefetchToken) async {
    // 待补档位:只选「确实缺线路」的档,超出上限的记录跳过原因。
    // 判定用精确同名(pendingPrefetchQualities),不能用 qualityByName ——
    // 它未命中时回退首档,缺失档会被误判成已解析,预取队列恒空。
    final targets = <QualityOption>[];
    for (final option in pendingPrefetchQualities(initial, _prefetchedQualities)) {
      if (targets.length >= kPrefetchQualityLimit) {
        PlaybackLog.write('prefetch_skip', {
          'site': params.site,
          'room': params.roomId,
          'quality': option.name,
          'reason': 'limit',
        });
        continue;
      }
      targets.add(option);
    }
    if (targets.isEmpty) return;

    // 只错开一次:让首帧先落地,随后并发补档(逐档 600ms 串行会把 4 档拖到
    // 4~6s;并发 2 约减半,又不至于抢首帧带宽)。
    await Future<void>.delayed(kPrefetchStagger);
    if (prefetchToken != _prefetchToken || !ref.mounted) return;

    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= targets.length) return;
        if (prefetchToken != _prefetchToken || !ref.mounted) return;
        await _prefetchOne(targets[index], source, prefetchToken);
      }
    }

    await Future.wait([for (var i = 0; i < kPrefetchConcurrency; i++) worker()]);
  }

  /// 补一个档位的线路并合并回当前 payload。
  Future<void> _prefetchOne(QualityOption option, RoomSource source, int prefetchToken) async {
    final startedAt = DateTime.now();
    PlaybackLog.write('prefetch_start', {'site': params.site, 'room': params.roomId, 'quality': option.name});
    try {
      final fetchedPayload = await source.resolveRoom(
        site: params.site,
        roomIdOrUrl: params.roomId,
        preferredQuality: option.name,
      );
      if (prefetchToken != _prefetchToken || !ref.mounted) return;
      final fetched = fetchedPayload.qualityByName(option.name);
      if (fetched == null || fetched.lines.isEmpty) {
        PlaybackLog.write('prefetch_empty', {
          'site': params.site,
          'room': params.roomId,
          'quality': option.name,
          'ms': DateTime.now().difference(startedAt).inMilliseconds,
        });
        return;
      }
      _prefetchedQualities[option.name] = fetched;
      PlaybackLog.write('prefetch_ok', {
        'site': params.site,
        'room': params.roomId,
        'quality': option.name,
        'lines': fetched.lines.length,
        'ms': DateTime.now().difference(startedAt).inMilliseconds,
      });
      final current = state.value;
      final currentPayload = current?.payload;
      if (current == null || currentPayload == null) return;
      final merged = mergeResolvedStream(currentPayload.streams, fetched);
      state = AsyncData(
        current.copyWith(
          payload: currentPayload.copyWith(streams: merged, fetchedAt: fetchedPayload.fetchedAt),
        ),
      );
    } catch (error) {
      // 后台预取失败不影响当前播放;用户切档时仍按需解析。
      PlaybackLog.write('prefetch_fail', {
        'site': params.site,
        'room': params.roomId,
        'quality': option.name,
        'error': error,
        'ms': DateTime.now().difference(startedAt).inMilliseconds,
      });
    }
  }

  /// 切换画质:预取完成时直接开流;否则按需重新解析。
  void switchQuality(StreamQuality quality) {
    final current = state.value;
    if (current == null || current.payload == null) return;
    final effectiveQuality = _prefetchedQualities[quality.name] ?? quality;
    final line = pickStreamLine(
      effectiveQuality,
      ref.read(settingsProvider).preferredLineFormat.value,
      site: params.site,
    );
    if (line == null) {
      _qualityOverride = quality.name;
      ref.invalidateSelf();
      return;
    }
    final generation = ++_generation;
    state = AsyncData(current.copyWith(quality: effectiveQuality, line: line, generation: generation));
    _open(line, _fallbackLines(effectiveQuality, line));
  }

  /// 同画质内切换线路。
  void switchLine(StreamLine line) {
    final current = state.value;
    if (current == null || current.payload == null) return;
    final generation = ++_generation;
    state = AsyncData(current.copyWith(line: line, generation: generation));
    _open(line, _fallbackLines(current.quality, line));
  }

  /// 切换舞台弹幕叠加层显隐(纯展示开关,不重开流、不换代际)。
  void toggleDanmaku() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(showDanmaku: !current.showDanmaku));
  }

  /// 重试:解析失败 → 整体重解析;播放失败 → 重开当前线路。
  void retry() {
    final current = state.value;
    if (current != null && current.payload == null) {
      ref.invalidateSelf();
      return;
    }
    final generation = ++_generation;
    // 整体重解析:旧一批预取线路已与当前 payload 脱钩,作废。
    _prefetchToken++;
    if (current != null) {
      state = AsyncData(current.copyWith(generation: generation));
    }
    _openSelected();
  }

  /// 用最新代际把选中线路(连同同画质回退线路)送进播放器。
  void _openSelected() {
    final current = state.value;
    final line = current?.line;
    if (current == null || current.isFixture || line == null) return;
    _open(line, _fallbackLines(current.quality, line));
  }

  /// 统一开流入口:确保播放器已装上「恢复重解析」回调再开流。
  ///
  /// 回调只能由编排层提供 —— 自动重连是播放器内部看门狗驱动的,编排层无法
  /// 感知"它已耗尽上限"。装上后,播放器在放弃前会回头向本层要一份**重新
  /// 解析**的地址(签名平台地址此时多半已过期,复用旧地址=无限重开失效源)。
  ///
  void _open(StreamLine line, List<StreamLine> fallbacks) {
    final player = ref.read(playerProvider);
    final openToken = ++_latestPlayerOpenToken;
    // LineRecoveryAware 不是 LivePlayer 的子类型,is 探测不产生类型提升,
    // 用 if-case 对象模式探测并绑定(免显式 as)。
    if (player case LineRecoveryAware aware) {
      aware.setLineRecovery(_recoverLines);
    }
    // 播放策略=purelive(2026-10-06 口径:播放策略完全对齐上游, fork 只留
    // UI):租约 FLV(斗鱼匿名原画 expire=300 等)交上游 FlvSpliceRelay
    // 服务——到点前双连接重签、关键帧对齐交接,不回读不跳段。
    if (player is IdleReleasingLivePlayer) {
      player.setLeaseRelayFactory(_createLeaseRelay);
    } else if (player case LeaseRelayAware relayAware) {
      relayAware.setLeaseRelayFactory(_createLeaseRelay);
    }
    unawaited(_openAndApplyVolume(player, line, fallbacks, _generation, openToken));
  }

  /// 开流前后套用本房间音量,不改变 pure_live 的线路选择和开流顺序。
  Future<void> _openAndApplyVolume(
    LivePlayer player,
    StreamLine line,
    List<StreamLine> fallbacks,
    int generation,
    int openToken,
  ) async {
    // 音量套用不阻塞开流(对齐 pure_live:进房先开流):mpv 的 volume 是
    // 进程级属性,通常先于首帧音频落地;开流后再补一次,校正快照与迟到回流。
    unawaited(_applyRoomVolume(player));
    await player.open(line, fallbacks);
    if (!ref.mounted || generation != _generation || openToken != _latestPlayerOpenToken) {
      return;
    }
    // 轮播房起播偏移(2026-10-03):payload.startAtMs>0 时开流成功后 seek 一次,
    // 从循环稿件已播位置接着看(上游 4-5 步卡在其播放层无 seek,zishu 的
    // media_kit 有 Seekable 能力,补全整链)。控制器按房间 family 生成,
    // 成员位即"每房间一次"——切画质/线路不回跳,换房新控制器自然重置。
    await _applyStartOffset(player);
    await _applyRoomVolume(player);
    // 租约预刷新排期(2026-10-03):斗鱼等平台 URL 带寿命(原画实测 300s),
    // 到点服务端断连——此前只能走事后恢复链(热切拼接处会重读一小段,且
    // 误把正常节点记入负缓存)。改为到期前主动重签热切,连接不断。
    _scheduleLeaseRefresh(player, line, generation);
  }

  /// URL 租约预刷新计时器。
  Timer? _leaseRefreshTimer;

  /// 当前房间的租约元数据(站点实现了 LivePlayLeaseMetadata 才有)。
  /// LivePlayLeaseMetadata 与 LiveSite 是平行能力接口(无子型关系),is 不会
  /// 类型提升,需显式 as(与 HEAD 既有写法一致)。
  LivePlayLeaseMetadata? _leaseMetadata() {
    final liveSite = Sites.of(params.site).liveSite;
    return liveSite is LivePlayLeaseMetadata ? liveSite as LivePlayLeaseMetadata : null;
  }

  /// 租约中继工厂(播放器经 [LeaseRelayAware] 在 open 时调用):门控对齐
  /// 上游 [FlvSpliceRelay.appliesTo]——URL 自报寿命(expire)且为 http(s)
  /// FLV 直链(斗鱼匿名原画)才走中继;虎牙式"URL 过期但连接不断"、HLS、
  /// 非租约线路一律返回 null,回落本地代理会话。中继续租见
  /// [_renewLeaseSource];站点 CDN 头与网络代理指令随闭包带齐。
  Future<FlvSpliceRelay?> _createLeaseRelay(StreamLine line) async {
    if (!ref.mounted || line.format != 'flv') return null;
    final lease = _leaseMetadata();
    if (lease == null) return null;
    final refreshAt = lease.getPlayUrlRefreshAt(line.url);
    if (!FlvSpliceRelay.appliesTo(line.url, refreshAt: refreshAt)) return null;
    try {
      final relay = await FlvSpliceRelay.start(
        FlvLeasedSource(Uri.parse(line.url), refreshAt: refreshAt),
        renew: _renewLeaseSource,
        headers: line.headers,
        findProxy: (uri) => UpstreamProxy.needsProxy(uri.host) ? 'PROXY ${UpstreamProxy.hostPort}' : 'DIRECT',
      );
      PlaybackLog.write('proxy_relay_wrap', {
        'site': params.site,
        'room': params.roomId,
        'host': Uri.tryParse(line.url)?.host,
        'refresh_at': refreshAt?.toIso8601String(),
      });
      return relay;
    } catch (error) {
      PlaybackLog.write('proxy_relay_fail', {
        'site': params.site,
        'room': params.roomId,
        'host': Uri.tryParse(line.url)?.host,
        'reason': '$error',
      });
      return null;
    }
  }

  /// 中继到点续租:走恢复重解析。节点轮换不是故障(recordAvoid=false,
  /// 不污染负缓存)、尽量同节点只换 token(keepCurrentHost=true);失败
  /// 抛错 → 中继保旧连接继续流,到点切断终结本地流,交回播放器既有恢复链。
  Future<FlvLeasedSource> _renewLeaseSource(FlvLeasedSource current) async {
    final lines = await _recoverLines(recordAvoid: false, keepCurrentHost: true);
    final flv = lines.where((candidate) => candidate.format == 'flv').firstOrNull;
    if (flv == null) {
      throw StateError('renew resolved no flv line for ${params.roomId}');
    }
    final refreshAt = _leaseMetadata()?.getPlayUrlRefreshAt(flv.url);
    PlaybackLog.write('proxy_relay_renewed', {
      'site': params.site,
      'room': params.roomId,
      'host': Uri.tryParse(flv.url)?.host,
      'refresh_at': refreshAt?.toIso8601String(),
    });
    // 重解析给出的地址若不再自报寿命(如登录态),免续租直连到自然断流。
    return FlvLeasedSource(Uri.parse(flv.url), refreshAt: refreshAt);
  }

  /// 站点自报的刷新时点([LivePlayLeaseMetadata.getPlayUrlRefreshAt])到点前
  /// 主动重签:recordAvoid=false(节点轮换不是故障)、keepCurrentHost=true
  /// (同节点只换 token),首线路仍为 FLV 时经本地代理热切,mpv 无感。
  /// 不可热切(HLS/无代理)时静默放弃,退回既有事后恢复链兜底。
  void _scheduleLeaseRefresh(LivePlayer player, StreamLine line, int generation) {
    _leaseRefreshTimer?.cancel();
    _leaseRefreshTimer = null;
    if (generation != _generation) return;
    try {
      final lease = _leaseMetadata();
      if (lease == null) return;
      final refreshAt = lease.getPlayUrlRefreshAt(line.url);
      if (refreshAt == null) return;
      // 租约 FLV 已交 FlvSpliceRelay 自管续租(双连接+关键帧对齐交接,
      // 门控同 [_createLeaseRelay]),这里不再双排期;本计时器只兜
      // HLS 等不可中继的租约形态。
      if (FlvSpliceRelay.appliesTo(line.url, refreshAt: refreshAt)) return;
      var delay = refreshAt.difference(DateTime.now());
      if (delay <= const Duration(seconds: 3)) return; // 已贴脸:事后链兜底
      if (delay > const Duration(minutes: 10)) delay = const Duration(minutes: 10);
      _leaseRefreshTimer = Timer(delay, () async {
        if (!ref.mounted || generation != _generation) return;
        final lines = await _recoverLines(recordAvoid: false, keepCurrentHost: true);
        if (lines.isEmpty || generation != _generation) return;
        final first = lines.first;
        if (first.format != 'flv' || player is! MediaKitLivePlayer) return;
        final switched = await (player as MediaKitLivePlayer).hotSwitchUpstream(first.url);
        PlaybackLog.write(switched ? 'lease_refresh_ok' : 'lease_refresh_skip', {
          'site': params.site,
          'room': params.roomId,
        });
        if (switched) {
          // 新地址落回状态(用户随后切档/切线用的才是同一批),并按新 URL 再排期。
          final current = state.value;
          final quality = current?.quality;
          if (current != null && quality != null) {
            state = AsyncData(
              current.copyWith(
                quality: StreamQuality(name: quality.name, rate: quality.rate, lines: lines),
                line: first,
                generation: generation,
              ),
            );
          }
          _scheduleLeaseRefresh(player, first, generation);
        }
      });
    } catch (_) {
      // 排期失败不影响播放:事后恢复链兜底。
    }
  }

  /// 本控制器(=本房间)是否已完成起播偏移。
  bool _startOffsetApplied = false;

  Future<void> _applyStartOffset(LivePlayer player) async {
    if (_startOffsetApplied) return;
    final offsetMs = state.value?.payload?.startAtMs ?? 0;
    if (offsetMs <= 0) return;
    final Seekable? seekable = player is Seekable ? player as Seekable : null;
    if (seekable == null) return;
    _startOffsetApplied = true;
    try {
      await seekable.seekTo(Duration(milliseconds: offsetMs));
    } catch (_) {
      // 点播式源偶发 seek 失败(分片未就绪):放弃本次偏移,从 0 播不致命。
      _startOffsetApplied = false;
    }
  }

  /// 把本房间的有效音量套到播放器。
  ///
  /// 全局静音走 [LivePlayer.setMuted](让控制条的静音图标同步点亮),其余情况
  /// 直接给音量 —— `setVolume(>0)` 本身就会解除会话内静音(见实现层)。
  Future<void> _applyRoomVolume(LivePlayer player) async {
    final decision = ref.read(roomVolumeProvider(params));
    if (decision.globalMuted) {
      await player.setMuted(true);
      return;
    }
    await player.setVolume(decision.volume);
  }

  /// 播放器请求恢复:重新解析当前房间,返回选中画质的**全新**线路。
  ///
  /// 故意走 [RoomRecoverer](绕开短缓存)而非 `resolveRoom` —— 后者可能命中
  /// 60s 短缓存,把过期地址原样交回去。非真实解析源(fixture)或解析异常时
  /// 返回空列表,由播放器走放弃分支给出终局建议。
  ///
  /// [recordAvoid] 控制"逃离 host 落负缓存":故障恢复路径(默认)记录;
  /// URL 预刷新([_refreshUrlBeforeExpire])传 false —— 预刷新换 host 是服务端
  /// 正常轮换边缘节点(2026-09-28 实测 scdn 池 -160/-187/-242 随机分配),
  /// 不是旧节点故障,记入会把整个 scdn 池逐个污染进负缓存。
  ///
  /// [keepCurrentHost] 控制 brother 线路排序:预刷新传 true(保持当前节点,
  /// 见 [refreshedLinesFor]);故障恢复默认 false(逃离死节点)。
  Future<List<StreamLine>> _recoverLines({bool recordAvoid = true, bool keepCurrentHost = false}) async {
    // 宿主已离场(autoDispose)时一律拒答:下面要读 state,而销毁后读会抛错。
    // 回调注销是主动防护,这里再兜一道 —— 注销与调用之间存在竞态窗口。
    if (!ref.mounted) return const [];
    final current = state.value;
    final source = ref.read(roomSourceProvider);
    final quality = current?.quality;
    if (current == null || current.payload == null || source is! RoomRecoverer) {
      PlaybackLog.write('resolve_skip', {
        'site': params.site,
        'room': params.roomId,
        'reason': current == null || current.payload == null ? 'no_state' : 'source_unaware',
      });
      return const [];
    }
    try {
      final payload = await source.recoverRoom(
        site: params.site,
        roomIdOrUrl: params.roomId,
        preferredQuality: quality?.name,
      );
      if (!ref.mounted) return const [];
      // 档位回退用进房同口径(占位档回退首个有线路的档):主播切推流画质后
      // 原档名消失,`pickPlayQuality` 只按名字回退首档,懒取流下首档常是
      // 空线路占位 → `no_line` → give_up(2026-09-28 真机 00:37 实测)。
      final next = _pickPlayableQuality(payload, quality?.name);
      final line = pickStreamLine(next, ref.read(settingsProvider).preferredLineFormat.value, site: params.site);
      if (line == null) {
        PlaybackLog.write('resolve_fail', {'site': params.site, 'room': params.roomId, 'reason': 'no_line'});
        return const [];
      }
      // 全部兄弟线路:故障恢复逃离死节点(keepCurrentHost=false,默认);
      // URL 预刷新保持当前节点只换 token(keepCurrentHost=true,服务端轮换
      // 边缘不是故障,逃逸排序会让短 TTL 流在节点池里 ping-pong)。
      final recovery = keepCurrentHost ? refreshedLinesFor(next, current.line) : recoveryLinesFor(next, current.line);
      // 故障恢复成功逃离到不同 host:把死节点记入负缓存,后续进房/重启
      // 不再首撞它(乐观记录,口径见 host_avoidlist.dart)。预刷新路径
      // (recordAvoid=false)不记:那是服务端正常轮换,不是旧节点故障。
      final escapedHost = Uri.tryParse(current.line?.url ?? '')?.host ?? '';
      final recoveryHost = Uri.tryParse(recovery.firstOrNull?.url ?? '')?.host ?? '';
      if (recordAvoid && escapedHost.isNotEmpty && recoveryHost.isNotEmpty && recoveryHost != escapedHost) {
        _avoidFailedHost(current.line?.url);
      }
      // 新地址落回状态:用户随后手动切线路 / 切档时用的才是同一批,
      // 否则又会退回那批过期地址。generation 推进以作废旧异步结果。
      PlaybackLog.write('resolve_ok', {
        'site': params.site,
        'room': params.roomId,
        'quality': next?.name,
        'lines': recovery.length,
        'host': Uri.tryParse(recovery.firstOrNull?.url ?? '')?.host,
        'hosts': [for (final line in recovery) Uri.tryParse(line.url)?.host ?? '?'].join(','),
      });
      state = AsyncData(
        current.copyWith(
          payload: payload,
          quality: next,
          line: recovery.firstOrNull ?? line,
          generation: ++_generation,
        ),
      );
      // 恢复重解析由播放器内部随后重新 open,先把当前房间的音量/静音语义
      // 套回底层,避免恢复路径只更新线路而丢失控制条状态。
      await _applyRoomVolume(ref.read(playerProvider));
      return recovery;
    } catch (error) {
      PlaybackLog.write('resolve_fail', {'site': params.site, 'room': params.roomId, 'error': '$error'});
      return const [];
    }
  }

  /// 回退线路：**恒为空**（用户口径 2026-09-26：去掉线路自动切换）。
  ///
  /// 此前这里把同画质下的其余线路全部作为 mpv 播放列表回退项，某条断流/超时时
  /// mpv 会自动跳到下一条；副作用是**用户手动切了线路后**仍会看到
  /// 「直播地址暂时无法打开，正在切换线路…」并被自动改线，与用户选的那条冲突。
  /// 现在只播用户/策略选中的这一条，失败就如实报错，不偷换线路。
  ///
  /// 底层 [LivePlayer.open] 的 `fallbacks` 形参与 mpv 播放列表能力保留
  /// （属平台层能力，不在本轮拆除），只是不再被喂数据。
  List<StreamLine> _fallbackLines(StreamQuality? quality, StreamLine? line) => const [];

  /// 按偏好挑**可起播**的档位:在 [pickPlayQuality] 结果落在空线路占位档
  /// (懒取流:解析侧只给实给档真实线路,其余档位占位;或服务器把高请求
  /// 档降级到低档)时,回退首个有线路的档 —— 选中占位档会让 line=null,
  /// 进房黑屏且不触发懒取流。pure_live「没有才退」同口径。
  ///
  /// 偏好值为 worst/lowest(`--quality worst`,见 [StartupRoute.worstQualityFlags])
  /// 时改为挑**最低码率的可播档**(rate 升序、须有线路;rate 同分取靠后 ——
  /// 平台档位列表习惯高→低排,同 rate 视为并列低档):劣化网络下低码率流
  /// 更容易存活(2026-09-29 斗鱼 9999 实测口径)。
  StreamQuality? _pickPlayableQuality(RoomPayload payload, String? preferredName) {
    if (preferredName != null && StartupRoute.worstQualityFlags.contains(preferredName.toLowerCase())) {
      final playable = payload.streams.where((stream) => stream.lines.isNotEmpty).toList();
      if (playable.isEmpty) return null;
      playable.sort((a, b) {
        final byRate = a.rate.compareTo(b.rate);
        return byRate != 0 ? byRate : b.name.compareTo(a.name);
      });
      return playable.first;
    }
    final selected = pickPlayQuality(payload, preferredName);
    if (selected == null || selected.lines.isNotEmpty) return selected;
    return payload.streams.firstWhere((stream) => stream.lines.isNotEmpty, orElse: () => selected);
  }
}
