import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// SegmentedButton 的 zishu 风格(移植 zishu follow_view 工具行的样式):
/// 选中段 accent 淡底 + accent 前景,未选中 surface 底 + 次级文字,
/// 1px `tokens.border` 描边 + `AppRadius.allSm` 圆角 + 紧凑密度。
/// 供状态筛选与卡片/列表两档切换共用。
ButtonStyle zishuFollowSegmentedStyle(BuildContext context) {
  final tokens = context.tokens;
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? tokens.accent.withValues(alpha: 0.18) : tokens.surface,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? tokens.accent : tokens.textSecondary,
    ),
    side: WidgetStatePropertyAll(BorderSide(color: tokens.border)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppRadius.allSm)),
    textStyle: WidgetStatePropertyAll(
      context.textBody.copyWith(fontSize: AppFontSize.bodySecondary, fontWeight: FontWeight.w600),
    ),
  );
}

/// 状态三段筛选:开播 / 录播 / 未开播。
///
/// 下标即 [FavoriteController.tabOnlineIndex] 的 0/1/2(对齐收藏页
/// 状态 tab 的口径),文案沿用 pure_live 收藏页既有 i18n key;
/// 选中态由调用方从控制器读,回调走 `animateToStatusIndex` 同步 tabController。
class ZishuFollowStatusFilter extends StatelessWidget {
  const ZishuFollowStatusFilter({super.key, required this.selectedIndex, required this.onSelected});

  /// 当前选中段(0 开播 / 1 录播 / 2 未开播)。
  final int selectedIndex;

  /// 切换回调(下发控制器,本组件不持有状态)。
  final ValueChanged<int> onSelected;

  static const List<String> _labelKeys = ['online_room_title', 'recording_room_title', 'offline_room_title'];

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        for (var index = 0; index < _labelKeys.length; index++)
          ButtonSegment(
            value: index,
            label: Text(i18n(_labelKeys[index]), key: Key('follow-status-$index')),
          ),
      ],
      // tabOnlineIndex 恒为 0..2,与 _labelKeys 一一对应,无需钳制
      // (num.clamp 返回 num,这里直接透传保持 int 类型)。
      selected: {selectedIndex},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onSelected(selection.first),
      style: zishuFollowSegmentedStyle(context),
    );
  }
}

/// 平台筛选 chips:全平台 + 各有关注的平台(站点表由调用方传
/// `FavoriteController.availableFavoriteSites`)。
///
/// 交互移植 zishu follow_platform_filter.dart 的页面态(Wrap 自适应,
/// 品牌色圆点):选中态用平台品牌色(「全平台」用 accent)点缀淡底与
/// 描边,文字对比度交给主题文字色。
class ZishuFollowPlatformFilter extends StatelessWidget {
  const ZishuFollowPlatformFilter({
    super.key,
    required this.sites,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// 候选平台表(含首位「全部」)。
  final List<Site> sites;

  /// 当前选中下标;-1 表示站点表与控制器索引暂不一致(全部不选)。
  final int selectedIndex;

  /// 切换回调(下发 `FavoriteController.selectSiteIndex`)。
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < sites.length; index++)
          _PlatformChip(
            label: sites[index].name,
            accent: _accentOf(context, sites[index]),
            showDot: sites[index].id != Sites.allSite,
            selected: index == selectedIndex,
            onTap: () => onSelected(index),
          ),
      ],
    );
  }

  Color _accentOf(BuildContext context, Site site) {
    if (site.id == Sites.allSite) return context.tokens.accent;
    return PlatformBrandCatalog.byId(site.id)?.color ?? context.tokens.accent;
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.label,
    required this.accent,
    required this.showDot,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool showDot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      borderRadius: AppRadius.allSm,
      onTap: onTap,
      // 状态反馈(全部走 token):未选中 hover 抬亮到 surfaceRaised;
      // 已选中的底本身是 accent 淡底,hover 用 accent 低 alpha 加深。
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
            if (showDot) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
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
