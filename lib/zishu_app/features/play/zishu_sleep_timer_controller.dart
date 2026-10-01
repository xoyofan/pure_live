import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu_app/features/play/zishu_stage_hint.dart';

/// app 级睡眠定时(GetX 版),移植自 zishu_flutter
/// `lib/src/features/play/application/sleep_timer_provider.dart`。
///
/// **为什么必须是 app 级控制器(非随页销毁)**:真源 sleep_timer_provider.dart
/// 文件头注释同口径 —— 播放编排随播放页销毁,而睡眠定时的使用场景恰恰是
/// 「设完定时后不再盯着播放页」;定时挂应用根,生命周期与全局播放器一致
/// (仅 app 退出时释放)。播放页卸载**不**取消定时([ZishuSleepTimerController]
/// 静态 `to` 惰性注册 + fenix 常驻,不经任何 binding/路由挂载)。
///
/// 到点行为对齐真源 `_fire`(sleep_timer_provider.dart:120-124):
/// 先撤定时器防「复活」→ 停播;提示通路按本项目口径替换 —— 真源在
/// play_view.dart:415-429 经 `ref.listen(firedCount)` 弹 3s SnackBar,此处
/// 直接走舞台提示浮层(免 context 的 [ZishuStageHint.show],文案真源
/// play_view.dart:425 同款、时长 3s 同源)。停播走既有暂停接线:与
/// zishu_player_controls.dart 的播放/暂停按钮同一 [GlobalPlayerService]
/// 播放管理器([PlayerManager.pause] 对空闲态为空操作,未初始化时整段跳过)。
class ZishuSleepTimerController extends GetxController {
  /// 常用预设(分钟):真源 `SleepTimerController.presetsMinutes` 同值。
  static const List<int> presetsMinutes = [15, 30, 60, 90, 120];

  /// 自定义时长上限(分钟):真源 `maxCustomMinutes` 同值(12 小时)。
  static const int maxCustomMinutes = 720;

  /// 到点提示文案(真源 play_view.dart:425 同文案;无既有 i18n key、json 本轮
  /// 冻结,中文常量记录)。
  static const String firedHintText = '睡眠定时已到，已停止播放';

  /// `SettingsService.to` / `MyCategoryController.to` 同款快捷读取;首次访问
  /// 惰性注册:permanent = 不参与 smart management 回收、仅 app 退出释放,
  /// fenix = 万一被删下次 find 自动重建 —— 两者合起来等价真源「app 级
  /// provider 非 autoDispose」的常驻语义。
  static ZishuSleepTimerController get to {
    if (!Get.isRegistered<ZishuSleepTimerController>()) {
      Get.lazyPut<ZishuSleepTimerController>(ZishuSleepTimerController.new, fenix: true, permanent: true);
    }
    return Get.find<ZishuSleepTimerController>();
  }

  /// 到点时刻;null = 未启用(真源 SleepTimerState.endsAt 同语义)。
  final Rxn<DateTime> endsAt = Rxn<DateTime>();

  /// 剩余时长(由 1s 心跳推进,仅供 UI 显示;到点判定唯一由 [_deadline] 负责,
  /// 不用 `endsAt - now` 是真源 _tick 同口径:墙钟在定时器被节流的环境下会让
  /// 显示瞬间跳一大段)。
  final Rxn<Duration> remaining = Rxn<Duration>();

  /// 本次设定值(分钟):睡眠菜单「选中态打勾」的判定依据(真源状态里无此
  /// 字段、菜单也无打勾,属本项目 popover 的既有选盒同款选中标识)。
  final Rxn<int> totalMinutes = Rxn<int>();

  /// 到点用的截止定时器。
  Timer? _deadline;

  /// 1s 心跳:只推进 [remaining] 显示,不参与到点判定。
  Timer? _ticker;

  /// 是否处于启用态。
  bool get active => endsAt.value != null;

  /// 剩余时间文案(`mm:ss`,满 1 小时为 `h:mm:ss`);未启用返回空串。
  /// 真源 SleepTimerState.remainingLabel 同格式;须在 Obx 内读取才有响应性。
  String get remainingLabel {
    final value = remaining.value;
    if (value == null) return '';
    final total = value.inSeconds <= 0 ? 0 : value.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  /// 设定定时;时长 ≤ 0 等同取消(真源 start 同语义;起新定时前先撤旧,
  /// 避免双定时器同时到点)。
  void start(Duration duration) {
    if (duration <= Duration.zero) {
      cancel();
      return;
    }
    _cancelTimers();
    endsAt.value = DateTime.now().add(duration);
    remaining.value = duration;
    totalMinutes.value = duration.inMinutes;
    _deadline = Timer(duration, _fire);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// 取消定时:清定时器与心跳,状态回未启用(不触发停播,真源 cancel 同口径)。
  void cancel() {
    _cancelTimers();
    endsAt.value = null;
    remaining.value = null;
    totalMinutes.value = null;
  }

  void _tick() {
    final current = remaining.value;
    if (current == null) return;
    final next = current - const Duration(seconds: 1);
    // 只为 UI 进度:递减显示值,不参与判定;到点唯一由 [_deadline] 负责。
    if (next <= Duration.zero) return;
    remaining.value = next;
  }

  /// 到点:先撤定时器防复活再停播(真源 _fire 同序),随后舞台提示告知
  /// 「是被定时停的」(真源 play_view.dart:419 注释同语义,3s)。
  void _fire() {
    _cancelTimers();
    final wasActive = active;
    endsAt.value = null;
    remaining.value = null;
    totalMinutes.value = null;
    if (!wasActive) return;
    if (GlobalPlayerService.instance.initialized) {
      unawaited(GlobalPlayerService.instance.player.pause());
    }
    ZishuStageHint.show(firedHintText, duration: const Duration(seconds: 3));
  }

  void _cancelTimers() {
    _deadline?.cancel();
    _deadline = null;
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void onClose() {
    _cancelTimers();
    super.onClose();
  }
}
