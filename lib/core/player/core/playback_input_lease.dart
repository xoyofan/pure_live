import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';

typedef PlaybackInputFactory = Future<PlaybackInputLease> Function(
  String url,
  Map<String, String> headers,
  HlsSourceQueryPolicy policy,
);

/// Acquires exactly one caller-owned input, not a reusable bootstrap URL.
/// Observe cancellation and settle only after cleaning failed/partial creation.
/// Expected cancellation uses this token's Dio cancellation error; other
/// creation/cleanup failures remain visible to both open and joined teardown.
typedef PlaybackOwnedInputFactory = Future<PlaybackInputLease> Function(CancelToken cancel);
typedef PlaybackNativeOpen = Future<void> Function(
  String url,
  List<String> urls,
  Map<String, String> headers,
  bool privateInput,
);

/// One input resource; closing is idempotent, including pending/late opens.
class PlaybackInputLease {
  /// `isUsable` 公开命名参数(fork 适配):跨库构造方可注入可用性判定
  /// (binder 以 seat.isClosed 桥接,2026-10-03 合并轮)。
  PlaybackInputLease(this.uri, Future<void> Function() close, {bool Function()? isUsable})
    : _close = close,
      _isUsable = isUsable;
  final Uri uri;
  final Future<void> Function() _close;
  final bool Function()? _isUsable;
  Future<void>? _closing;
  bool _closed = false;
  bool get isUsable => !_closed && (_isUsable?.call() ?? true);
  Future<void> close() {
    _closed = true;
    return _closing ??= Future<void>.sync(_close);
  }
}
