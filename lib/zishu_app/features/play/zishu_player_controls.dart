/// zishu 风格 on-video 播放控制条(样式真源:zishu_flutter
/// `lib/src/features/play/widgets/player_controls.dart` 的 PlayerControlsBar)。
///
/// 单行 48px,压在视频底部的渐变 scrim 上(transparent → AppOnVideo.scrim
/// 黑 72%):左组 = 播放/暂停 + 刷新 + 睡眠定时 + 弹幕开关「弹」+ 弹幕设置
/// 齿轮 popover (显示/透明度/字号/速度/区域);右组 = 静音 + 音量滑杆 96px +
/// 画质选盒 + 线路选盒 + 画中画 + 宽屏 W + 全屏 F。on-video 墨色恒定暗底语义
/// (AppOnVideo),不随应用主题翻转。
///
/// compact 响应式(真源 player_controls.dart:150-157,237,304,377-391 同口径):
/// 控制条自身可用宽 <560 时隐藏 音量滑杆(保留静音钮)/ 睡眠定时 / 画中画 /
/// 宽屏,只留播放/刷新/弹幕/静音/画质/线路/全屏核心按钮;判宽用
/// [LayoutBuilder] 判条自身宽而非视口宽 —— 宽视口也可能被常驻侧栏挤窄
/// (真源同注)。
///
/// 与真源的差异(移植口径):
/// - 状态管理 Riverpod → GetX:Rx 读取在各子件自己的 `Obx` 内完成;
/// - 数据源全部走 pure_live 真实 API(VideoController / LivePlayController /
///   GlobalPlayerService / GlobalPlayerState),不触碰底层播放引擎;
/// - 显隐接 pure_live 既有 `showController` 逻辑:条内 hover 恒亮
///   (`onMouseEnterController` 销定),隐藏时 AnimatedOpacity 200ms 淡出;
/// - 弹幕设置写 [VideoController] 的弹幕 Rx 字段,由 DanmakuManager 的 ever
///   worker 回写设置并刷新弹幕渲染配置(见 video_controller.dart)。
library;

import 'dart:async';

import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/play_quality_label.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart' show GlobalPlayerState;
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/zishu_sleep_timer_controller.dart';
import 'package:pure_live/zishu_app/features/play/zishu_stage_hint.dart';
import 'package:remixicon/remixicon.dart';

/// on-video 控件的 Material 墨色(样式真源 `_onVideoInkTheme`):控制条恒定
/// 暗底,hover/pressed/focus 覆盖色必须恒定亮色,否则浅色主题下是深色覆盖层,
/// 压在暗 scrim 上没有反馈。
ThemeData _onVideoInkTheme(BuildContext context) => Theme.of(context).copyWith(
  hoverColor: AppOnVideo.text.withValues(alpha: 0.12),
  highlightColor: AppStateLayer.pressedOf(AppOnVideo.text),
  focusColor: AppStateLayer.focusOf(AppOnVideo.text),
  splashColor: AppStateLayer.splashOf(AppOnVideo.text),
);

/// 控制条 `IconButton` 的状态覆盖色(样式真源 `_onVideoButtonStyle`)。
ButtonStyle _onVideoButtonStyle() => ButtonStyle(
  animationDuration: AppMotion.fast,
  overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.focused)) {
      return AppOnVideo.text.withValues(alpha: 0.24);
    }
    if (states.contains(WidgetState.pressed)) {
      return AppOnVideo.text.withValues(alpha: 0.18);
    }
    if (states.contains(WidgetState.hovered)) {
      return AppOnVideo.text.withValues(alpha: 0.12);
    }
    return null;
  }),
);

/// 打开菜单时销定控制条(对齐既有 SettingsButton 的 isMenuOpen 口径)。
void _pinControlBar(VideoController controller) {
  controller.isMenuOpen.value = true;
  controller.stopHideController();
}

/// 菜单关闭后解除销定并重新武装自动隐藏计时。
void _unpinControlBar(VideoController controller) {
  if (controller.status == PlayerStatus.disposed) return;
  controller.isMenuOpen.value = false;
  controller.enableController();
}

/// on-video 控制条。挂在舞台底部 overlay 上;显隐完全由既有
/// [VideoController.showController] 驱动,本组件不再自带隐藏计时。
class ZishuPlayerControlsBar extends StatefulWidget {
  const ZishuPlayerControlsBar({super.key, required this.controller});

  final VideoController controller;

  @override
  State<ZishuPlayerControlsBar> createState() => _ZishuPlayerControlsBarState();
}

class _ZishuPlayerControlsBarState extends State<ZishuPlayerControlsBar> {
  VideoController get controller => widget.controller;

  /// 静音前的音量(取消静音时的恢复目标)。
  /// pure_live 无独立静音通道:静音 = 音量归 0(VideoController.setVolume)。
  double _volumeBeforeMute = 0;

  Future<void> _toggleMute() async {
    final volume = controller.currentVolume.value;
    if (volume > 0) {
      _volumeBeforeMute = volume;
      await controller.setVolume(0);
    } else {
      await controller.setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Slider 等 Material 控件需要 Material 祖先;条在无壳布局的 Stack 内,
    // 与样式真源同口径用透明 Material 自给。
    return Theme(
      data: _onVideoInkTheme(context),
      child: Material(
        type: MaterialType.transparency,
        child: Obx(() {
          final visible = controller.showController.value || controller.isMenuOpen.value;
          return MouseRegion(
            // 条内 hover 恒亮:hover 期间经 hover-owner 销定,不触发自动隐藏。
            onEnter: (_) => controller.onMouseEnterController(),
            onExit: (_) => controller.onMouseExitController(),
            child: IgnorePointer(
              // 隐藏后整条放行指针,点击穿透到视频手势层(播放/暂停、亮度音量)。
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                // compact 判宽取控制条自身可用宽(真源 player_controls.dart:
                // 148-157 同口径:LayoutBuilder 判 <560;宽视口也可能被常驻
                // 侧栏挤窄,不判视口宽)。
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    return SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 渐变 scrim 单独一层并放行指针:空档区域点击继续落到
                          // 视频手势层,不吞按钮之外的点击。
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, AppOnVideo.scrim],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Align(alignment: Alignment.centerLeft, child: _buildLeftGroup(compact)),
                          Align(alignment: Alignment.centerRight, child: _buildRightGroup(compact)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 左组:播放/暂停 → 刷新 → 睡眠定时(compact 隐藏,真源 :237)→
  /// 弹幕开关「弹」→ 弹幕设置齿轮。
  Widget _buildLeftGroup(bool compact) {
    final danmakuEnabled = SettingsService.to.danmaku.enableDanmakuDisplay.v;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _PlayPauseButton(),
        IconButton(
          key: const Key('play-refresh-stream'),
          style: _onVideoButtonStyle(),
          tooltip: i18n('refresh'),
          onPressed: () {
            unawaited(controller.refresh());
            // 完成反馈对齐真源:「已刷新」SnackBar 2s(player_controls.dart:224-229)
            // 落进舞台内浮层。key `play_refreshed` 待主会话补入 en/zh 字典
            // (zh「已刷新」/ en "Refreshed",见本轨 compromises)。
            ZishuStageHint.show(i18n('play_refreshed'));
          },
          icon: const Icon(Icons.refresh_rounded, size: 20, color: AppOnVideo.text),
        ),
        if (!compact) _SleepTimerButton(controller: controller),
        if (danmakuEnabled) ...[
          _DanmakuToggleButton(controller: controller),
          _DanmakuSettingsButton(controller: controller),
        ],
      ],
    );
  }

  /// 右组:静音 + 音量滑杆 96px(compact 隐藏滑杆、保留静音,真源 :304)→
  /// 画质 → 线路 → 画中画 → 宽屏 W → 全屏 F(compact 隐藏 画中画/宽屏,
  /// 真源 :377-391;全屏恒留)。按钮序保持真源顺序。
  Widget _buildRightGroup(bool compact) {
    final showPip = GlobalPlayerService.instance.initialized && (PlatformUtils.isWindows || PlatformUtils.isAndroid);
    final showWidescreen = controller.supportWindowFull;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MuteButton(controller: controller, onToggleMute: _toggleMute),
        if (!compact) ...[const SizedBox(width: AppSpacing.xs), _VolumeSlider(controller: controller)],
        const SizedBox(width: AppSpacing.xs),
        _QualitySelectBox(controller: controller),
        const SizedBox(width: AppSpacing.xs),
        _LineSelectBox(controller: controller),
        const SizedBox(width: AppSpacing.sm),
        if (showPip && !compact) const _PipButton(),
        if (showWidescreen && !compact) _WidescreenButton(controller: controller),
        _FullscreenButton(controller: controller),
      ],
    );
  }
}

/// 播放/暂停(快照驱动):对齐既有 PlayPauseButton 的 onPlaying 流口径。
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final player = GlobalPlayerService.instance.player;
    return StreamBuilder<bool>(
      stream: player.onPlaying.distinct(),
      initialData: player.isPlayingNow,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? player.isPlayingNow;
        return IconButton(
          key: const Key('play-toggle-play'),
          style: _onVideoButtonStyle(),
          // 键位后缀对齐真源 :196「暂停 (Space)」(读现 tooltip 文案拼接,半角括号)。
          tooltip: '${i18n(isPlaying ? 'multiview_pause' : 'multiview_play')} (Space)',
          onPressed: () => unawaited(player.togglePlayPause()),
          icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20, color: AppOnVideo.text),
        );
      },
    );
  }
}

/// 睡眠定时入口(真源 _SleepTimerButton,player_controls.dart:576-682 的
/// GetX 转写):点击弹预设 popover,行为锚定按钮 —— 「关闭定时」(有定时时
/// 才出现)/ 预设 15/30/60/90/120 分钟 / 「自定义…」(对话框输入,上限 720
/// 分钟,真源 maxCustomMinutes 同值);当前档位菜单项打勾(对齐本条画质/
/// 线路选盒的选中标识;真源菜单无打勾,属本项目 popover 家族统一口径)。
/// active 时按钮 tooltip 显示剩余时间(真源 :590「睡眠定时 (剩余 mm:ss)」
/// 同构;「定时关闭」/「剩余时间」复用既有 i18n key `sleep_timer` /
/// `remaining_time` 拼接)。数据源为 app 级 [ZishuSleepTimerController]
/// (真源 sleepTimerProvider 语义:离开播放页定时不清)。设定/取消反馈复用
/// 既有 key `room_playback_timer_set` / `room_playback_timer_cancelled`
/// (zh 文案与真源 :604/:600 同文)。菜单打开期间销定控制条防自动隐藏
/// (本文件 popover 家族同款 pin/unpin)。
class _SleepTimerButton extends StatelessWidget {
  const _SleepTimerButton({required this.controller});

  final VideoController controller;

  /// 菜单里「自定义…」项的哨兵值;预设档位为分钟数,「关闭定时」为 0
  /// (真源 _customValue 同口径)。
  static const int _customValue = -1;

  /// 菜单项文案(真源 :611/:622 同文案;无既有 i18n key、json 本轮全轨冻结,
  /// 中文常量记录)。
  static const String _turnOffLabel = '关闭定时';
  static const String _customLabel = '自定义…';

  /// 自定义对话框标题(真源 :647 同文案;无 i18n key,中文常量记录)。
  static const String _customDialogTitle = '自定义睡眠定时';

  @override
  Widget build(BuildContext context) {
    final timer = ZishuSleepTimerController.to;
    return Obx(() {
      final active = timer.active;
      return PopupMenuButton<int>(
        // 测试锚点:睡眠定时入口(真源同 key)。
        key: const Key('play-sleep-timer'),
        tooltip: active
            // active 带剩余时间(真源 :590 同构;剩余文案由控制器 1s 心跳驱动,
            // Obx 订阅 remaining 每秒刷新)。
            ? '${i18n('sleep_timer')} (${i18n('remaining_time')} ${timer.remainingLabel})'
            : i18n('sleep_timer'),
        padding: EdgeInsets.zero,
        color: Get.theme.colorScheme.surfaceContainerHighest,
        position: PopupMenuPosition.over,
        onOpened: () => _pinControlBar(controller),
        onCanceled: () => _unpinControlBar(controller),
        onSelected: (value) {
          _unpinControlBar(controller);
          if (value == _customValue) {
            unawaited(_pickCustomMinutes(context));
            return;
          }
          if (value <= 0) {
            timer.cancel();
            ZishuStageHint.show(i18n('room_playback_timer_cancelled'));
            return;
          }
          timer.start(Duration(minutes: value));
          ZishuStageHint.show(i18n('room_playback_timer_set', args: {'minutes': '$value'}));
        },
        itemBuilder: (context) {
          // 菜单每次打开即时取值(非响应式即可:打开瞬间的新鲜值,真源同口径)。
          final activeNow = timer.active;
          final minutes = timer.totalMinutes.value;
          return [
            if (activeNow)
              const PopupMenuItem<int>(
                // 测试锚点:关闭定时(真源同 key)。
                key: Key('play-sleep-timer-off'),
                value: 0,
                child: Text(_turnOffLabel),
              ),
            for (final preset in ZishuSleepTimerController.presetsMinutes)
              PopupMenuItem<int>(
                // 测试锚点:预设档(真源同 key)。
                key: Key('play-sleep-timer-$preset'),
                value: preset,
                child: Row(
                  children: [
                    if (minutes == preset)
                      Icon(Icons.check_rounded, size: 16, color: context.tokens.accent)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text('$preset ${i18n('minutes')}'),
                  ],
                ),
              ),
            PopupMenuItem<int>(
              // 测试锚点:自定义(真源同 key)。
              key: const Key('play-sleep-timer-custom'),
              value: _customValue,
              child: Row(
                children: [
                  // 自定义档打勾:有定时且档位不在预设表(唯一能设出非预设档的入口)。
                  if (activeNow && minutes != null && !ZishuSleepTimerController.presetsMinutes.contains(minutes))
                    Icon(Icons.check_rounded, size: 16, color: context.tokens.accent)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: AppSpacing.xs),
                  const Text(_customLabel),
                ],
              ),
            ),
          ];
        },
        child: Icon(
          active ? RemixIcons.moon_fill : RemixIcons.moon_line,
          size: 20,
          color: active ? context.tokens.accent : AppOnVideo.text,
        ),
      );
    });
  }

  /// 「自定义…」输入对话框(真源 _pickCustomMinutes :641-682 的转写):
  /// 空/非法输入直接放弃;超上限 clamp 到 720(真源同 clamp)。反馈走
  /// [ZishuStageHint](免 context 静态通道,await 返回后无需 context.mounted
  /// 检查;菜单选中后浮层路由关闭,[context] 仅用于挂对话框路由)。
  Future<void> _pickCustomMinutes(BuildContext context) async {
    final fieldController = TextEditingController();
    try {
      final minutes = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(_customDialogTitle),
          content: TextField(
            // 测试锚点:自定义分钟输入(真源同 key)。
            key: const Key('play-sleep-timer-custom-input'),
            controller: fieldController,
            autofocus: true,
            keyboardType: TextInputType.number,
            // 输入提示(真源 :654「分钟(1-720)」同文案;上限插值,中文常量)。
            decoration: InputDecoration(hintText: '分钟(1-${ZishuSleepTimerController.maxCustomMinutes})'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel'))),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(int.tryParse(fieldController.text.trim())),
              child: Text(i18n('confirm')),
            ),
          ],
        ),
      );
      if (minutes == null || minutes <= 0) return;
      final max = ZishuSleepTimerController.maxCustomMinutes;
      final clamped = minutes > max ? max : minutes;
      ZishuSleepTimerController.to.start(Duration(minutes: clamped));
      ZishuStageHint.show(i18n('room_playback_timer_set', args: {'minutes': '$clamped'}));
    } finally {
      fieldController.dispose();
    }
  }
}

/// 静音切换:音量 > 0 记住当前值并归 0,归 0 时恢复记忆值。
class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.controller, required this.onToggleMute});

  final VideoController controller;
  final Future<void> Function() onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final muted = controller.currentVolume.value <= 0;
      return IconButton(
        key: const Key('play-toggle-mute'),
        style: _onVideoButtonStyle(),
        // 键位后缀对齐真源 :294「静音 (M)」(读现 tooltip 文案拼接,半角括号)。
        tooltip: '${i18n(muted ? 'cancel_mute' : 'mute')} (M)',
        onPressed: onToggleMute,
        icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 20, color: AppOnVideo.text),
      );
    });
  }
}

/// 音量滑杆(96px):值域 0..1(VideoController.currentVolume 语义),
/// 拖动即写入并经 trySetVolume 持久化到房间音量。
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final volume = controller.currentVolume.value.clamp(0.0, 1.0).toDouble();
      return SizedBox(
        width: 96,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: AppControls.sliderTrackHeight,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppControls.sliderThumbRadius),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          ),
          child: Slider(
            value: volume,
            max: 1.0,
            activeColor: context.tokens.accent,
            // 未激活轨道在视频上需保持可见:浅色主题 border 近白会隐形。
            inactiveColor: AppOnVideo.textMuted,
            onChanged: (value) => unawaited(controller.setVolume(value)),
          ),
        ),
      );
    });
  }
}

/// 画质选盒:入口显示当前档名,菜单项打勾标当前档;切换走
/// `setResolution(ReloadDataType.changeQuality, …)`。
class _QualitySelectBox extends StatelessWidget {
  const _QualitySelectBox({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    final live = controller.livePlayController;
    return Obx(() {
      final state = live.state.value;
      final player = state.player;
      final switching = live.playerController.isStreamSwitching.value;
      if (!state.room.success || player.qualites.isEmpty || !player.hasPlaybackSource) {
        return const SizedBox.shrink();
      }
      final currentIndex = player.currentQuality.clamp(0, player.qualites.length - 1);
      return PopupMenuButton<int>(
        key: const Key('play-quality-menu'),
        tooltip: i18n('toolbox_select_quality'),
        padding: EdgeInsets.zero,
        color: Get.theme.colorScheme.surfaceContainerHighest,
        position: PopupMenuPosition.over,
        onOpened: () => _pinControlBar(controller),
        onCanceled: () => _unpinControlBar(controller),
        onSelected: (index) {
          _unpinControlBar(controller);
          unawaited(live.setResolution(ReloadDataType.changeQuality, index, player.currentLineIndex));
        },
        itemBuilder: (context) => [
          for (var i = 0; i < player.qualites.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  if (i == currentIndex)
                    Icon(Icons.check_rounded, size: 16, color: context.tokens.accent)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(player.qualites[i].quality),
                ],
              ),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (switching) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: AppOnVideo.text),
              ),
              const SizedBox(width: 5),
            ],
            // 窄条防护:入口包 Flexible + ellipsis,不把控制条撑溢出。
            Flexible(
              child: Text(
                key: const Key('play-quality-current'),
                player.qualitySafe.playbackLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppFontSize.bodySecondary, color: AppOnVideo.textMuted),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppOnVideo.textMuted),
          ],
        ),
      );
    });
  }
}

/// 线路选盒:入口显示「线路{n}」,菜单项打勾标当前线路;切换走
/// `setResolution(ReloadDataType.changeLine, …)`。
class _LineSelectBox extends StatelessWidget {
  const _LineSelectBox({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    final live = controller.livePlayController;
    return Obx(() {
      final state = live.state.value;
      final player = state.player;
      final switching = live.playerController.isStreamSwitching.value;
      if (!state.room.success || !player.hasPlaybackSource) {
        return const SizedBox.shrink();
      }
      final currentIndex = player.currentLineIndex.clamp(0, player.lineCount - 1);
      return PopupMenuButton<int>(
        key: const Key('play-line-menu'),
        tooltip: i18n('select_play_line'),
        padding: EdgeInsets.zero,
        color: Get.theme.colorScheme.surfaceContainerHighest,
        position: PopupMenuPosition.over,
        onOpened: () => _pinControlBar(controller),
        onCanceled: () => _unpinControlBar(controller),
        onSelected: (index) {
          _unpinControlBar(controller);
          unawaited(live.setResolution(ReloadDataType.changeLine, player.currentQuality, index));
        },
        itemBuilder: (context) => [
          for (var i = 0; i < player.lineCount; i++)
            PopupMenuItem<int>(
              key: Key('play-line-item-$i'),
              value: i,
              child: Row(
                children: [
                  if (i == currentIndex)
                    Icon(Icons.check_rounded, size: 16, color: context.tokens.accent)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(i18n('toolbox_line', args: {'index': '${i + 1}'})),
                ],
              ),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (switching) ...[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: AppOnVideo.text),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                i18n('toolbox_line', args: {'index': '${currentIndex + 1}'}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppFontSize.bodySecondary, color: AppOnVideo.textMuted),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppOnVideo.textMuted),
          ],
        ),
      );
    });
  }
}

/// 画中画(对齐既有 PIPButton:准备中不可点,失败提示重试)。
/// 按钮仅在 GlobalPlayerService 已初始化时挂载(见 _buildRightGroup),
/// 故此处可安全读取 playerManager 的 Rx 状态。
class _PipButton extends StatelessWidget {
  const _PipButton();

  @override
  Widget build(BuildContext context) {
    final manager = GlobalPlayerService.instance.player;
    return Obx(() {
      final preparing = manager.isPipPreparing.value;
      return IconButton(
        key: const Key('play-toggle-pip'),
        style: _onVideoButtonStyle(),
        tooltip: i18n('float_window_play'),
        onPressed: preparing
            ? null
            : () async {
                try {
                  await manager.enablePip();
                } catch (_) {
                  // 失败反馈从全局 toast 换成舞台内浮层(对齐真源播放页
                  // SnackBar 通道),key 复用既有 `pip_enter_failed`。
                  ZishuStageHint.show(i18n('pip_enter_failed'));
                }
              },
        icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 20, color: AppOnVideo.text),
      );
    });
  }
}

/// 宽屏 W(窗口全屏:视频铺满窗口,不动系统窗口)。
class _WidescreenButton extends StatelessWidget {
  const _WidescreenButton({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = GlobalPlayerState.to.isWindowFullscreen.value;
      return IconButton(
        key: const Key('play-toggle-widescreen'),
        style: _onVideoButtonStyle(),
        // 键位后缀对齐真源 :395-397「网页全屏 (W)」(读现 tooltip 文案拼接,半角括号)。
        tooltip: '${i18n(expanded ? 'collapse_player_window' : 'expand_player_window')} (W)',
        onPressed: () => controller.toggleWindowFullScreen(),
        icon: Icon(
          expanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
          size: 20,
          color: expanded ? context.tokens.accent : AppOnVideo.text,
        ),
      );
    });
  }
}

/// 全屏 F(同时请求系统窗口全屏)。
class _FullscreenButton extends StatelessWidget {
  const _FullscreenButton({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = GlobalPlayerState.to.isFullscreen.value;
      return IconButton(
        key: const Key('play-toggle-fullscreen'),
        style: _onVideoButtonStyle(),
        // 键位后缀对齐真源 :413-415「全屏 (F)」(读现 tooltip 文案拼接,半角括号)。
        tooltip: '${i18n(expanded ? 'exit_fullscreen' : 'enter_fullscreen')} (F)',
        onPressed: () => unawaited(controller.toggleFullScreen()),
        icon: Icon(
          expanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
          size: 20,
          color: expanded ? context.tokens.accent : AppOnVideo.text,
        ),
      );
    });
  }
}

/// 舞台弹幕显隐开关(「弹」方块,样式真源 _DanmakuMark)。
class _DanmakuToggleButton extends StatelessWidget {
  const _DanmakuToggleButton({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final show = !controller.hideDanmaku.value;
      return IconButton(
        key: const Key('play-toggle-danmaku'),
        style: _onVideoButtonStyle(),
        tooltip: i18n('danmaku'),
        onPressed: () => controller.hideDanmaku.toggle(),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: _DanmakuMark(active: show, corner: _DanmakuCorner.check),
      );
    });
  }
}

/// 「弹」字方块(样式真源 `ctrl-danmaku-mark` 复刻):正方形 + 2px 描边 +
/// 圆角,内含「弹」字;[corner] 叠加右下角标,激活时描边与内容转品牌紫。
enum _DanmakuCorner { none, check, gear }

class _DanmakuMark extends StatelessWidget {
  const _DanmakuMark({required this.active, this.corner = _DanmakuCorner.none});

  final bool active;
  final _DanmakuCorner corner;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppOnVideo.accent : AppOnVideo.textMuted;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            '弹',
            style: TextStyle(fontSize: AppFontSize.body, height: 1, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        if (corner != _DanmakuCorner.none)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 11,
              height: 11,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppOnVideo.popoverBg,
                borderRadius: BorderRadius.circular(3),
                boxShadow: AppElevation.hairline,
              ),
              child: corner == _DanmakuCorner.check
                  ? Text(
                      '√',
                      style: TextStyle(
                        fontSize: AppFontSize.overline,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: AppOnVideo.accent,
                      ),
                    )
                  : Icon(Icons.settings_rounded, size: 9, color: active ? AppOnVideo.accent : AppOnVideo.textMuted),
            ),
          ),
      ],
    );
  }
}

/// 飘屏弹幕设置入口:「弹」方块 + 右下齿轮角标;点击向上弹出设置面板
/// (显示/透明度/字号/速度/区域,样式真源 OverlayDanmakuSettingsPanel 复刻)。
/// 读写 [VideoController] 的弹幕 Rx 字段:DanmakuManager 的 ever worker 会
/// 回写 DanmakuSettingsController 并刷新弹幕渲染配置。
class _DanmakuSettingsButton extends StatefulWidget {
  const _DanmakuSettingsButton({required this.controller});

  final VideoController controller;

  @override
  State<_DanmakuSettingsButton> createState() => _DanmakuSettingsButtonState();
}

class _DanmakuSettingsButtonState extends State<_DanmakuSettingsButton> {
  final MenuController _menu = MenuController();

  VideoController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menu,
      onOpen: () => _pinControlBar(controller),
      onClose: () => _unpinControlBar(controller),
      style: MenuStyle(
        alignment: Alignment.topCenter,
        backgroundColor: const WidgetStatePropertyAll(AppOnVideo.popoverBg),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
      ),
      menuChildren: [
        // 弹幕设置 popover 恒定暗底(0xF2121212):内部控件墨色同样切到
        // on-video,浅色主题下 hover/focus 覆盖层才可见。
        Obx(() {
          final show = !controller.hideDanmaku.value;
          return Theme(
            data: _onVideoInkTheme(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _settingsTitle(context),
                _settingsRow(
                  label: i18n('settings_danmaku_open'),
                  trailing: _PopoverSwitch(value: show, onChanged: (value) => controller.hideDanmaku.value = !value),
                ),
                _sliderRow(
                  label: i18n('settings_danmaku_opacity'),
                  value: controller.danmakuOpacity.value,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  display: '${(controller.danmakuOpacity.value * 100).round()}%',
                  onChanged: (v) => controller.danmakuOpacity.value = v,
                ),
                _sliderRow(
                  label: i18n('settings_danmaku_fontsize'),
                  value: controller.danmakuFontSize.value,
                  min: 10,
                  max: 30,
                  divisions: 20,
                  display: '${controller.danmakuFontSize.value.round()}',
                  onChanged: (v) => controller.danmakuFontSize.value = v,
                ),
                _sliderRow(
                  label: i18n('settings_danmaku_speed'),
                  value: controller.danmakuSpeed.value,
                  min: 20,
                  max: 400,
                  divisions: 38,
                  display: '${controller.danmakuSpeed.value.round()}',
                  onChanged: (v) => controller.danmakuSpeed.value = v,
                ),
                _settingsAreaRow(
                  context,
                  current: controller.danmakuArea.value,
                  onPick: (v) => controller.danmakuArea.value = v,
                ),
              ],
            ),
          );
        }),
      ],
      builder: (context, menuController, child) {
        final open = menuController.isOpen;
        return IconButton(
          key: const Key('play-danmaku-settings'),
          tooltip: i18n('settings_danmaku_title'),
          style: _onVideoButtonStyle(),
          onPressed: () => menuController.isOpen ? menuController.close() : menuController.open(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: _DanmakuMark(active: open, corner: _DanmakuCorner.gear),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _settingsTitle(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.only(bottom: 4),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppOnVideo.text.withValues(alpha: 0.12))),
    ),
    child: Text(
      i18n('danmaku'),
      style: TextStyle(fontSize: AppFontSize.bodySecondary, fontWeight: FontWeight.w600, color: AppOnVideo.accent),
    ),
  );

  Widget _settingsRow({required String label, Widget? trailing}) => SizedBox(
    width: 232,
    child: Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontSize: AppControls.labelFontSize, color: AppOnVideo.textMuted),
          ),
        ),
        const Spacer(),
        trailing ?? const SizedBox.shrink(),
      ],
    ),
  );

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) => SizedBox(
    width: 232,
    child: Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(fontSize: AppControls.labelFontSize, color: AppOnVideo.textMuted),
          ),
        ),
        Expanded(
          // 紧凑行高:默认 M3 触摸目标 ~48px 会把每行撑到两倍。
          child: SizedBox(
            height: AppControls.sliderRowHeight,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: AppControls.sliderTrackHeight,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppControls.sliderThumbRadius),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                activeColor: AppOnVideo.accent,
                inactiveColor: AppOnVideo.textMuted,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: AppFontSize.caption, color: AppOnVideo.accent),
          ),
        ),
      ],
    ),
  );

  Widget _settingsAreaRow(BuildContext context, {required double current, required ValueChanged<double> onPick}) =>
      SizedBox(
        width: 232,
        child: Row(
          children: [
            const SizedBox(
              width: 56,
              child: Text(
                '区域',
                style: TextStyle(fontSize: AppControls.labelFontSize, color: AppOnVideo.textMuted),
              ),
            ),
            const Spacer(),
            PopupMenuButton<double>(
              initialValue: current,
              tooltip: i18n('settings_danmaku_area'),
              onSelected: onPick,
              color: Get.theme.colorScheme.surfaceContainerHighest,
              position: PopupMenuPosition.over,
              itemBuilder: (context) => [
                for (final (label, ratio) in const [('全屏', 1.0), ('3/4', 0.75), ('半屏', 0.5), ('1/4', 0.25)])
                  PopupMenuItem<double>(
                    value: ratio,
                    child: Row(
                      children: [
                        if (current == ratio)
                          Icon(Icons.check_rounded, size: 16, color: AppOnVideo.accent)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(label),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppOnVideo.textMuted),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(switch (current) {
                      0.75 => '3/4',
                      0.5 => '半屏',
                      0.25 => '1/4',
                      _ => '全屏',
                    }, style: const TextStyle(fontSize: AppFontSize.caption, color: AppOnVideo.text)),
                    const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppOnVideo.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// popover 内迷你开关(样式真源 CompactSwitch 30×16 密度的移植精简版:
/// 轨道 30×16、圆角 8、滑块 12;选中轨道品牌紫,未选中恒定亮描边 ——
/// 宿主是恒定暗底 popover,未选中色不随主题翻转)。
class _PopoverSwitch extends StatelessWidget {
  const _PopoverSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final track = AppOnVideo.accent;
    return Semantics(
      toggled: value,
      // 纯 GestureDetector 无光标反馈:外包 MouseRegion 补手型,不动布局。
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            width: 30,
            height: 16,
            decoration: BoxDecoration(
              color: value ? track : Colors.transparent,
              borderRadius: AppRadius.allMd,
              border: Border.all(color: value ? track : AppOnVideo.textMuted),
            ),
            child: AnimatedAlign(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value ? AppOnBright.white : AppOnVideo.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
