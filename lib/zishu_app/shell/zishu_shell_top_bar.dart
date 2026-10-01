import 'dart:async';
import 'dart:io';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/utils/windows_multi_instance_launcher.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';
import 'package:pure_live/zishu_app/features/search/zishu_search_dialog.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_follow_avatars.dart';

/// hover 浮层关闭延迟:对齐 zishu 真源 `_AppShellState` 的
/// `_kHoverCloseDelay`(800)—— 离开触发区后留时间把鼠标移进浮层。
/// 壳层与播放页共用([ZishuShellFlyoutMachine] 同源引用)。
const Duration kZishuShellHoverCloseDelay = Duration(milliseconds: 800);

/// 平台 tab / 我的分类悬停到浮层弹出的延迟(300ms):扫过顶栏不弹,停留才弹
/// (对齐真源平台 tab 同款开门延迟)。
const Duration kZishuShellHoverOpenDelay = Duration(milliseconds: 300);

/// 顶栏平台入口渲染表:严格按 `savedPlatformIds` 顺序;未保存(隐藏)的站点
/// 一律不渲染。新平台在「平台顺序与可见」设置里默认关,勾选后才进顶栏。
/// 壳层与播放页共用(PopularController 未注册时回落空表)。
List<Site> visibleTopBarSites() {
  final saved = SettingsService.to.app.savedPlatformIds.v;
  if (!Get.isRegistered<PopularController>()) return const <Site>[];
  final all = Get.find<PopularController>().sites;
  final visible = <Site>[];
  for (final id in saved) {
    for (final site in all) {
      if (site.id == id) {
        visible.add(site);
        break;
      }
    }
  }
  return visible;
}

/// 44px 顶栏:surface 底,主导航图标组 | 平台 tab 居中 | 工具区(关注/搜索/设置/账号)。
///
/// 壳层([ZishuAppShell])与播放页([ZishuPlayView])共用一份;本组件只管
/// 视觉与触发,行为参数(当前菜单 index、当前平台 id、各回调)由调用方注入,
/// hover 浮层由调用方在自己的 Stack 里渲染(壳层见 [ZishuShellFlyoutMachine])。
class ZishuShellTopBar extends StatelessWidget {
  final int index;
  final List<Site> sites;
  final String? currentSiteId;

  /// 平台 tab 选中口径补充:site.id == currentSiteId 且本值为真才描边选中
  /// (壳层=仅热门页,分区/关注页不亮 tab;播放页=恒真,选中当前房间平台)。
  final bool platformTabsActive;
  final void Function(int) onSelectMenu;
  final void Function(String) onSelectSite;

  /// 「关注」钮 hover → 触发点中心 x(弹在播头像网格);移出交给延迟关门。
  final void Function(double centerX) onFollowHoverStart;
  final VoidCallback onFollowHoverEnd;

  /// 平台 tab hover → `(站点 id, 触发点中心 x)`,300ms 后弹分类浮层;
  /// 移出取消开门并交给延迟关门。
  final void Function(String siteId, double centerX) onPlatformHoverStart;
  final VoidCallback onPlatformHoverEnd;

  /// 「我的分类」入口:hover 300ms 开浮层、点击 toggle(均回传触发点中心 x,
  /// 对齐 zishu 真源 top_nav nav-my-category 的 onMyCategoryHover/Tap);
  /// 移出取消开门并交给延迟关门。
  final void Function(double centerX) onMyCategoryHoverStart;
  final void Function(double centerX) onMyCategoryTap;
  final VoidCallback onMyCategoryHoverEnd;

  /// 打开 zishu 设置弹窗(设置钮与账号菜单共用)。
  final VoidCallback onOpenSettings;

  const ZishuShellTopBar({
    super.key,
    required this.index,
    required this.sites,
    required this.currentSiteId,
    required this.platformTabsActive,
    required this.onSelectMenu,
    required this.onSelectSite,
    required this.onPlatformHoverStart,
    required this.onPlatformHoverEnd,
    required this.onFollowHoverStart,
    required this.onFollowHoverEnd,
    required this.onMyCategoryHoverStart,
    required this.onMyCategoryTap,
    required this.onMyCategoryHoverEnd,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: AppSpacing.topNavHeight,
      color: tokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          _TopNavBrand(
            index: index,
            onSelectMenu: onSelectMenu,
            onMyCategoryHoverStart: onMyCategoryHoverStart,
            onMyCategoryTap: onMyCategoryTap,
            onMyCategoryHoverEnd: onMyCategoryHoverEnd,
          ),
          const Spacer(),
          for (final site in sites)
            _PlatformTab(
              site: site,
              selected: site.id == currentSiteId && platformTabsActive,
              onTap: () => onSelectSite(site.id),
              onHoverStart: onPlatformHoverStart,
              onHoverEnd: onPlatformHoverEnd,
            ),
          const Spacer(),
          // 关注触发器:在播头像堆叠(无在播回落星形),悬停仍走既有
          // follow flyout 态机(openFollowFlyout / 延迟关门),点击进关注页。
          ZishuFollowAvatars(
            tooltip: i18n('favorites_title'),
            onTap: () => onSelectMenu(HomeMenu.favorites.index),
            onHoverStart: onFollowHoverStart,
            onHoverEnd: onFollowHoverEnd,
          ),
          _TopNavTool(
            tooltip: '${i18n('search_live')}  Ctrl+F',
            icon: Remix.search_line,
            onTap: () => showZishuSearchDialog(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          _TopNavTool(tooltip: i18n('settings_title'), icon: Remix.settings_5_line, onTap: onOpenSettings),
          _TopUserArea(onOpenSettings: onOpenSettings),
        ],
      ),
    );
  }
}

/// 品牌字 + 主导航图标组(首页/分区/我的分类);关注等工具入口在顶栏右侧。
/// 组成与顺序对齐 zishu 真源 top_nav.dart 的 nav-home / nav-category /
/// nav-my-category(真源图标 Icons.star_border_rounded);我的分类无对应
/// 菜单页签(对齐真源:hover 开 ZishuMyCategoryFlyout、点击 toggle 浮层),
/// 无持久选中态,图标恒为主组未选色 textSecondary。
class _TopNavBrand extends StatelessWidget {
  final int index;
  final void Function(int) onSelectMenu;

  /// 「我的分类」hover 浮层挂钩:进入回传触发点中心 x(300ms 后开门,
  /// 调用方态机持有延迟),点击回传中心 x 做 toggle,移出取消开门并交给
  /// 延迟关门。
  final void Function(double centerX) onMyCategoryHoverStart;
  final void Function(double centerX) onMyCategoryTap;
  final VoidCallback onMyCategoryHoverEnd;

  const _TopNavBrand({
    required this.index,
    required this.onSelectMenu,
    required this.onMyCategoryHoverStart,
    required this.onMyCategoryTap,
    required this.onMyCategoryHoverEnd,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: Text(
            'Pure Live',
            style: context.textTitle.copyWith(
              fontSize: AppFontSize.title,
              color: tokens.brandBright,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _TopNavIcon(
          key: const Key('nav-home'),
          icon: Remix.home_5_fill,
          tooltip: i18n('popular_title'),
          color: index == HomeMenu.popular.index ? tokens.textPrimary : tokens.textSecondary,
          onTap: () => onSelectMenu(HomeMenu.popular.index),
        ),
        _TopNavIcon(
          key: const Key('nav-category'),
          icon: Remix.apps_2_fill,
          tooltip: i18n('areas_title'),
          color: index == HomeMenu.areas.index ? tokens.textPrimary : tokens.textSecondary,
          onTap: () => onSelectMenu(HomeMenu.areas.index),
        ),
        Builder(
          builder: (hoverContext) {
            // 触发点中心 x:MouseRegion 与点击区共用同一个 RenderBox 快照
            // (与 _PlatformTab 同款处理,真源 _NavAction 同口径)。
            RenderBox? box;
            double centerX() {
              final target = box ??= hoverContext.findRenderObject() as RenderBox?;
              if (target == null) return 0;
              final dx = target.localToGlobal(Offset.zero).dx;
              return dx + target.size.width / 2;
            }

            return MouseRegion(
              onEnter: (_) => onMyCategoryHoverStart(centerX()),
              onExit: (_) => onMyCategoryHoverEnd(),
              child: _TopNavIcon(
                key: const Key('nav-my-category'),
                icon: Icons.star_border_rounded,
                tooltip: i18n('my_category_title'),
                color: tokens.textSecondary,
                onTap: () => onMyCategoryTap(centerX()),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TopNavIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _TopNavIcon({super.key, required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

/// 顶栏平台 tab:32×32 悬停 pill 内放平台图标;hover ≥300ms 弹分类浮层
/// (延迟由调用方态机持有,这里只回传触发点中心 x 与移出事件)。
class _PlatformTab extends StatelessWidget {
  final Site site;
  final bool selected;
  final VoidCallback onTap;

  /// hover 浮层挂钩:进入回传 `(站点 id, 触发点中心 x)`(全局坐标),
  /// 移出取消开门并交给调用方延迟关门。
  final void Function(String siteId, double centerX) onHoverStart;
  final VoidCallback onHoverEnd;

  const _PlatformTab({
    required this.site,
    required this.selected,
    required this.onTap,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Builder(
        builder: (hoverContext) {
          // 触发点中心 x:MouseRegion 与点击区共用同一个 RenderBox 快照
          // (真源 _NavAction 同款处理)。
          RenderBox? box;
          double centerX() {
            final target = box ??= hoverContext.findRenderObject() as RenderBox?;
            if (target == null) return 0;
            final dx = target.localToGlobal(Offset.zero).dx;
            return dx + target.size.width / 2;
          }

          return MouseRegion(
            onEnter: (_) => onHoverStart(site.id, centerX()),
            onExit: (_) => onHoverEnd(),
            child: InkResponse(
              onTap: onTap,
              radius: 18,
              hoverColor: tokens.surfaceRaised,
              focusColor: Theme.of(context).focusColor,
              child: Tooltip(
                message: site.name,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? tokens.surfaceRaised : Colors.transparent,
                    borderRadius: AppRadius.allMd,
                    border: Border.all(color: selected ? tokens.accent : Colors.transparent, width: 1),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: PlatformIcon(id: site.id, size: 22),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopNavTool extends StatelessWidget {
  const _TopNavTool({required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Theme.of(context).extension<ZishuTokens>()!.textSecondary),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      splashRadius: 18,
    );
  }
}

/// 顶栏右侧用户区:圆形头像钮 + PopupMenu。
///
/// 菜单在 zishu 原三项(历史/设置/关于)之外并入 pure_live 工具四项
/// (备份/工具箱/多窗/新窗口),对齐旧 UI 的 MenuButton + CommonAppBarActions
/// 能力面 —— 顶栏不另加图标避免拥挤,全部收进用户菜单。原
/// 原 `ZishuUserArea` 菜单固定为三项且不可扩展,故按其视觉(头像钮、菜单
/// 行高/图标/字级)在本壳内重建;工具项图标与文案沿用旧 UI 口径
/// (cloud_line/link/layout_grid_line/add_to_photos_outlined)。
///
/// 开关门控在 itemBuilder 内读取(菜单每次打开即时取值,对齐旧 UI):
/// 多窗受 `enableMultiView`,新窗口受 `Platform.isWindows && enableNewWindowPlay`,
/// 关闭的项不渲染。
class _TopUserArea extends StatelessWidget {
  const _TopUserArea({required this.onOpenSettings});

  /// 打开 zishu 设置弹窗(与顶栏设置钮同一入口,由调用方注入)。
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return PopupMenuButton<String>(
      key: const Key('zishu-nav-user'),
      tooltip: i18n('account'),
      offset: const Offset(0, 30),
      color: tokens.surface,
      onSelected: (action) {
        switch (action) {
          case 'history':
            Get.toNamed(RoutePath.kHistory);
          case 'settings':
            onOpenSettings();
          case 'about':
            Get.toNamed(RoutePath.kAbout);
          case 'backup':
            Get.toNamed(RoutePath.kBackup);
          case 'toolbox':
            Get.toNamed(RoutePath.kToolbox);
          case 'multiview':
            unawaited(AppNavigator.toMultiview());
          case 'new_window':
            unawaited(_launchNewWindow());
        }
      },
      itemBuilder: (menuContext) => [
        _item(menuContext, 'history', Icons.history_rounded, i18n('history')),
        _item(menuContext, 'settings', Remix.settings_5_line, i18n('settings_title')),
        _item(menuContext, 'about', Remix.information_line, i18n('about')),
        _item(menuContext, 'backup', Remix.cloud_line, i18n('backup_recover')),
        _item(menuContext, 'toolbox', Remix.link, i18n('open_link')),
        if (SettingsService.to.app.enableMultiView.v)
          _item(menuContext, 'multiview', Remix.layout_grid_line, i18n('multiview_title')),
        if (Platform.isWindows && SettingsService.to.app.enableNewWindowPlay.v)
          _item(menuContext, 'new_window', Icons.add_to_photos_outlined, i18n('open_new_window')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: tokens.accent,
          child: Icon(Icons.person_outline_rounded, size: 16, color: AppOnBright.white),
        ),
      ),
    );
  }

  /// 新窗口:launch 已自守 `Platform.isWindows`;失败时对齐旧 UI MenuButton
  /// 的 toast 提示。
  Future<void> _launchNewWindow() async {
    try {
      await WindowsMultiInstanceLauncher.launch();
    } catch (_) {
      ToastUtil.show(i18n('open_new_window_failed'));
    }
  }

  PopupMenuItem<String> _item(BuildContext context, String value, IconData icon, String label) {
    final tokens = context.tokens;
    return PopupMenuItem(
      value: value,
      height: 34,
      child: Row(
        children: [
          Icon(icon, size: 15, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: AppFontSize.bodySecondary, color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}
