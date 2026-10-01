/// zishu 设置弹窗「全面扁平化」共享紧凑行部件(2026-10 任务D)。
///
/// 行样式统一口径(用户裁决:所有点击弹新页面的改为折叠就地展开):
/// - **标题与说明同一行**:说明跟在标题后,`context.textSecondary` 弱化,
///   超长 ellipsis,不再两行堆叠;
/// - **行高紧凑**:上下 padding 压到 [AppSpacing.xs](4px)级;
/// - **开关一律 [CompactSwitch]**(30×16 迷你开关,全局统一口径,视觉对齐一行高度);
/// - 下拉/滑杆同样一行化,滑杆走 [AppControls] 的 3px 轨道 + 6px 滑块;
/// - 颜色/字号/圆角/动效全走 design_tokens 与 zishu tokens,零裸值。
library;

import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/compact_switch.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 一行设置的通用骨架:标题 + 同行弱化说明 + 尾部控件,整行可点([onTap])。
class ZishuSettingLine extends StatelessWidget {
  const ZishuSettingLine({
    super.key,
    required this.title,
    this.desc,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.danger = false,
  });

  final String title;

  /// 同行说明:跟在标题后弱化展示,超长 ellipsis(不再两行堆叠)。
  final String? desc;

  /// 尾部控件(迷你开关 / 下拉 / 图标 / 进度等)。
  final Widget? trailing;

  /// 整行点击回调(null = 不可点,不挂手势)。
  final VoidCallback? onTap;

  /// false 时标题转次级色(如 busy 禁用态)。
  final bool enabled;

  /// 危险动作(清除缓存等)标题用 error 色。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final titleColor = !enabled ? tokens.textSecondary : (danger ? tokens.error : tokens.textPrimary);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textBody.copyWith(fontWeight: FontWeight.w600, color: titleColor),
              ),
            ),
            if (desc != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(desc!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textSecondary),
              ),
            ] else
              const Spacer(),
            if (trailing != null) ...[const SizedBox(width: AppSpacing.md), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 一行迷你开关:绑定响应式布尔(写入即经 HiveRx 自动持久化),内部 Obx 即时刷新。
///
/// [read]/[onChanged] 闭包形态便于绑定「按 id 计算」的布尔(如平台在线人数
/// 开关);绑定裸 [RxBool] 用 [ZishuSwitchLine.rx] 构造。整行点击 = 切换
/// (对齐 SwitchListTile 行为);[onChanged] 为 null 时视为禁用。
class ZishuSwitchLine extends StatelessWidget {
  const ZishuSwitchLine({super.key, required this.title, this.desc, required this.read, required this.onChanged});

  /// 绑定裸 [RxBool] 的便捷构造:直接读 Rx、写入即持久化。
  factory ZishuSwitchLine.rx({Key? key, required String title, String? desc, required RxBool rx}) {
    return ZishuSwitchLine(key: key, title: title, desc: desc, read: () => rx.v, onChanged: (v) => rx.v = v);
  }

  final String title;
  final String? desc;

  /// Obx 内读取当前值(必须读 Rx 才会被 Obx 追踪)。
  final bool Function() read;

  /// 开关回调(null = 禁用)。
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Obx(
      () => ZishuSettingLine(
        title: title,
        desc: desc,
        enabled: !disabled,
        onTap: disabled ? null : () => onChanged!(!read()),
        trailing: Opacity(
          // 禁用态视觉:半透明 + no-op(CompactSwitch.onChanged 非空)。
          opacity: disabled ? 0.45 : 1,
          child: CompactSwitch(value: read(), onChanged: disabled ? (_) {} : onChanged!),
        ),
      ),
    );
  }
}

/// 一行下拉:候选 [values] + 当前值(经 [readValue] 在 Obx 内读取),
/// 已存值不在候选时并到候选尾,避免 DropdownButton.value 断言失败。
class ZishuDropdownLine<T> extends StatelessWidget {
  const ZishuDropdownLine({
    super.key,
    required this.title,
    this.desc,
    required this.values,
    required this.labelOf,
    required this.readValue,
    required this.onChanged,
  });

  final String title;
  final String? desc;
  final List<T> values;
  final String Function(T value) labelOf;

  /// Obx 内读取当前值(必须读 Rx 才会被 Obx 追踪)。
  final T Function() readValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(() {
      final current = readValue();
      final items = values.contains(current) ? values : [...values, current];
      return ZishuSettingLine(
        title: title,
        desc: desc,
        trailing: DropdownButton<T>(
          value: current,
          underline: const SizedBox.shrink(),
          isDense: true,
          padding: EdgeInsets.zero,
          icon: Icon(Icons.expand_more_rounded, size: 16, color: tokens.textSecondary),
          style: context.textBody,
          items: [for (final value in items) DropdownMenuItem<T>(value: value, child: Text(labelOf(value)))],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      );
    });
  }
}

/// 一行滑杆:标签 + 紧凑滑杆 + 右侧数值。滑杆规格取 [AppControls]
/// (轨道 3px / 滑块半径 6,对齐 web el-slider 紧凑视觉),accent 走 tokens。
class ZishuSliderLine extends StatelessWidget {
  const ZishuSliderLine({
    super.key,
    required this.title,
    required this.min,
    required this.max,
    this.stepSize,
    required this.readValue,
    required this.onChanged,
    this.displayOf,
  });

  final String title;
  final double min;
  final double max;

  /// 步长(null = 连续)。
  final double? stepSize;

  /// Obx 内读取当前值(必须读 Rx 才会被 Obx 追踪)。
  final double Function() readValue;
  final ValueChanged<double> onChanged;

  /// 数值展示文案(缺省一位小数)。
  final String Function(double value)? displayOf;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(() {
      final value = readValue().clamp(min, max);
      final display = displayOf?.call(value) ?? value.toStringAsFixed(1);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.xs),
        child: SizedBox(
          height: 24,
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textBody.copyWith(fontSize: AppFontSize.bodySecondary, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: AppControls.sliderTrackHeight,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppControls.sliderThumbRadius),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: stepSize == null ? null : ((max - min) / stepSize!).round(),
                    label: display,
                    activeColor: tokens.accent,
                    inactiveColor: tokens.accent.withValues(alpha: 0.15),
                    onChanged: onChanged,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 48,
                child: Text(
                  display,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: context.textBody.copyWith(fontSize: AppFontSize.bodySecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// 展开区里的小节标题(caption 弱化)。
class ZishuSectionCaption extends StatelessWidget {
  const ZishuSectionCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textCaption),
    );
  }
}

/// 嵌套手风琴行(原「跳子页」行的就地展开变体):图标块(28×28)+ 标题 +
/// 同行说明 + 旋转 chevron;点击 [onToggle] 原地展开/收起 [child]。
///
/// 与组头 [_AccordionSection] 同机制(AnimatedSize + ClipRect),尺寸缩一档
/// (图标 28×28 / 16px),展开内容左缩进 36 与标题对齐。
class ZishuExpandLine extends StatelessWidget {
  const ZishuExpandLine({
    super.key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: AppRadius.allSm,
          hoverColor: tokens.surfaceRaised,
          splashColor: AppStateLayer.splashOf(tokens.accent),
          highlightColor: AppStateLayer.pressedOf(tokens.accent),
          focusColor: AppStateLayer.focusOf(tokens.accent),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
                  child: Icon(icon, size: 16, color: tokens.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textBody.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textSecondary),
                ),
                const SizedBox(width: AppSpacing.sm),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                  child: Icon(Icons.expand_more_rounded, size: 18, color: tokens.textSecondary),
                ),
              ],
            ),
          ),
        ),
        // 原地展开/收起:高度动画走 AnimatedSize(fast),收起态用定宽零高
        // SizedBox 保住宽度约束;ClipRect 防止动画中内容溢出画到组外。
        ClipRect(
          child: AnimatedSize(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(left: 36, top: AppSpacing.xs, bottom: AppSpacing.xs),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

/// zishu 风格单选 chip(样式对齐 follow 筛选 chips):选中 accent 淡底 +
/// accent 描边 + w700,未选中 surface 底 + border 描边 + w400。
class ZishuOptionChip extends StatelessWidget {
  const ZishuOptionChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      borderRadius: AppRadius.allSm,
      onTap: onTap,
      hoverColor: selected ? tokens.accent.withValues(alpha: 0.12) : tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? tokens.accent.withValues(alpha: 0.18) : tokens.surface,
          borderRadius: AppRadius.allSm,
          border: Border.all(color: selected ? tokens.accent : tokens.border),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textBody.copyWith(
            fontSize: AppFontSize.bodySecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? tokens.textPrimary : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 拖拽排序 chip 的包装:外层 [DragTarget] + 内层 [Draggable]。
///
/// [draggable] = false 时不可拖(隐藏条目,对齐原页「隐藏行没有持久化顺序,
/// 不可拖拽」口径),但仍可作为放置目标?—— 不,[acceptEnabled] 为 false 时
/// 也不接收(隐藏条目不在持久化顺序表里,插入无意义)。
class ZishuDragChip extends StatelessWidget {
  const ZishuDragChip({
    super.key,
    required this.data,
    required this.draggable,
    required this.onAccepted,
    required this.child,
  });

  /// 本 chip 携带的 id(拖拽数据 / 放置判定)。
  final String data;

  /// 是否可拖拽(同时决定本 chip 是否接收放置)。
  final bool draggable;

  /// 有条目拖到本 chip 上时的回调(参数为被拖条目 id)。
  final void Function(String draggedId) onAccepted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => draggable && details.data != data,
      onAcceptWithDetails: (details) => onAccepted(details.data),
      builder: (context, candidate, _) {
        final highlighted = candidate.isNotEmpty;
        return Draggable<String>(
          data: data,
          maxSimultaneousDrags: draggable ? 1 : 0,
          dragAnchorStrategy: childDragAnchorStrategy,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.85, child: child),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: child),
          child: highlighted
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.allSm,
                    border: Border.all(color: tokens.accent),
                  ),
                  child: child,
                )
              : child,
        );
      },
    );
  }
}

/// 紧凑输入框装饰(isDense + allSm 圆角),代理地址/端口、UA、昵称等共用。
InputDecoration zishuDenseInput(
  BuildContext context,
  String label, {
  String? hint,
  String? errorText,
  String? counterText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    errorMaxLines: 3,
    counterText: counterText,
    isDense: true,
    border: OutlineInputBorder(borderRadius: AppRadius.allSm),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
  );
}

/// 小尺寸加载圈(14px / 2px 描边),行尾 busy 态共用。
Widget zishuMiniSpinner(BuildContext context, {Color? color}) {
  return SizedBox.square(
    dimension: 14,
    child: CircularProgressIndicator(strokeWidth: 2, color: color ?? context.tokens.accent),
  );
}

/// 尾部 chevron 小图标(原「跳子页」行语义改为「弹深层管理对话框」的暗示)。
Widget zishuLineChevron(BuildContext context) {
  return Icon(Icons.chevron_right_rounded, size: 18, color: context.tokens.textSecondary);
}

/// 「更多设置」类重管理页的对话框宿主(任务D 口径:设置弹窗内不再推整页,
/// 深层管理页以对话框形态弹出、内容原样保留;调用方负责先 [ensureBinding]
/// 补注册该页路由本会执行的 GetX 绑定)。
class ZishuPageHostDialog {
  ZishuPageHostDialog._();

  static Future<void> show(BuildContext context, {required Widget page, VoidCallback? ensureBinding}) async {
    ensureBinding?.call();
    final viewport = MediaQuery.sizeOf(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: context.tokens.barrier,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allLg),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: math.min(viewport.width * 0.86, 720),
          height: math.min(viewport.height * 0.8, 720),
          child: page,
        ),
      ),
    );
  }
}
