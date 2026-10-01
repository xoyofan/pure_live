// zishu 聊天 tab(真源:zishu_flutter `side_panel/chat_tab.dart` `_ChatTab`)。
//
// 对齐口径:
// - 数据 watch `LivePlayController.danmakuMessages`(RxList,500 上限由
//   controller 维护、换房自动清空),只渲染 `LiveMessageType.chat`;
// - 双队列节流(真源 chat_tab.dart:151-421 全量移植):显示队列 200 上限 /
//   积压队列 100 上限;限速开时新消息进积压、显示空首条立即放行、Timer 按
//   设置秒数逐条放行;限速关时新消息直通、积压一并放出;速度滑杆变化重启
//   定时器(见 `_ingest`/`_ensureReleaseTimer`);
// - 翻译就绪放行(真源 `_translateForDisplay`:337-377):所有放行路径先过
//   翻译(开关 = 通用组「标题自动翻译」同一 Rx
//   `SettingsService.to.app.enableTitleTranslation`),2.5s 未就绪以原文放行,
//   译文与原文相同直接放行原消息;显示列表里永远是终稿文本;
// - 播放状态指示(真源 PlaybackStatus:116-123 + 状态条:552-571):▶/⏸
//   11px 图标(播放中=liveBadge/暂停=textSecondary)+「播放中/播放中(静音)/
//   已暂停」;播放态取 `GlobalPlayerService` 播放器快照(与
//   zishu_player_controls.dart:214-218 `_PlayPauseButton` 同源接线:播放器
//   暴露的是 BehaviorSubject 流而非 Rx,StreamBuilder 保即时;静音读
//   `VideoController.currentVolume` Rx,包在内层 Obx 里即时刷新);
// - 正向 ListView.builder:最新在底(非 reverse),默认贴底跟随(离底容差
//   24px + postFrame jumpTo);离底时累计新消息,「N 条新消息」accent 胶囊
//   浮层(Positioned bottom:8 居中)点击 220ms 动画滚底;
// - 行 = 单个 Text.rich 内联流(对齐真源 chat_row):等级牌 → 粉丝牌 →
//   用户名(协议色非白时用之,w600)→「：」→ 正文,行高 1.48,字号/行距/
//   整表透明度接 [ChatStreamSettings];徽章复用 chat_badges.dart;
// - 顶部状态条:播放状态 + 连接态圆点/文案 + 「刷新」重连钮(逐态
//   overlayColor 对齐真源:611-627:hover surfaceRaised / 按下 accent 16% /
//   键盘焦点 accent 24%);
// - chatEnabled=false → 居中「聊天已关闭」空态(真源 :516-527,整 tab 无
//   状态条);无输入框(对齐真源)。
//
// 与真源的差异(报告口径):
// - 富文本表情段:本仓 LiveMessage 无 segments 模型,正文保持纯文本,
//   翻译走 `translateChatText` 单文本入口(真源是 translateBody 段级);
// - 真源「N 条新消息」计数按显示队列增量,本仓一致;聊天设置源为
//   ChatStreamSettings(GetX Rx),真源是 settingsProvider(Riverpod)。

import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/chat_stream_settings.dart';
import 'package:pure_live/zishu_app/translation/translation_coordinator.dart';

import 'chat_badges.dart';

/// 贴底判定容差(px,对齐真源)。
const double _kBottomTolerance = 24;

/// 行高(对齐真源 `_kChatLineHeight` = 1.48);字号走设置(chatFontSize)。
const double _kChatLineHeight = 1.48;

/// zishu 播放页侧栏「聊天」tab:纯聊天流(对齐 zishu `_ChatTab`)。
class ZishuChatTab extends StatefulWidget {
  const ZishuChatTab({super.key, required this.room});

  /// 当前房间快照:切房(didUpdateWidget 房间标识变化)时重置队列/贴底/未读。
  final LiveRoom room;

  @override
  State<ZishuChatTab> createState() => _ZishuChatTabState();
}

class _ZishuChatTabState extends State<ZishuChatTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  /// 显示队列 A(对齐真源 `_displayRows`):已放行的聊天行(译文终稿),
  /// 最新在末尾;超 [_kChatDisplayLimit] 从头部裁掉最旧。
  final List<LiveMessage> _displayRows = <LiveMessage>[];

  /// 积压队列 B(对齐真源 `_pendingMessages`):仅限速模式使用,新消息先入队,
  /// 每 speed 秒从头部放一条进显示;超 [_kChatPendingLimit] 裁头丢最旧。
  final List<LiveMessage> _pendingMessages = <LiveMessage>[];

  /// 上一次 danmakuMessages 快照:controller 侧 `_flushDanmakuMessages`
  /// 复用旧元素引用后 `assignAll`(只追加 + 裁头),按对象身份 diff 出
  /// 本次真正新增的批次(每条只 ingest 一次,天然去重)。
  List<LiveMessage>? _lastSnapshot;

  /// 用户是否贴底:贴底时新消息自动跟随滚底;离底时累计「N 条新消息」。
  bool _pinnedToBottom = true;

  /// 离底期间累计的新显示条数(按钮文案)。
  int _unseenCount = 0;

  /// 限速放行定时器(单次,放行后续排,对齐 web setTimeout 链)与其间隔
  /// (秒);间隔变化(速度滑杆)时重启。
  Timer? _releaseTimer;
  int? _releaseIntervalSec;

  /// 房间代数:切房时自增。翻译是异步的,「译文就绪再放出」的等待期间可能
  /// 跨切房(State 复用不 dispose)——await 返回后代数不一致即丢弃,防旧房
  /// 消息串进新房列表(对齐真源 `_roomGeneration`)。
  int _roomGeneration = 0;

  /// 显示队列出口的单条翻译等待上限:译文超时未到就以原文放行,宁可原文
  /// 也不无限拖住队列(协调器自身另有 6s 请求超时)。真源同值。
  static const Duration _kTranslateWaitLimit = Duration(milliseconds: 2500);

  /// 显示队列上限(对齐 web useDanmaku CHAT_DISPLAY_LIMIT = 200)。
  static const int _kChatDisplayLimit = 200;

  /// 积压队列上限(对齐 web useDanmaku CHAT_PENDING_LIMIT = 100)。
  static const int _kChatPendingLimit = 100;

  /// TabBarView 只挂载当前页,切 tab 会 dispose 离屏子页;keepAlive 保住
  /// 滚动位置/队列与贴底状态(消息本体在 controller 的 RxList,无丢失风险)。
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 用户上滑/下滑时维护贴底状态与「N 条新消息」显隐。
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(covariant ZishuChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切房(State 复用,如同一树内换房):双队列与放行进度全部归零(对齐
    // 真源 didUpdateWidget),在途翻译放行作废,恢复贴底 —— 新房间首批内容
    // 出现即默认滚到底部。
    if (oldWidget.room.platform != widget.room.platform || oldWidget.room.roomId != widget.room.roomId) {
      _cancelReleaseTimer();
      _roomGeneration += 1;
      _displayRows.clear();
      _pendingMessages.clear();
      _lastSnapshot = null;
      _unseenCount = 0;
      _pinnedToBottom = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollToBottom(animate: false);
        }
      });
    }
  }

  @override
  void dispose() {
    _cancelReleaseTimer();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelReleaseTimer() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _releaseIntervalSec = null;
  }

  /// 与播放路由同实例(对齐 DanmakuTabView 的 `GetView<LivePlayController>`)。
  LivePlayController get _controller => Get.find<LivePlayController>();

  /// 弹幕引擎快照:EmptyDanmaku = 站点未接入(空态文案与状态条据此分叉)。
  bool _isSupported(LivePlayController controller) => controller.danmakuController.liveDanmaku is! EmptyDanmaku;

  bool _isConnected(LivePlayController controller) => controller.danmakuController.liveDanmaku.isConnected;

  /// 刷新 = 强制重建弹幕会话(connectRoom force,对齐真源「重新连接」语义;
  /// DanmakuController 内部有序列化与 epoch 保护,重复点击安全)。
  void _reconnect(LivePlayController controller) {
    unawaited(controller.danmakuController.connectRoom(controller.room, force: true));
  }

  /// 通用组「标题自动翻译」开关(与侧栏聊天共用同一 Rx,见文件头口径)。
  /// SettingsService 属启动常驻服务,不注册(理论边缘)视同关。
  bool get _translationEnabled {
    try {
      return SettingsService.to.app.enableTitleTranslation.v;
    } catch (_) {
      return false;
    }
  }

  // ---- 双队列节流(对齐真源 chat_tab.dart:151-421)----

  /// 快照 diff(真源 `_diffSnapshot`):返回相对上次快照真正新增的消息。
  /// controller 侧 assignAll 复用旧元素引用,按「上次末条的对象身份」在新
  /// 快照中定位新增后缀(覆盖纯追加与「追加 + 裁头」两种形态);找不到
  /// 身份链(中途整表替换/按谓词删行,如屏蔽用户)时退化为全量重放。
  List<LiveMessage> _diffSnapshot(List<LiveMessage> snapshot) {
    final prev = _lastSnapshot;
    _lastSnapshot = snapshot;
    if (identical(prev, snapshot)) return const [];
    if (prev == null || prev.isEmpty || snapshot.isEmpty) return snapshot;
    final last = prev.last;
    for (var i = snapshot.length - 1; i >= 0; i -= 1) {
      if (identical(snapshot[i], last)) return snapshot.sublist(i + 1);
    }
    return snapshot;
  }

  /// ingest(对齐真源 `_ingest`):
  /// - 限速关:新消息直通显示;限速期积压一并放出(真源 drainChatPending),
  ///   并停掉放行定时器;
  /// - 限速开:新消息进积压队列(超 [_kChatPendingLimit] 裁头丢最旧);显示
  ///   列表为空时首条立即放行(真源 pushChatPendingBatch);其余交给
  ///   [_ensureReleaseTimer] 按 speed 逐条放行。
  ///
  /// 翻译口径:**译文就绪才放行显示** —— 所有放行路径(直通批量 / 限速逐条 /
  /// 首条立即)都先经 [_translateForDisplay] 完成中文化(2.5s 上限,超时以
  /// 原文放行),显示列表里永远是终稿文本。
  ///
  /// 本仓快照含 online/gift 等类型,diff 后按 chat 类型过滤(真源会话 feed
  /// 本就只有弹幕,无此步)。
  void _ingest(List<LiveMessage> snapshot, {required bool throttled, required int intervalSec}) {
    final batch = _diffSnapshot(snapshot)
        .where((message) => message.type == LiveMessageType.chat)
        .toList(growable: false);
    if (!throttled) {
      _cancelReleaseTimer();
      final outgoing = [...batch, ..._pendingMessages];
      _pendingMessages.clear();
      if (outgoing.isNotEmpty) {
        // 批内并行发起翻译(协调器缓存/批量去重),按到达顺序逐条放行。
        unawaited(_drainToDisplay(outgoing));
      }
      return;
    }
    if (batch.isNotEmpty) {
      _pendingMessages.addAll(batch);
      if (_pendingMessages.length > _kChatPendingLimit) {
        _pendingMessages.removeRange(0, _pendingMessages.length - _kChatPendingLimit);
      }
      if (_displayRows.isEmpty) {
        // 首条立即显示(真源 pushChatPendingBatch:显示空且有积压即放一条)。
        unawaited(_releaseOnePending());
      }
    }
    _ensureReleaseTimer(intervalSec);
  }

  /// 批量放行(直通模式):并行提交翻译,按序 await、按序入显示队列;
  /// 每条落地即刷新(消息逐条浮现),全部完成后统一走滚动跟随。
  Future<void> _drainToDisplay(List<LiveMessage> messages) async {
    final generation = _roomGeneration;
    final enabled = _translationEnabled;
    final futures = [for (final message in messages) _translateForDisplay(message, enabled: enabled)];
    var added = 0;
    for (final future in futures) {
      final translated = await future;
      if (!mounted || generation != _roomGeneration) return;
      _pushTranslated(translated);
      added += 1;
      // 每条落地即请求一帧:消息以帧粒度逐条浮现,不积攒到批末。
      setState(() {});
    }
    _onDisplayGrew(added);
  }

  /// 追加进显示队列,超 [_kChatDisplayLimit] 裁头丢最旧(对齐真源
  /// pushChatDisplay)。入参必须是已完成中文化的终稿消息。
  void _pushTranslated(LiveMessage message) {
    _displayRows.add(message);
    if (_displayRows.length > _kChatDisplayLimit) {
      _displayRows.removeRange(0, _displayRows.length - _kChatDisplayLimit);
    }
  }

  /// 显示队列出口的中文化(真源 `_translateForDisplay`:337-377):开关关 /
  /// 已是中文(无需翻译,协调器原样返回)→ 原消息直通(零开销);需翻译 →
  /// 译文重建消息,超 [_kTranslateWaitLimit] 未就绪以原文放行 —— 宁可原文,
  /// 不拖住整条聊天流。译文与原文相同直接放行原消息对象。
  Future<LiveMessage> _translateForDisplay(LiveMessage message, {required bool enabled}) async {
    if (!enabled) return message;
    String translated;
    try {
      translated = await translateChatText(message.message, waitLimit: _kTranslateWaitLimit);
    } catch (_) {
      return message;
    }
    if (translated == message.message) return message;
    return _copyMessageWithText(message, translated);
  }

  /// LiveMessage 全字段拷贝(仅换正文):粉丝牌/等级/协议色等原样保留,
  /// 行渲染管线(徽章、颜色)不受翻译影响。
  LiveMessage _copyMessageWithText(LiveMessage message, String text) => LiveMessage(
    type: message.type,
    userName: message.userName,
    userId: message.userId,
    message: text,
    data: message.data,
    color: message.color,
    userLevel: message.userLevel,
    fansLevel: message.fansLevel,
    fansName: message.fansName,
    isLocal: message.isLocal,
    messageId: message.messageId,
    sentAt: message.sentAt,
    style: message.style,
    badgeName: message.badgeName,
    badgeLevel: message.badgeLevel,
    badgeColorStart: message.badgeColorStart,
    badgeColorEnd: message.badgeColorEnd,
    badgeColorBorder: message.badgeColorBorder,
    badgeUrl: message.badgeUrl,
    badgeBrid: message.badgeBrid,
    badgeMonths: message.badgeMonths,
    badgeDiafid: message.badgeDiafid,
  );

  /// 从积压头部放行一条进显示(真源 releaseOnePending 的 shift 语义):
  /// 译文就绪(或超时回原文)后入显示队列并刷新;限速模式每 tick 一条,
  /// 翻译等待融入放行间隔,不占用 UI 帧。
  Future<void> _releaseOnePending() async {
    if (_pendingMessages.isEmpty) return;
    final generation = _roomGeneration;
    final message = _pendingMessages.removeAt(0);
    final translated = await _translateForDisplay(message, enabled: _translationEnabled);
    if (!mounted || generation != _roomGeneration) return;
    _pushTranslated(translated);
    setState(() {});
    _onDisplayGrew(1);
  }

  /// 限速放行调度(真源 ensureReleaseTimer):无积压不排表;已有定时器且
  /// 间隔未变则不动;速度滑杆变化(间隔变化)→ 重启定时器,滑杆即时生效。
  void _ensureReleaseTimer(int intervalSec) {
    if (_pendingMessages.isEmpty) return;
    if (_releaseTimer != null && _releaseIntervalSec != intervalSec) {
      _releaseTimer!.cancel();
      _releaseTimer = null;
    }
    _releaseTimer ??= Timer(Duration(seconds: intervalSec), _onReleaseTick);
    _releaseIntervalSec = intervalSec;
  }

  /// 到点放行一条;积压未尽则按当前速度续排下一发。速度在定时器存续期内
  /// 变化时,下一次调度会用新速度。放行等待译文期间不重入排程(定时器已
  /// 置空),完成后续排。
  Future<void> _onReleaseTick() async {
    _releaseTimer = null;
    if (!mounted || _pendingMessages.isEmpty) return;
    await _releaseOnePending();
    if (!mounted) return;
    if (_pendingMessages.isNotEmpty) {
      _ensureReleaseTimer(ChatStreamSettings.to.speed);
    }
  }

  /// 用户当前是否停在底部(容差 24px,避免像素误差导致误判)。
  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - _kBottomTolerance;
  }

  void _onScrollChanged() {
    if (!mounted) return;
    final atBottom = _isAtBottom;
    final changed = atBottom != _pinnedToBottom || (atBottom && _unseenCount > 0);
    _pinnedToBottom = atBottom;
    if (atBottom) _unseenCount = 0;
    if (changed) setState(() {});
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (!animate) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut).then((_) {
      // ListView.builder 惰性构建:尾部行未 realize 时 maxScrollExtent 可能
      // 滞后(只统计已构建行),落定后按最新 extent 校正一次(对齐真源)。
      if (!mounted || !_scrollController.hasClients || !_pinnedToBottom) {
        return;
      }
      final position = _scrollController.position;
      if (position.pixels < position.maxScrollExtent - 0.5) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  /// 新显示内容到达后:贴底时自动跟随滚底(滚动放 post-frame:首帧 ListView
  /// 尚未挂载时也能在挂载后跳到底部);离底时仅累计未读。
  void _onDisplayGrew(int added) {
    if (added <= 0) return;
    if (!_pinnedToBottom) {
      _unseenCount += added;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollToBottom(animate: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    final tokens = context.tokens;
    // 控制器未注册(直接热预览等边缘,与 ZishuPlayView 同口径的占位等待)。
    if (!Get.isRegistered<LivePlayController>()) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('聊天暂不可用', textAlign: TextAlign.center, style: context.textCaption),
        ),
      );
    }
    final controller = _controller;
    // 聊天设置:总开关 + 渲染参数(字号/行距/透明度/节流,对齐真源 build 内
    // watch settingsProvider;Rx 在 Obx 内读取,滑杆变化即时重建)。
    final settings = ChatStreamSettings.to;
    return Obx(() {
      // chatEnabled=false:居中空态(真源 :516-527,整 tab 不渲染状态条)。
      if (!settings.chatEnabled.v) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text('聊天已关闭', textAlign: TextAlign.center, style: context.textCaption),
          ),
        );
      }
      // 双队列 ingest + 限速放行(对齐真源 build 内 _ingest 调用点):全量
      // 直通 / 逐条放行;翻译就绪才放行(见 _ingest 注释)。
      final messages = controller.danmakuMessages.toList(growable: false);
      _ingest(messages, throttled: settings.chatThrottleOn.v, intervalSec: settings.speed);
      final rows = _displayRows;
      final newCount = _pinnedToBottom ? 0 : _unseenCount;
      final messageFontSize = settings.fontSize.toDouble();
      final rowSpacing = settings.lineSpacing.toDouble();
      // 连接态是引擎上的普通 bool(非 Rx):放在 Obx 内读取,消息流(含
      // DanmakuController 的连接状态系统消息)触发重建时即刷新快照。
      final supported = _isSupported(controller);
      final connected = _isConnected(controller);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusBar(context, tokens, controller: controller, supported: supported, connected: connected),
          Expanded(
            child: Stack(
              children: [
                // 聊天区不透明度(真源 :653-656,10-100 → 0.1-1.0;空态同在
                // Opacity 内,对齐真源 :656-666)。
                Opacity(
                  key: const Key('play-side-chat-opacity'),
                  opacity: settings.opacity / 100,
                  child: rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              // 空态两文案(无既有 i18n key,中文常量,对齐真源 :661)。
                              supported ? '暂无弹幕，等待水友发言…' : '当前站点暂不支持弹幕',
                              textAlign: TextAlign.center,
                              style: context.textCaption,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.sm,
                            AppSpacing.xs,
                            AppSpacing.sm,
                            AppSpacing.sm,
                          ),
                          itemCount: rows.length,
                          itemBuilder: (context, index) => Padding(
                            key: const Key('play-side-chat-row'),
                            // 行间距 = 设置 chatLineSpacing(真源 :679 padding bottom)。
                            padding: EdgeInsets.only(bottom: rowSpacing),
                            child: _ZishuChatRow(
                              message: rows[index],
                              site: widget.room.platform ?? '',
                              fontSize: messageFontSize,
                            ),
                          ),
                        ),
                ),
                if (newCount > 0)
                  // 对齐真源 .chat-new-bar:底部水平居中,距底 8。
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(
                      child: _NewMessagesButton(
                        count: newCount,
                        onTap: () {
                          setState(() => _unseenCount = 0);
                          _scrollToBottom();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// 顶部状态条(高 31,对齐真源 :546-648):播放状态指示 + 连接态圆点/
  /// 文案 + 「刷新」重连钮。
  ///
  /// 播放态:与 zishu_player_controls `_PlayPauseButton` 同源快照接线
  /// (GlobalPlayerService 播放器 isPlayingNow/onPlaying,普通流非 Rx →
  /// StreamBuilder);静音态读 `VideoController.currentVolume` Rx,内层
  /// Obx 包裹保证拖音量/静音切换即时刷新(对齐 `_MuteButton` 口径)。
  Widget _buildStatusBar(
    BuildContext context,
    ZishuTokens tokens, {
    required LivePlayController controller,
    required bool supported,
    required bool connected,
  }) {
    final player = GlobalPlayerService.instance.player;
    return StreamBuilder<bool>(
      stream: player.onPlaying.distinct(),
      initialData: player.isPlayingNow,
      builder: (context, playingSnapshot) {
        final playing = playingSnapshot.data ?? player.isPlayingNow;
        return Obx(() {
          final muted = (controller.state.value.player.videoController?.currentVolume.value ?? 1) <= 0;
          // 播放状态文案(真源 PlaybackStatus.label:122,无 i18n key,
          // 中文常量;半角括号区分静音态)。
          final statusLabel = playing ? (muted ? '播放中(静音)' : '播放中') : '已暂停';
          // 连接态短文案无既有 i18n key,中文常量(对齐真源 _connectionLabel)。
          final String connectionLabel = supported ? (connected ? '弹幕已连接' : '弹幕未连接') : '弹幕不支持';
          final Color dotColor = supported && connected ? tokens.liveBadge : tokens.textSecondary;
          return Container(
            height: MediaQuery.textScalerOf(context).scale(31),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: tokens.surfaceSoft,
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                // 播放状态指示(真源 :554-571):▶/⏸ 11px,播放中 liveBadge。
                Icon(
                  playing ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 11,
                  color: playing ? tokens.liveBadge : tokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(statusLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textCaption),
                ),
                const SizedBox(width: 12),
                Icon(Icons.circle, size: 7, color: dotColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    connectionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textCaption,
                  ),
                ),
                const Spacer(),
                // 对齐真源:图标 + 「刷新」文字的小按钮(高 24)。文案用既有
                // i18n key `refresh`;tooltip 无对应 key,中文常量。
                Tooltip(
                  message: '重新连接弹幕',
                  child: TextButton(
                    key: const Key('play-side-chat-refresh'),
                    onPressed: supported ? () => _reconnect(controller) : null,
                    style:
                        TextButton.styleFrom(
                          minimumSize: const Size(0, 24),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: tokens.textSecondary,
                          // 六态补全:hover 抬 surfaceRaised、按下/键盘焦点走
                          // accent 低 alpha(对齐真源 :611-627)。
                          animationDuration: AppMotion.fast,
                        ).copyWith(
                          // 逐态 overlayColor 只能走 copyWith:styleFrom 的
                          // overlayColor 参数是单个 Color?,不收 WidgetStateProperty。
                          overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (states.contains(WidgetState.focused)) {
                              return tokens.accent.withValues(alpha: 0.24);
                            }
                            if (states.contains(WidgetState.pressed)) {
                              return tokens.accent.withValues(alpha: 0.16);
                            }
                            if (states.contains(WidgetState.hovered)) {
                              return tokens.surfaceRaised;
                            }
                            return null;
                          }),
                        ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 13),
                        const SizedBox(width: 2),
                        Text(
                          i18n('refresh'),
                          // tokens 非常量,TextStyle 不能带 const(对齐真源 :636-640)。
                          style: TextStyle(fontSize: AppFontSize.caption, height: 1, color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

/// 聊天消息行:单个 Text.rich 内联流(对齐真源 chat_row `_ChatRow` 的单段落
/// 结构 —— 徽章/昵称/正文同处一个段落,正文折行时第二行从段落最左顶格起排)。
class _ZishuChatRow extends StatelessWidget {
  const _ZishuChatRow({required this.message, required this.site, required this.fontSize});

  final LiveMessage message;

  /// 站点 id(LiveRoom.platform:'douyu'/'huya'/'douyin'/'bilibili'…),
  /// 徽章分站渲染依据(对齐真源 `_ChatRowData.site`)。
  final String site;

  /// 行字号(设置 chatFontSize,真源 :539/682)。
  final double fontSize;

  /// 系统消息:`addSystemMessage` 固定以 i18n('system_message')(zh
  /// 「系统消息」)作 userName、type 仍是 chat,模型上无独立 type 可分,
  /// 按用户名判定后整行走次级样式(无徽章/用户名前缀)。
  bool get _isSystem => message.userName == i18n('system_message');

  /// 用户名颜色:协议色非白(平台给了弹幕色)才用之,白色 = 默认 → 次级色
  /// (engines 侧 `color == 0` 统一映射为 `LiveMessageColor.white`)。
  Color _userColor(BuildContext context) {
    final color = message.color;
    if (color.r == 255 && color.g == 255 && color.b == 255) return context.tokens.textSecondary;
    return Color.fromARGB(255, color.r, color.g, color.b);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (_isSystem) {
      return Text(
        message.message,
        style: TextStyle(fontSize: fontSize, height: _kChatLineHeight, color: tokens.textSecondary),
      );
    }
    // 单段落内联流(对齐真源:固定行高 strut,徽章 middle 对齐 + 行尾 2px)。
    return Text.rich(
      strutStyle: StrutStyle(fontSize: fontSize, height: _kChatLineHeight, forceStrutHeight: true),
      TextSpan(
        children: [
          // 徽章顺序对齐真源:平台用户等级 pill 在前、粉丝牌在后
          // (真源 chat_row.dart:107-119;真源 userLevel gate 是 >0,我们
          // 是字符串非空白,引擎侧只在 >0 时填,语义一致)。
          if (message.userLevel.trim().isNotEmpty)
            zishuInlineBadge(ZishuChatUserLevelBadge(site: site, level: message.userLevel)),
          // 粉丝牌缺字段不渲染(zishuFanBadgeVisible:douyu/通用仍要求团名,
          // douyin/huya 有协议图 url 或等级即可 —— 官方图/圆盘可脱离团名
          // 渲染,与真源 visibleFor 只卡 douyu 的口径一致)。name 用 ?? ''
          // 传:douyin/huya 允许无名(官方图分支 tooltip 不带名)。
          if (zishuFanBadgeVisible(
            site: site,
            name: message.badgeName,
            level: message.badgeLevel,
            url: message.badgeUrl,
          ))
            zishuInlineBadge(
              ZishuChatFanBadge(
                site: site,
                name: message.badgeName ?? '',
                level: message.badgeLevel,
                colorStart: message.badgeColorStart,
                colorEnd: message.badgeColorEnd,
                colorBorder: message.badgeColorBorder,
                url: message.badgeUrl,
                brid: message.badgeBrid,
                months: message.badgeMonths,
                diafid: message.badgeDiafid,
              ),
            ),
          TextSpan(
            text: message.userName,
            style: TextStyle(
              fontSize: fontSize,
              height: _kChatLineHeight,
              fontWeight: FontWeight.w600,
              color: _userColor(context),
            ),
          ),
          TextSpan(
            text: '：',
            style: TextStyle(fontSize: fontSize, height: _kChatLineHeight, color: tokens.textSecondary),
          ),
          // 正文保持纯文本(表情图富文本段不迁,见文件头注释);翻译已在
          // 放行管线完成(显示即终稿)。
          TextSpan(
            text: message.message,
            style: TextStyle(fontSize: fontSize, height: _kChatLineHeight, color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// 「N 条新消息」跳底按钮:用户离开底部且有新消息时浮在列表底部居中
/// (对齐真源 `_NewMessagesButton`:accent 实底胶囊,亮底白字)。
class _NewMessagesButton extends StatelessWidget {
  const _NewMessagesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tokens.accent,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        key: const Key('play-side-chat-jump-bottom'),
        borderRadius: AppRadius.allMd,
        onTap: onTap,
        // accent 实底上用白低 alpha 提亮(不引入新色相,不改尺寸)。
        hoverColor: AppOnBright.white.withValues(alpha: 0.12),
        splashColor: AppStateLayer.splashOf(AppOnBright.white),
        highlightColor: AppStateLayer.pressedOf(AppOnBright.white),
        focusColor: AppStateLayer.focusOf(AppOnBright.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            // 无既有 i18n key,中文常量(对齐真源同文案)。
            '$count 条新消息',
            style: const TextStyle(
              fontSize: AppFontSize.bodySecondary,
              height: 1.1,
              color: AppOnBright.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
