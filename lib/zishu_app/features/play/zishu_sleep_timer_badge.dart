import 'package:pure_live/common/index.dart';

import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/zishu_sleep_timer_controller.dart';

/// 舞台右上角的睡眠定时倒计时 pill,移植自 zishu_flutter
/// `lib/src/features/play/views/play_view.dart:1465` 的 `_SleepTimerBadge`
/// (锚点 `play-sleep-remaining`)。
///
/// 不放进控制条:控制条在沉浸态会淡出,而「还有多久停」属于需要一直可见的状态。
/// 本组件自带舞台定位([Positioned] top/right = [AppSpacing.sm],对齐真源
/// play_view.dart:527-531 的包裹方式),**必须作为舞台 [Stack] 的直接子级放置**。
///
/// 数据源(2026-10 改):app 级 [ZishuSleepTimerController](真源
/// sleepTimerProvider 语义:定时挂应用根,离开播放页不清,到点自动停播并清态)。
/// Obx 订阅 `active` 与 `remaining`(控制器内 1s 心跳推进,本组件不再自备
/// 计时器);无定时(含到点/取消后的未启用态)渲染 [SizedBox.shrink]。
/// 剩余文案沿用既有 i18n key `play_sleep_timer_remaining`。
///
/// 旧房间级定时链路(LivePlayController.ui.closeTimes/applyRoomPlaybackTimer
/// 经 RoomTimerDialog)仍在 legacy 菜单可达
/// (live_play_menu_button.dart:112),本 badge 不再读它 —— 旧定时此后没有
/// 舞台呈现,可见链路只走 app 级控制器(真源同口径:可见状态与到点行为
/// 单一来源)。
class ZishuSleepTimerBadge extends StatelessWidget {
  const ZishuSleepTimerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final timer = ZishuSleepTimerController.to;
    return Obx(() {
      if (!timer.active) return const SizedBox.shrink();
      return Positioned(
        top: AppSpacing.sm,
        right: AppSpacing.sm,
        child: _SleepTimerPill(remaining: timer.remainingLabel),
      );
    });
  }
}

/// pill 本体:样式逐字移植 zishu `_SleepTimerBadge`
/// (play_view.dart:1465-1497)。
class _SleepTimerPill extends StatelessWidget {
  const _SleepTimerPill({required this.remaining});

  /// 剩余时间文案(`mm:ss` / `h:mm:ss`)。
  final String remaining;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      key: const Key('play-sleep-remaining'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(color: tokens.surfaceRaised.withValues(alpha: 0.72), borderRadius: AppRadius.allPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bedtime_rounded, size: 14, color: tokens.accent),
          const SizedBox(width: AppSpacing.xs),
          Text(
            i18n('play_sleep_timer_remaining', args: {'time': remaining}),
            style: context.textCaption.copyWith(color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}
