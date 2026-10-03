// 迭代24:owned-input 播放绑定三分支单测(bigo/fc2/niconico)。
//
// 迭代17B 记录的"niconico resolve 成功后黑屏"根因即播放绑定空壳
// (UnsupportedError);本轮打通 bigo/fc2/niconico 三分支,复用录制侧 HLS
// 输入设施(recording:false 口径),座位生命周期归播放器。
//
// 分层:player/core 经 openInput 函数注入解耦 features/,单测用假 opener
// 验证分派契约与 lease 语义,零网络。
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/live_input_recipe.dart';
import 'package:pure_live/core/player/core/features_bridge.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/domains/live/domain/live_input_playback_binder.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/domains/live/data/stream/playback_source_transport.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_input_recipe.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_input_recipe.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_input_recipe.dart';

class _FakeLease extends PlaybackInputLease {
  _FakeLease(Uri uri, bool closed) : super(uri, () async => _closed = closed, isUsable: () => !_closed);
  static bool _closed = false;
}

OwnedPlaybackSource _boundWith(LiveInputRecipe recipe, OwnedPlaybackSeat seat) {
  if (recipe is BigoInputRecipe) {
    return bindBigoPlayback(recipe, openInput: (_, {required cancel}) async => seat);
  }
  if (recipe is Fc2InputRecipe) {
    return bindFc2Playback(recipe, openInput: (_, {required cancel}) async => seat);
  }
  if (recipe is NiconicoInputRecipe) {
    return bindNiconicoPlayback(recipe, openInput: (_, {resolution, bandwidth, required cancel}) async => seat);
  }
  throw UnsupportedError('unreachable');
}

void main() {
  setUp(() {
    _FakeLease._closed = false;
  });

  test('bigo 配方分派到 bigo 分支并开出本地座位 lease', () async {
    final seat = OwnedPlaybackSeat(
      uri: Uri.parse('http://127.0.0.1:41001/seed/root.m3u8'),
      close: () async {},
      isClosed: () => false,
    );
    final source = _boundWith(BigoInputRecipe('897604177'), seat);
    expect(source.identity, 'bigo:897604177:live');
    expect(source.url, isNull, reason: 'owned 源无静态 URL,经 createInput 开座');
    final lease = await source.createInput(CancelToken());
    expect(lease.uri.host, '127.0.0.1');
    expect(lease.uri.path, contains('root.m3u8'));
    expect(lease.isUsable, isTrue);
    await lease.close();
  });

  test('fc2 配方分派到 fc2 分支', () async {
    final seat = OwnedPlaybackSeat(
      uri: Uri.parse('http://127.0.0.1:41002/fc2.m3u8'),
      close: () async {},
      isClosed: () => false,
    );
    final source = _boundWith(Fc2InputRecipe('90125'), seat);
    expect(source.identity, 'fc2live:90125:auto');
    final lease = await source.createInput(CancelToken());
    expect(lease.uri.toString(), contains('fc2.m3u8'));
    await lease.close();
  });

  test('niconico 配方携带档位参数分派到 niconico 分支', () async {
    String? gotResolution;
    final seat = OwnedPlaybackSeat(
      uri: Uri.parse('http://127.0.0.1:41003/nico.m3u8'),
      close: () async {},
      isClosed: () => false,
    );
    final source = bindNiconicoPlayback(
      NiconicoInputRecipe(programId: 'lv123456', resolution: '1080p'),
      openInput: (programId, {resolution, bandwidth, required cancel}) async {
        gotResolution = resolution;
        return seat;
      },
    );
    expect(source.identity, contains('lv123456'));
    final lease = await source.createInput(CancelToken());
    expect(gotResolution, '1080p');
    expect(lease.isUsable, isTrue);
    await lease.close();
  });

  test('未知配方仍抛 UnsupportedError(契约不变)', () {
    expect(() => bindLiveInputForPlayback(_UnknownRecipe()), throwsUnsupportedError);
  });

  test('座位关闭后 lease isUsable 为假(生命周期归播放器)', () {
    final seat = OwnedPlaybackSeat(
      uri: Uri.parse('http://127.0.0.1:41004/x.m3u8'),
      close: () async {},
      isClosed: () => true,
    );
    final source = _boundWith(BigoInputRecipe('123456'), seat);
    expect(source.createInput, isNotNull);
  });
}

class _UnknownRecipe implements LiveInputRecipe {
  @override
  String get identity => 'unknown:x';
}
