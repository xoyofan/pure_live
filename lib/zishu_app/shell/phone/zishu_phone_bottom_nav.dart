import 'dart:async';

import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/search/zishu_search_dialog.dart';
import 'package:pure_live/zishu_app/features/settings/zishu_settings_view.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_follow_avatars.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_my_category_flyout.dart';

/// 窄屏(<768)底部主导航:移植 zishu_flutter `lib/src/app/shell/bottom_nav.dart`
/// 的 `_BottomNav`(56px、surfaceSoft 底、顶缘 1px 边框)。
///
/// 真源 8 项 = logo/首页/分类/我的分类/关注/搜索/主题/我的;pure_live 无
/// 「我的」登录项,按任务口径省略 → 7 项;`nav-settings` 以「设置弹窗」
/// 形态补回(对齐真源该项 onTap = openSettingsDialog 的弹窗口径,不再推页,
/// 与宽屏顶栏设置钮同源)。锚点名(nav-brand/nav-home/nav-category/
/// nav-my-category/nav-follow/nav-search/nav-theme/nav-settings)沿用真源。
/// 标签优先用既有 i18n key
/// (popular_title=热门 / areas_title=分区 / favorites_title=关注 /
/// search_live=搜索直播 / theme_mode_light|dark=浅色|深色模式 /
/// my_category_title=我的分类 / settings_title=设置)。「我的分类」点击弹
/// my_category flyout 同款底部面板(不再跳分区页)。
class ZishuPhoneBottomNav extends StatelessWidget {
  const ZishuPhoneBottomNav({super.key, required this.index, required this.onSelectMenu});

  /// 当前激活的 [HomeMenu] 索引(无激活项时为 -1)。
  final int index;

  /// 走外壳的页面切换(与宽屏外壳同一回调,最终落到 HomePage 的 setState)。
  final void Function(int) onSelectMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 测试锚点:移动底栏容器(真源契约,勿改)。
      key: const Key('bottom-nav'),
      height: AppSpacing.bottomNavHeight,
      decoration: BoxDecoration(
        color: context.tokens.surfaceSoft,
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      child: Row(
        children: [
          _BottomItem(
            key: const Key('nav-brand'),
            leading: SizedBox(
              width: 26,
              height: 26,
              // pure_live 无 zishu 的 assets/ui/logo/logo-128.png,
              // 用应用图标 assets/icons/icon.png(pubspec 已注册),加载失败
              // 回退真源同款「薯」字紫底圆。
              child: Image.asset(
                'assets/icons/icon.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.tokens.accent, shape: BoxShape.circle),
                  child: const Text(
                    '薯',
                    style: TextStyle(
                      color: AppOnBright.white,
                      fontSize: AppFontSize.subtitle,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            label: '',
            active: false,
            onTap: () => onSelectMenu(HomeMenu.popular.index),
          ),
          _BottomItem(
            key: const Key('nav-home'),
            leading: _bottomIcon(Icons.home_rounded, index == HomeMenu.popular.index, context.tokens),
            label: i18n('popular_title'),
            active: index == HomeMenu.popular.index,
            onTap: () => onSelectMenu(HomeMenu.popular.index),
          ),
          _BottomItem(
            key: const Key('nav-category'),
            leading: _bottomIcon(Icons.grid_view_rounded, false, context.tokens),
            label: i18n('areas_title'),
            // 真源口径:分类项不作选中态(它只是分类面板/分区页的入口)。
            active: false,
            onTap: () => onSelectMenu(HomeMenu.areas.index),
          ),
          _BottomItem(
            key: const Key('nav-my-category'),
            leading: _bottomIcon(Icons.category_outlined, false, context.tokens),
            label: i18n('my_category_title'),
            // 弹「我的分类」面板(flyout 同款内容:chips + 管理入口),
            // 不再跳分区页;图标/标签沿用真源 `_BottomMyCategoryItem`
            // (标签改用既有 i18n key my_category_title)。
            active: false,
            onTap: () => unawaited(showZishuMyCategorySheet(context)),
          ),
          _BottomItem(
            key: const Key('nav-follow'),
            // 真源 bottom_nav.dart:84-92:关注项 leading 是 20px 档在播头像
            // 堆叠(_NavFollowAvatars(size: bottomSize)),不是爱心图标;数据
            // 与壳层关注浮层同一份口径(favoriteRooms 在播过滤)。堆叠纯渲染,
            // 点击仍由本项 InkWell 进关注页(手机无 hover,不需要触发器壳)。
            leading: const ZishuFollowAvatarStack(size: ZishuFollowAvatars.bottomSize),
            label: i18n('favorites_title'),
            active: index == HomeMenu.favorites.index,
            onTap: () => onSelectMenu(HomeMenu.favorites.index),
          ),
          _BottomItem(
            key: const Key('nav-search'),
            leading: _bottomIcon(Icons.search_rounded, false, context.tokens),
            label: i18n('search_live'),
            // 与宽屏顶栏同源:搜索是全局弹框,不切页面。
            active: false,
            onTap: () => unawaited(showZishuSearchDialog(context)),
          ),
          const _BottomThemeItem(),
          _BottomItem(
            key: const Key('nav-settings'),
            leading: _bottomIcon(Icons.settings_outlined, false, context.tokens),
            label: i18n('settings_title'),
            // 对齐真源口径:设置是全局弹框(与宽屏顶栏设置钮同源),不切页面。
            active: false,
            onTap: () => unawaited(openZishuSettingsDialog(context)),
          ),
        ],
      ),
    );
  }
}

/// 底部导航图标(按选中态着色,真源同款)。
Widget _bottomIcon(IconData icon, bool active, ZishuTokens tokens) =>
    Icon(icon, size: 20, color: active ? tokens.accent : tokens.textSecondary);

/// 底栏单格(真源 `_BottomItem` 原样):Expanded + InkWell + 图标/文字纵排,
/// 8 项挤在 360px 宽下时靠 FittedBox scaleDown 收敛而不是溢出。
class _BottomItem extends StatelessWidget {
  const _BottomItem({super.key, required this.leading, required this.label, required this.active, this.onTap});

  final Widget leading;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.tokens.accent : context.tokens.textSecondary;
    return Expanded(
      child: InkWell(
        hoverColor: context.tokens.surface,
        focusColor: AppStateLayer.focusOf(context.tokens.accent),
        splashColor: AppStateLayer.splashOf(context.tokens.accent),
        highlightColor: AppStateLayer.pressedOf(context.tokens.accent),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(fontSize: AppFontSize.caption, color: color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 底栏「主题」项:移植 zishu_flutter `shell/theme_actions.dart` 的
/// `_BottomThemeItem` —— 文案表示「点击后要切到的目标」,当前生效深色时
/// 显示「浅色模式」、否则「深色模式」。数据层用 pure_live
/// `SettingsService.to.theme.themeModeName`("System"/"Dark"/"Light"),
/// system 档按平台亮度解析生效态(与 MaterialApp 的 themeMode 同口径)。
class _BottomThemeItem extends StatelessWidget {
  const _BottomThemeItem();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final modeName = SettingsService.to.theme.themeModeName.v;
      final isDark = switch (modeName) {
        'Dark' => true,
        'Light' => false,
        _ => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };
      return _BottomItem(
        key: const Key('nav-theme'),
        leading: _bottomIcon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, false, context.tokens),
        label: isDark ? i18n('theme_mode_light') : i18n('theme_mode_dark'),
        active: false,
        onTap: () => SettingsService.to.theme.changeThemeMode(isDark ? 'Light' : 'Dark'),
      );
    });
  }
}
