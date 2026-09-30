import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// zishu 风格关注空态(移植 zishu FollowEmptyState 的视觉:心形图标 +
/// 标题 + 说明 + 操作按钮),文案与动作沿用 pure_live 收藏页口径:
/// - 全局无关注 → `empty_favorite_online_*`;
/// - 有关注但当前筛选为空 → 按状态给 `favorite_empty_*_title`,
///   说明区分「此平台暂无」/「关注数据仍在,共 {count} 个」;
/// - 未开播档有数据时给「查看未开播」直达,否则给重试。
class ZishuFollowEmptyState extends StatelessWidget {
  const ZishuFollowEmptyState({super.key, required this.controller});

  final FavoriteController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(() {
      final statusIndex = controller.tabOnlineIndex.value;
      final globalTotal = SettingsService.to.fav.favoriteRooms.v.length;
      final totalForSite = controller.favoriteCountForSite(_activeSiteId());
      final offlineForSite = controller.favoriteCountForSite(_activeSiteId(), statusIndex: 2);

      final String title;
      final String subtitle;
      if (globalTotal == 0) {
        title = i18n('empty_favorite_online_title');
        subtitle = i18n('empty_favorite_online_subtitle');
      } else {
        title = switch (statusIndex) {
          1 => i18n('favorite_empty_recording_title'),
          2 => i18n('favorite_empty_offline_title'),
          _ => i18n('favorite_empty_online_title'),
        };
        subtitle = i18n(totalForSite == 0 ? 'favorite_empty_platform_subtitle' : 'favorite_empty_filter_subtitle')
            .replaceAll('{count}', totalForSite.toString());
      }
      final canShowOffline = statusIndex != 2 && offlineForSite > 0;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 44, color: tokens.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: context.textTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, textAlign: TextAlign.center, style: context.textSecondary),
            const SizedBox(height: AppSpacing.lg),
            if (canShowOffline)
              OutlinedButton(
                onPressed: () => controller.animateToStatusIndex(2),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.accent,
                  side: BorderSide(color: tokens.border),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.allSm),
                ),
                child: Text(i18n('favorite_show_offline')),
              )
            else
              zishu.RetryButton(onRetry: controller.refreshData),
          ],
        ),
      );
    });
  }

  /// 当前激活平台 id(站点表与控制器索引短暂不一致时回退全平台,
  /// `favoriteCountForSite` 对 allSite 直接取总数)。
  String _activeSiteId() {
    final sites = controller.availableFavoriteSites;
    final index = controller.tabSiteIndex.value;
    if (index < 0 || index >= sites.length) return Sites.allSite;
    return sites[index].id;
  }
}
