import 'dart:async';

import 'package:pure_live/common/index.dart';

import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 舞台右上角的睡眠定时倒计时 pill,移植自 zishu_flutter
/// `lib/src/features/play/views/play_view.dart:1465` 的 `_SleepTimerBadge`
/// (锚点 `play-sleep-remaining`)。
///
/// 不放进控制条:控制条在沉浸态会淡出,而「还有多久停」属于需要一直可见的状态。
/// 本组件自带舞台定位([Positioned] top/right = [AppSpacing.sm],对齐真源
/// play_view.dart:527-531 的包裹方式),**必须作为舞台 [Stack] 的直接子级放置**。
///
/// 数据源(pure_live 真实 API,非 zishu 的 SleepTimerState):
/// [LivePlayController.state](`Rx<LivePlayState>`)里的 `ui.closeTimeFlag`
/// (定时开关)与 `ui.closeTimes`(分钟数),由
/// [LivePlayController.applyRoomPlaybackTimer] /
/// `updateTimerFlag` / `updateTimerTimes` 写入
/// (lib/modules/live_play/controllers/live_play_controller.dart:647-668);
/// 无定时器(`closeTimeFlag == false`,含到时自动结束)时渲染
/// [SizedBox.shrink]。
///
/// 底层 StopWatchTimer 倒计时封装在 TimerController 内、未暴露剩余时间流
/// (lib/modules/live_play/controllers/timer_controller.dart),故剩余时间由本
/// 组件按「开关翻转 / 分钟数变更即重启」的口径本地推算 —— 该时机与
/// `TimerController.toggleTimer` 的重启点一一对应;每秒 tick 刷新显示,
/// 到 00:00 后保持显示直到控制器把 `closeTimeFlag` 置 false。
class ZishuSleepTimerBadge extends StatefulWidget {
  const ZishuSleepTimerBadge({super.key, this.controller});

  /// 播放控制器:缺省时按 GetX 惯例 `Get.find<LivePlayController>()`
  /// (与 ZishuPlayView 同口径,未注册时渲染空)。
  final LivePlayController? controller;

  @override
  State<ZishuSleepTimerBadge> createState() => _ZishuSleepTimerBadgeState();
}

class _ZishuSleepTimerBadgeState extends State<ZishuSleepTimerBadge> {
  /// 每秒一跳的显示刷新。
  static const Duration _tickInterval = Duration(seconds: 1);

  Timer? _ticker;

  /// 当前倒计时截止时刻;null = 无定时。
  DateTime? _endsAt;

  /// 上次同步到的控制器状态(检测 toggleTimer 的重启点)。
  bool _lastEnabled = false;
  int _lastMinutes = -1;

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  /// 把控制器的定时状态同步进本地倒计时。
  /// 在 Obx 求值内调用,只改字段/计时器,不触发 setState(刷新由 tick 驱动)。
  void _syncSchedule({required bool enabled, required int minutes}) {
    if (enabled == _lastEnabled && minutes == _lastMinutes) return;
    _lastEnabled = enabled;
    _lastMinutes = minutes;
    if (!enabled) {
      _endsAt = null;
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    // 与 TimerController.toggleTimer 的重启时机对齐:开关翻转或时长变更
    // 都会重启底层 StopWatchTimer,这里同步重设倒计时起点。
    _endsAt = DateTime.now().add(Duration(minutes: minutes < 1 ? 1 : minutes));
    _ticker ??= Timer.periodic(_tickInterval, (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Duration get _remaining {
    final endsAt = _endsAt;
    if (endsAt == null) return Duration.zero;
    final remaining = endsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// `mm:ss`;满 1 小时进位为 `h:mm:ss`(对齐 zishu remainingLabel 口径)。
  String _formatRemaining(Duration remaining) {
    final totalSeconds = remaining.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '${two(minutes)}:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final LivePlayController controller;
    if (widget.controller != null) {
      controller = widget.controller!;
    } else if (Get.isRegistered<LivePlayController>()) {
      controller = Get.find<LivePlayController>();
    } else {
      // binding 未就绪(直接热预览等):不渲染。
      return const SizedBox.shrink();
    }
    return Obx(() {
      final ui = controller.state.value.ui;
      _syncSchedule(enabled: ui.closeTimeFlag, minutes: ui.closeTimes);
      if (!ui.closeTimeFlag) return const SizedBox.shrink();
      return Positioned(
        top: AppSpacing.sm,
        right: AppSpacing.sm,
        child: _SleepTimerPill(remaining: _formatRemaining(_remaining)),
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
          Text('定时 $remaining', style: context.textCaption.copyWith(color: tokens.textPrimary)),
        ],
      ),
    );
  }
}
