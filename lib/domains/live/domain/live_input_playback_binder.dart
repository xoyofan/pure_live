import 'package:pure_live/core/player/core/features_bridge.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_input_recipe.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_input_recipe.dart';
import 'package:pure_live/shared/platforms/live_input_recipe.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_input_recipe.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/domains/live/data/stream/playback_source_transport.dart';

typedef LiveInputPlaybackBinder = OwnedPlaybackSource Function(LiveInputRecipe recipe);

/// Binds public resolution data to a playback recipe without opening a seat.
/// Every actual native open acquires independent resources inside the manager.
///
/// 三分支(迭代24)复用录制输入管道的 HLS 座位设施(`recording: false` 口径:
/// 不落盘、不 drain 尾部、关闭即断流),与录制绑定同源但生命周期归播放器:
/// zishu 播放链经 [_openOwnedInput] 开座,旧 UI 经 PlayerKernel 同一入口。
OwnedPlaybackSource bindLiveInputForPlayback(LiveInputRecipe recipe) => switch (recipe) {
  BigoInputRecipe() => bindBigoPlayback(recipe),
  Fc2InputRecipe() => bindFc2Playback(recipe),
  NiconicoInputRecipe() => bindNiconicoPlayback(recipe),
  _ => throw UnsupportedError('No playback binding for this input recipe'),
};

OwnedPlaybackSource bindBigoPlayback(BigoInputRecipe recipe, {BigoPlaybackInputOpener? openInput}) =>
    OwnedPlaybackSource(
      identity: recipe.identity,
      createInput: (cancel) async {
        final input = await (openInput ?? openBigoPlaybackInput)(recipe.siteId, cancel: cancel);
        return PlaybackInputLease(input.uri, input.close, isUsable: () => !input.isClosed());
      },
    );

OwnedPlaybackSource bindFc2Playback(Fc2InputRecipe recipe, {Fc2PlaybackInputOpener? openInput}) => OwnedPlaybackSource(
  identity: recipe.identity,
  createInput: (cancel) async {
    final input = await (openInput ?? openFc2PlaybackInput)(recipe.channelId, cancel: cancel);
    return PlaybackInputLease(input.uri, input.close, isUsable: () => !input.isClosed());
  },
);

OwnedPlaybackSource bindNiconicoPlayback(NiconicoInputRecipe recipe, {NiconicoPlaybackInputOpener? openInput}) =>
    OwnedPlaybackSource(
      identity: recipe.identity,
      createInput: (cancel) async {
        final input = await (openInput ?? openNiconicoPlaybackInput)(
          recipe.programId,
          resolution: recipe.resolution,
          bandwidth: recipe.bandwidth,
          cancel: cancel,
        );
        return PlaybackInputLease(input.uri, input.close, isUsable: () => !input.isClosed());
      },
    );
