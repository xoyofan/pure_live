/// 录制中心的状态筛选(zishu 风格)。
///
/// pure_live 独有功能,zishu 无对应页面;chips 交互与视觉移植自
/// `zishu_app/features/follow/zishu_follow_filters.dart` 的平台筛选
/// (Wrap 自适应 + 品牌色圆点 + 选中 accent 淡底/accent 描边):
/// - 九档状态与 `RecorderPage.tabs` 同序同口径(全部/录制中/等待/队列/
///   重连/处理/完成/失败/已停止),文案沿用既有 `recorder_tab_*` key;
/// - 状态色只取主题 token:录制中用 liveBadge 绿、失败用 error 红、
///   完成用 success 绿、等待/重连用 brand 金(金色仅作状态强调)、
///   工作中档用 accent 紫、已停止用 textSecondary 灰。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 录制中心筛选档(下标即 chips 行顺序,对齐 `RecorderPage.tabs`)。
enum ZishuRecordFilter {
  all(null, 'recorder_tab_all'),
  running(RecordStatus.running, 'recorder_tab_recording'),
  waitingLive(RecordStatus.waitingLive, 'recorder_tab_waiting'),
  queued(RecordStatus.queued, 'recorder_tab_queue'),
  reconnecting(RecordStatus.reconnecting, 'recorder_tab_reconnecting'),
  processing(RecordStatus.processing, 'recorder_tab_processing'),
  completed(RecordStatus.completed, 'recorder_tab_completed'),
  failed(RecordStatus.failed, 'recorder_tab_failed'),
  stopped(RecordStatus.stopped, 'recorder_tab_stopped');

  const ZishuRecordFilter(this.status, this.labelKey);

  /// 该档对应的任务状态;`all` 档为 null(不过滤)。
  final RecordStatus? status;

  /// 文案 i18n key(已确认存在于 assets/translations/zh.json)。
  final String labelKey;

  /// 任务是否命中本档。
  bool matches(LiveRecordTask task) => status == null || task.status == status;
}

/// 任务状态 → 强调色。全部取主题 token,金色只用于等待/重连两档的强调;
/// 供筛选 chips 圆点与任务卡状态徽章共用,保证两处口径一致。
Color zishuRecordStatusColor(ZishuTokens tokens, RecordStatus status) {
  switch (status) {
    case RecordStatus.running:
      return tokens.liveBadge;
    case RecordStatus.preparing:
    case RecordStatus.queued:
    case RecordStatus.processing:
      return tokens.accent;
    case RecordStatus.waitingLive:
      return tokens.brandBright;
    case RecordStatus.reconnecting:
      return tokens.brandBright;
    case RecordStatus.completed:
      return tokens.success;
    case RecordStatus.failed:
      return tokens.error;
    case RecordStatus.stopped:
      return tokens.textSecondary;
  }
}

/// 状态九档筛选 chips 行:Wrap 自适应换行,选中态 accent 淡底 + accent
/// 描边,未选中 surface 底 + border 描边(样式同关注页平台 chips)。
/// 选中态由调用方持有(本组件不持状态),回调下发筛选档下标。
class ZishuRecorderStatusFilter extends StatelessWidget {
  const ZishuRecorderStatusFilter({super.key, required this.selectedIndex, required this.onSelected});

  /// 当前选中档下标(0..8,即 [ZishuRecordFilter.values] 顺序)。
  final int selectedIndex;

  /// 切换回调(下发筛选档下标)。
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < ZishuRecordFilter.values.length; index++)
          _RecordStatusChip(
            key: Key('record-status-$index'),
            label: i18n(ZishuRecordFilter.values[index].labelKey),
            dotColor: index == 0
                ? null
                : zishuRecordStatusColor(context.tokens, ZishuRecordFilter.values[index].status!),
            selected: index == selectedIndex,
            onTap: () => onSelected(index),
          ),
      ],
    );
  }
}

class _RecordStatusChip extends StatelessWidget {
  const _RecordStatusChip({super.key, required this.label, required this.selected, required this.onTap, this.dotColor});

  final String label;

  /// 状态圆点色;null 表示「全部」档,不画圆点。
  final Color? dotColor;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = tokens.accent;
    return InkWell(
      borderRadius: AppRadius.allSm,
      onTap: onTap,
      // 状态反馈(全部走 token,同关注页平台 chips):未选中 hover 抬亮到
      // surfaceRaised;已选中的底本身是 accent 淡底,hover 用 accent 低 alpha 加深。
      hoverColor: selected ? accent.withValues(alpha: 0.12) : tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(accent),
      highlightColor: AppStateLayer.pressedOf(accent),
      focusColor: AppStateLayer.focusOf(accent),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : tokens.surface,
          borderRadius: AppRadius.allSm,
          border: Border.all(color: selected ? accent : tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textBody.copyWith(
                fontSize: AppFontSize.bodySecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? tokens.textPrimary : tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
