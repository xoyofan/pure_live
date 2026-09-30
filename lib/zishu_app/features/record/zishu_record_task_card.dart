/// zishu 风格录制任务卡。
///
/// pure_live 独有功能,zishu 无对应卡片;按 zishu 设计语言把
/// `recorder/recorder_page.dart` 的大卡片重绘为紧凑行:
/// 封面缩略 + 信息 + 右侧操作钮。
/// - 卡片 = surface 底 + `AppRadius.allMd`(8px)圆角 + hairline
///   `tokens.border` 描边,无投影(对齐 ZishuRoomCard 基线);
/// - 封面缩略左上角叠状态徽章(coverScrim 暗底 + 状态色圆点 + 状态文案,
///   复用 [CoverBadge],状态色只作圆点强调);
/// - 信息列 = 标题 / 平台·主播 / 元信息 chips / 录制统计 / 告警与失败行;
/// - 操作钮按状态给档,口径与原 RecorderPage 完全一致(数据层不改):
///   工作中 → 移除+停止;队列 → 移除+立即开始+取消;可重启 → 移除+主操作。
///   CTA 用 accent 紫(主题 colorScheme.primary 已被接成品牌金,这里显式
///   走 tokens.accent,遵守「金色只用于强调」)。
library;

import 'package:cached_network_image/cached_network_image.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/widgets/cover_badges.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/record/zishu_recorder_filters.dart';

/// 封面缩略尺寸(16:9 紧凑档,信息列让出主宽)。
const double _kCoverWidth = 120;
const double _kCoverHeight = 68;

class ZishuRecordTaskCard extends StatelessWidget {
  const ZishuRecordTaskCard({super.key, required this.task, required this.controller});

  final LiveRecordTask task;
  final RecorderController controller;

  // 与原 RecorderPage._TaskCard 同一套状态口径(仅重绘,不改行为)。
  static const Set<RecordStatus> _workingStatuses = {
    RecordStatus.running,
    RecordStatus.reconnecting,
    RecordStatus.preparing,
  };
  static const Set<RecordStatus> _restartableStatuses = {
    RecordStatus.failed,
    RecordStatus.stopped,
    RecordStatus.waitingLive,
    RecordStatus.completed,
    RecordStatus.processing,
  };

  void _openRoom() {
    AppNavigator.toLiveRoomDetail(
      liveRoom: LiveRoom(
        roomId: task.roomId,
        platform: task.platform,
        title: task.title,
        nick: task.nick,
        avatar: task.avatar,
        cover: task.cover,
        watching: task.watching,
        followers: task.followers,
        audienceMetricType: task.audienceMetricType,
        liveStatus: task.liveStatus,
      ),
    );
  }

  // ---- 文案/格式化(逻辑照抄原页面,只换落点) ----

  String _audienceText() {
    final labelKey = switch (task.audienceMetricType) {
      AudienceMetricType.popularity => 'audience_popularity',
      AudienceMetricType.onlineViewers => 'audience_online',
      AudienceMetricType.totalViewers => 'audience_total',
      AudienceMetricType.followers => 'audience_followers',
      AudienceMetricType.unknown => 'audience_count',
    };
    return '${i18n(labelKey)} ${readableCount(task.watching)}';
  }

  String _failureStageText() {
    final stage = task.lastErrorStage;
    if (stage == 'ffmpeg' || stage?.startsWith('ffmpeg.') == true) {
      return i18n('recorder_stage_ffmpeg');
    }
    return switch (stage) {
      'room' => i18n('recorder_stage_room'),
      'quality' => i18n('recorder_stage_quality'),
      'stream' => i18n('recorder_stage_stream'),
      'network' => i18n('recorder_stage_network'),
      'merge' => i18n('recorder_stage_merge'),
      'scheduler' => i18n('recorder_stage_scheduler'),
      'status' => i18n('recorder_stage_status'),
      'background' => i18n('recorder_stage_background'),
      _ => i18n('recorder_stage_unknown'),
    };
  }

  String _formatDuration(int sec) {
    final d = Duration(seconds: sec);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 ${i18n('unit_b')}';
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} ${i18n('unit_gb')}';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} ${i18n('unit_mb')}';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} ${i18n('unit_kb')}';
    return '$bytes ${i18n('unit_b')}';
  }

  String _formatBitrate(double kilobitsPerSecond) {
    if (!kilobitsPerSecond.isFinite || kilobitsPerSecond <= 0) return '--';
    if (kilobitsPerSecond >= 1000) return '${(kilobitsPerSecond / 1000).toStringAsFixed(1)} Mbps';
    return '${kilobitsPerSecond.toStringAsFixed(0)} kbps';
  }

  /// 开始时间(与原页同口径:`DateTime.toString()` 的 `MM-dd HH:mm` 段)。
  String get _startTimeText => task.displayStartTime.toString().substring(5, 16);

  bool get _showStats =>
      _workingStatuses.contains(task.status) ||
      const {RecordStatus.processing}.contains(task.status) ||
      task.recordedSeconds > 0 ||
      task.fileSize > 0;

  // ---- 视觉 ----

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final statusColor = zishuRecordStatusColor(tokens, task.status);
    final brand = PlatformBrandCatalog.byId(task.platform);
    final platformName = brand?.name ?? task.platform.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: tokens.border),
      ),
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: _openRoom,
        hoverColor: tokens.surfaceRaised,
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(tokens, statusColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildInfo(context, tokens, brand?.color, platformName)),
              const SizedBox(width: AppSpacing.sm),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(ZishuTokens tokens, Color statusColor) {
    final coverUrl = normalizeNetworkImageUrl(task.cover);
    return SizedBox(
      width: _kCoverWidth,
      height: _kCoverHeight,
      child: ClipRRect(
        borderRadius: AppRadius.allSm,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: tokens.surfaceSoft,
                child: coverUrl.isEmpty
                    ? Center(child: Icon(Icons.videocam_outlined, size: 20, color: tokens.textSecondary))
                    : CachedNetworkImage(
                        imageUrl: coverUrl,
                        cacheKey: coverUrl,
                        cacheManager: CustomImageCacheManager.instance,
                        httpHeaders: networkImageHeaders(coverUrl),
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        useOldImageOnUrlChange: true,
                        placeholder: (_, _) => ColoredBox(color: tokens.surfaceRaised),
                        errorWidget: (_, _, _) =>
                            Center(child: Icon(Icons.videocam_outlined, size: 20, color: tokens.textSecondary)),
                      ),
              ),
            ),
            // 状态徽章:coverScrim 暗底 + 状态色圆点,金色/红色只作圆点强调。
            Positioned(
              left: 0,
              bottom: 0,
              child: CoverBadge(
                corner: CoverCorner.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(task.status.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ZishuTokens tokens, Color? brandColor, String platformName) {
    final warnings = [
      if (task.inputCoverageIncomplete) i18n('recorder_input_coverage_incomplete'),
      if (task.inputTailDiscarded) i18n('recorder_input_tail_discarded'),
    ];
    final hasError = task.lastError?.isNotEmpty == true && task.status != RecordStatus.running;
    final statsStyle = context.textCaption.copyWith(
      color: tokens.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            if (brandColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: brandColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                brandColor != null ? '$platformName · ${task.nick}' : '${task.nick} · ${task.platform.toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textCaption,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(task.selectedQuality ?? i18n('recorder_auto'), style: context.textCaption),
            if (task.selectedLine?.isNotEmpty == true)
              Text(task.selectedLine!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textCaption),
            Text(_audienceText(), style: context.textCaption),
            Text(_startTimeText, style: context.textCaption),
          ],
        ),
        if (_showStats) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              _formatDuration(task.recordedSeconds),
              _formatFileSize(task.fileSize),
              '${task.recordSpeed.toStringAsFixed(1)}x',
              _formatBitrate(task.bitrate),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: statsStyle,
          ),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 13, color: tokens.brandBright),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  warnings.join('\n'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textCaption.copyWith(color: tokens.brandBright),
                ),
              ),
            ],
          ),
        ],
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 13, color: tokens.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  i18n('recorder_last_error', args: {'stage': _failureStageText(), 'error': task.lastError!}),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textCaption.copyWith(color: tokens.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 右侧操作钮(状态口径与原页面一致,视觉收敛为紧凑 zishu 按钮)。
  Widget _buildActions() {
    final status = task.status;

    if (_workingStatuses.contains(status)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RemoveTaskAction(task: task, controller: controller),
          const SizedBox(height: AppSpacing.xs),
          _TaskAction(
            label: i18n('recorder_stop'),
            tone: _ActionTone.danger,
            onPressed: () => controller.stopTask(task),
          ),
        ],
      );
    }

    if (status == RecordStatus.queued) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RemoveTaskAction(task: task, controller: controller),
          const SizedBox(height: AppSpacing.xs),
          _TaskAction(
            label: i18n('recorder_start'),
            tone: _ActionTone.accent,
            onPressed: () => controller.forceStartTask(task),
          ),
          const SizedBox(height: AppSpacing.xs),
          _TaskAction(label: i18n('cancel'), tone: _ActionTone.outline, onPressed: () => controller.stopTask(task)),
        ],
      );
    }

    if (_restartableStatuses.contains(status)) {
      final label = switch (status) {
        RecordStatus.failed => i18n('retry'),
        RecordStatus.waitingLive => i18n('recorder_check_now'),
        RecordStatus.completed => i18n('recorder_restart_record'),
        _ => i18n('recorder_start'),
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RemoveTaskAction(task: task, controller: controller),
          const SizedBox(height: AppSpacing.xs),
          _TaskAction(label: label, tone: _ActionTone.accent, onPressed: () => controller.forceStartTask(task)),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ---- 操作钮 ----

/// 操作钮色板:accent 紫 = 主操作/CTA;error 红 = 停止与移除;
/// outline = 取消等次级操作。金色不作控件色(zishu 口径)。
enum _ActionTone { accent, danger, outline, textDanger }

class _TaskAction extends StatelessWidget {
  const _TaskAction({required this.label, required this.tone, this.onPressed});

  final String label;
  final _ActionTone tone;

  /// null = 禁用(移除确认/移除执行期间的忙态)。
  final VoidCallback? onPressed;

  ButtonStyle _style(BuildContext context) {
    final tokens = context.tokens;
    // styleFrom 的 shape/textStyle 收裸值(OutlinedBorder?/TextStyle?),
    // 与原页 FilledButton.styleFrom 用法一致。
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.allSm);
    const density = VisualDensity.compact;
    const tap = MaterialTapTargetSize.shrinkWrap;
    const textStyle = TextStyle(fontSize: AppFontSize.bodySecondary, fontWeight: FontWeight.w600);
    const padding = EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0);
    const minimumSize = Size(0, 30);
    return switch (tone) {
      _ActionTone.accent => FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: AppOnBright.white,
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: tap,
        visualDensity: density,
        shape: shape,
        textStyle: textStyle,
      ),
      _ActionTone.danger => FilledButton.styleFrom(
        backgroundColor: tokens.error,
        foregroundColor: AppOnBright.white,
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: tap,
        visualDensity: density,
        shape: shape,
        textStyle: textStyle,
      ),
      _ActionTone.outline => OutlinedButton.styleFrom(
        foregroundColor: tokens.textSecondary,
        side: BorderSide(color: tokens.border),
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: tap,
        visualDensity: density,
        shape: shape,
        textStyle: textStyle,
      ),
      _ActionTone.textDanger => TextButton.styleFrom(
        foregroundColor: tokens.error,
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: tap,
        visualDensity: density,
        shape: shape,
        textStyle: textStyle,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    return switch (tone) {
      _ActionTone.accent || _ActionTone.danger => FilledButton(style: style, onPressed: onPressed, child: Text(label)),
      _ActionTone.outline => OutlinedButton(style: style, onPressed: onPressed, child: Text(label)),
      _ActionTone.textDanger => TextButton(style: style, onPressed: onPressed, child: Text(label)),
    };
  }
}

/// 「移除监控」按钮:确认后 `unRecorder`(口径同原 `_RemoveMonitorButton`,
/// 忙态防重入)。文案沿用既有 key(报告轨确认过均在 zh.json)。
class _RemoveTaskAction extends StatefulWidget {
  const _RemoveTaskAction({required this.task, required this.controller});

  final LiveRecordTask task;
  final RecorderController controller;

  @override
  State<_RemoveTaskAction> createState() => _RemoveTaskActionState();
}

class _RemoveTaskActionState extends State<_RemoveTaskAction> {
  bool _busy = false;

  String _displayName(LiveRecordTask task) {
    for (final value in [task.title, task.nick, task.roomId]) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '--';
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);
    final target = widget.task;
    try {
      final ok = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          title: Text(i18n('recorder_cancel_monitor')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(i18n('recorder_cancel_monitor_confirm_named', args: {'name': _displayName(target)})),
          ),
          actionsOverflowButtonSpacing: AppSpacing.sm,
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: dialogContext.tokens.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(i18n('confirm')),
            ),
          ],
        ),
      );
      if (ok == true) await widget.controller.unRecorder(target);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 忙态禁用(同原按钮 onPressed: null 的置灰语义)。
    return _TaskAction(label: i18n('remove'), tone: _ActionTone.textDanger, onPressed: _busy ? null : _remove);
  }
}
