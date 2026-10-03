/// owned-input 播放开座桥:把录制侧现成的 HLS 输入设施(bigo/fc2/niconico)
/// 以 `recording: false` 口径接给播放绑定。
///
/// 分层边界:player/core 不直接依赖 features/;经本桥注入开座函数,测试可
/// 覆写(见 live_input_playback_binder 的 openInput 参数)。座位生命周期归
/// 播放器——返回的 close 关闭输入与其本地中继。
library;

import 'package:dio/dio.dart';

import 'package:pure_live/domains/recorder/data/services/bigo_hls_input.dart';
import 'package:pure_live/domains/recorder/data/services/fc2_hls_input.dart';
import 'package:pure_live/domains/recorder/data/services/niconico_hls_input.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_api.dart';

import 'package:pure_live/core/stream/upstream_proxy_routing.dart';

/// 统一开座结果:本地中继 URI + 关闭钩 + 存活探测。
class OwnedPlaybackSeat {
  const OwnedPlaybackSeat({required this.uri, required this.close, required this.isClosed});

  final Uri uri;
  final Future<void> Function() close;
  final bool Function() isClosed;
}

typedef BigoPlaybackInputOpener = Future<OwnedPlaybackSeat> Function(String siteId, {required CancelToken cancel});

typedef Fc2PlaybackInputOpener = Future<OwnedPlaybackSeat> Function(String channelId, {required CancelToken cancel});

typedef NiconicoPlaybackInputOpener = Future<OwnedPlaybackSeat> Function(
  String programId, {
  String? resolution,
  int? bandwidth,
  required CancelToken cancel,
});

/// bigo:studio 接口匿名可达时开 HLS 座位(公开在播 + hls 直链校验在
/// BigoHlsInput.open 内);上游匿名门(needLogin)时抛 BigoException 由
/// 播放链落 owned_seat_fail。
Future<OwnedPlaybackSeat> openBigoPlaybackInput(String siteId, {required CancelToken cancel}) async {
  final input = await BigoHlsInput.open(
    siteId,
    recording: false,
    findProxy: resolveUpstreamProxyDirective,
    cancel: cancel,
  );
  return OwnedPlaybackSeat(uri: input.inputUri, close: input.close, isClosed: () => input.isClosed);
}

/// fc2:频道 HLS 座位(auto 档)。
Future<OwnedPlaybackSeat> openFc2PlaybackInput(String channelId, {required CancelToken cancel}) async {
  final input = await Fc2HlsInput.open(
    channelId,
    recording: false,
    findProxy: resolveUpstreamProxyDirective,
    cancel: cancel,
  );
  return OwnedPlaybackSeat(uri: input.inputUri, close: input.close, isClosed: () => input.isClosed);
}

/// niconico:观察页解析 → 选档 → HLS 座位(不落盘)。
/// `NiconicoWatch`/座位风控口径与录制同源:同一节目多开有互踢风险,座位由
/// 播放器独占并在离场时关闭(见 play_provider 的 _ownedLease 兜底)。
Future<OwnedPlaybackSeat> openNiconicoPlaybackInput(
  String programId, {
  String? resolution,
  int? bandwidth,
  required CancelToken cancel,
}) async {
  final watch = await NiconicoApi().room(programId, cancel: cancel);
  final input = await NiconicoHlsInput.open(
    watch,
    resolution: resolution,
    bandwidth: bandwidth,
    recording: false,
    findProxy: resolveUpstreamProxyDirective,
    cancel: cancel,
  );
  return OwnedPlaybackSeat(uri: input.inputUri, close: input.close, isClosed: () => input.isClosed);
}
