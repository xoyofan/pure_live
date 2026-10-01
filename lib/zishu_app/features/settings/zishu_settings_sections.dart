/// zishu 设置弹窗「全面扁平化」的各就地展开内容(2026-10 任务D)。
///
/// 原 13 个跳页行(`Get.to` 独立设置页)全部改为手风琴就地展开,本文件是
/// 各展开区的紧凑实现:**复用既有 controller 逻辑 + 重写紧凑 UI**,不把
/// 独立页面 widget 内嵌进手风琴(行样式见 `zishu_settings_rows.dart`)。
///
/// 仅有的例外是各页内部再下钻的「重管理页」(第三方授权 / 标签管理 / WebDAV /
/// 远程同步 / 弹幕屏蔽 / 字体管理 / IPTV 频道管理 / 账号页):这些页面自身是
/// 数百行的管理器,按任务D「保留更多设置类弹 dialog 的入口」口径改为
/// **对话框宿主**([ZishuPageHostDialog])弹出,内容原样保留;其路由 Binding
/// 均为单控制器 lazyPut,弹前用 `Get.lazyPut(fenix: true)` 复刻。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter_json/flutter_json.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/common/services/settings/backup_controller.dart';
import 'package:pure_live/common/services/settings/cache_controller.dart';
import 'package:pure_live/common/services/settings/danmaku_settings_controller.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/common/services/settings/log_controller.dart';
import 'package:pure_live/common/services/settings/player_settings_controller.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';
import 'package:pure_live/common/widgets/count_button.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/common/proxy_routing.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';
import 'package:pure_live/modules/auth/auth_controller.dart';
import 'package:pure_live/modules/auth/mine_page.dart';
import 'package:pure_live/modules/auth/sign_in_page.dart';
import 'package:pure_live/modules/iptv/iptv_manage.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_danmaku_style_editor.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';
import 'package:pure_live/modules/settings/pages/font_family_manager_page.dart';
import 'package:pure_live/modules/settings/widgets/app_color_picker_dialog.dart';
import 'package:pure_live/modules/remote_receiver/remote_sync_page.dart';
import 'package:pure_live/modules/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/modules/shield/danmu_shield_controller.dart';
import 'package:pure_live/modules/shield/danmu_shield_page.dart';
import 'package:pure_live/modules/web_dav/web_dav_controller.dart';
import 'package:pure_live/modules/web_dav/web_dav_page.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/models/player_engine.dart';
import 'package:pure_live/player/utils/mpv_option_labels.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/utils/windows_pip_driver.dart';
import 'package:pure_live/plugins/backup_recovery_service.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/compact_switch.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

import 'zishu_settings_rows.dart';

// ---------------------------------------------------------------------------
// 通用 / 导航与显示
// ---------------------------------------------------------------------------

/// 「导航与显示」紧凑版(原 NavigationSettingsPage):Windows 多视图开关 +
/// 菜单顺序与可见的紧凑横排 Wrap(图标 + 名称 + 可见迷你开关 + 拖拽把手)。
class ZishuNavigationSettingsContent extends StatelessWidget {
  const ZishuNavigationSettingsContent({super.key});

  static const _menuIcons = <HomeMenu, IconData>{
    HomeMenu.favorites: Icons.favorite_rounded,
    HomeMenu.popular: Icons.local_fire_department_rounded,
    HomeMenu.areas: Icons.apps_rounded,
    HomeMenu.record: Icons.video_library_rounded,
  };

  static const _menuLabelKeys = <HomeMenu, String>{
    HomeMenu.favorites: 'favorites_title',
    HomeMenu.popular: 'popular_title',
    HomeMenu.areas: 'areas_title',
    HomeMenu.record: 'record_center',
  };

  @override
  Widget build(BuildContext context) {
    final app = SettingsService.to.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (PlatformUtils.isWindows) ...[
          ZishuSwitchLine.rx(title: i18n('multiview_title'), rx: app.enableMultiView),
          ZishuSectionCaption(i18n('navigation_display_settings')),
        ],
        Obx(() {
          final savedOrder = AppSettingsController.normalizeMenuIds(app.savedMenuIds.v);
          final sortedMenus = List<HomeMenu>.from(HomeMenu.values);
          sortedMenus.sort((a, b) {
            final indexA = savedOrder.indexOf(a.id);
            final indexB = savedOrder.indexOf(b.id);
            if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
            if (indexA != -1) return -1;
            if (indexB != -1) return 1;
            return 0;
          });
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final menu in sortedMenus) _MenuSortChip(menu: menu, savedOrder: savedOrder)],
          );
        }),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.xs),
          child: Text(i18n('drag_menu_to_sort_tip'), style: context.textCaption),
        ),
      ],
    );
  }
}

/// 单个菜单条目(交互与平台条目同构):开关 = 是否可见,把手 = 拖拽排序。
class _MenuSortChip extends StatelessWidget {
  const _MenuSortChip({required this.menu, required this.savedOrder});

  final HomeMenu menu;
  final List<String> savedOrder;

  bool get _visible => savedOrder.contains(menu.id);

  bool get _canDrag => _visible && savedOrder.length > 1;

  void _toggleVisibility(bool value) {
    final savedMenus = AppSettingsController.normalizeMenuIds(SettingsService.to.app.savedMenuIds.v);
    if (!value && savedMenus.length <= 1) {
      ToastUtil.show(i18n('at_least_one_menu_required'));
      return;
    }
    SettingsService.to.app.toggleMenuVisibility(menu, value);
  }

  void _acceptDrop(String draggedId) {
    if (draggedId == menu.id) return;
    final app = SettingsService.to.app;
    final order = List<String>.from(AppSettingsController.normalizeMenuIds(app.savedMenuIds.v));
    if (!order.contains(draggedId) || !order.contains(menu.id)) return;
    order.remove(draggedId);
    order.insert(order.indexOf(menu.id), draggedId);
    app.savedMenuIds.v = order;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allSm,
        border: Border.all(
          color: _visible
              ? tokens.border
              : Color.alphaBlend(tokens.textSecondary.withValues(alpha: 0.18), tokens.surface),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ZishuNavigationSettingsContent._menuIcons[menu]!,
            size: 14,
            color: _visible ? tokens.textSecondary : tokens.border,
          ),
          const SizedBox(width: 4),
          Text(
            i18n(ZishuNavigationSettingsContent._menuLabelKeys[menu]!),
            maxLines: 1,
            style: context.textBody.copyWith(
              fontSize: AppFontSize.bodySecondary,
              fontWeight: FontWeight.w500,
              color: _visible ? tokens.textPrimary : tokens.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          CompactSwitch(value: _visible, onChanged: _toggleVisibility),
          if (_canDrag) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: i18n('drag_menu_to_sort_tip'),
              child: Icon(Icons.drag_indicator_rounded, size: 14, color: tokens.textSecondary),
            ),
          ],
        ],
      ),
    );
    return ZishuDragChip(data: menu.id, draggable: _canDrag, onAccepted: _acceptDrop, child: chip);
  }
}

// ---------------------------------------------------------------------------
// 刷新
// ---------------------------------------------------------------------------

/// 「刷新」紧凑版(原 RefreshSettingsPage):开关 + 间隔/并发改为紧凑下拉。
class ZishuRefreshSettingsContent extends StatelessWidget {
  const ZishuRefreshSettingsContent({super.key});

  static const _intervals = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360];
  static const _thumbnailIntervals = [5, 10, 15, 30, 60, 120, 240, 360];

  static String _intervalLabel(int minute) {
    if (minute < 60) return '$minute ${i18n('minute')}';
    if (minute == 60) return '1 ${i18n('hour')}';
    if (minute == 90) return '1.5 ${i18n('hour')}';
    return '${minute ~/ 60} ${i18n('hour')}';
  }

  @override
  Widget build(BuildContext context) {
    final refresh = SettingsService.to.refreshConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSwitchLine.rx(
          title: i18n('auto_refresh_follow'),
          desc: i18n('auto_refresh_follow_subtitle'),
          rx: refresh.autoRefreshFavorite,
        ),
        ZishuSwitchLine.rx(
          title: i18n('refresh_follow_on_resume'),
          desc: i18n('refresh_follow_on_resume_subtitle'),
          rx: refresh.refreshFavoriteOnResume,
        ),
        Obx(
          () => refresh.autoRefreshFavorite.v
              ? ZishuDropdownLine<int>(
                  title: i18n('auto_refresh_interval'),
                  values: _intervals,
                  labelOf: _intervalLabel,
                  readValue: () => refresh.autoRefreshInterval.v,
                  onChanged: (value) => refresh.autoRefreshInterval.v = value,
                )
              : const SizedBox(width: double.infinity),
        ),
        ZishuDropdownLine<int>(
          title: i18n('max_concurrent_refresh'),
          desc: i18n('max_concurrent_refresh_subtitle'),
          values: [for (var i = 1; i <= 20; i++) i],
          labelOf: (value) => value == RefreshConfigController.defaultMaxConcurrentRefresh
              ? '$value · ${i18n('recommended')}'
              : '$value',
          readValue: () => refresh.maxConcurrentRefresh.v,
          onChanged: (value) => refresh.maxConcurrentRefresh.v = value,
        ),
        ZishuSwitchLine.rx(
          title: i18n('auto_refresh_thumbnails'),
          desc: i18n('auto_refresh_thumbnails_subtitle'),
          rx: refresh.autoRefreshThumbnails,
        ),
        Obx(
          () => refresh.autoRefreshThumbnails.v
              ? ZishuDropdownLine<int>(
                  title: i18n('thumbnail_refresh_interval'),
                  values: _thumbnailIntervals,
                  labelOf: _intervalLabel,
                  readValue: () => refresh.thumbnailRefreshInterval.v,
                  onChanged: (value) => refresh.thumbnailRefreshInterval.v = value,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 视频(含竖屏/在线人数/画中画弹幕入口等)
// ---------------------------------------------------------------------------

/// 「视频」紧凑版(原 VideoSettingsPage):音频 / 画质 / 播放行为(竖屏、
/// 在线人数、悬浮窗)/ 弹幕五段,全部就地一行化。
class ZishuVideoSettingsContent extends StatelessWidget {
  const ZishuVideoSettingsContent({super.key});

  static String _resolutionLabel(String value) {
    final key = PlayerConsts.resolutionLabelKey(value);
    return key == null ? value : i18n(key);
  }

  /// 竖屏全屏显示模式文案(与 PortraitLiveSettingsPage 顶层的
  /// `portraitFullscreenDisplayModeLabel` 同口径;为不再 import 独立页面
  /// widget,在此就地转写)。
  static String _fullscreenDisplayLabel(PortraitFullscreenDisplayMode value) => switch (value) {
    PortraitFullscreenDisplayMode.complete => i18n('portrait_fullscreen_display_complete'),
    PortraitFullscreenDisplayMode.ambient => i18n('portrait_fullscreen_display_ambient'),
    PortraitFullscreenDisplayMode.balanced => i18n('portrait_fullscreen_display_balanced'),
    PortraitFullscreenDisplayMode.cover => i18n('portrait_fullscreen_display_cover'),
  };

  static Future<void> _refreshPresentation() async {
    GlobalPlayerService.instance.player.refreshPortraitPresentationPolicy();
  }

  static Future<void> _setPipAlwaysOnTop(bool enabled) async {
    final player = SettingsService.to.player;
    try {
      await setWindowsPipAlwaysOnTop(enabled);
      player.windowsPipAlwaysOnTop.v = enabled;
    } catch (_) {
      ToastUtil.show(i18n('windows_pip_always_on_top_apply_failed'));
    }
  }

  static Future<void> _confirmPipReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('windows_pip_reset_position')),
        content: Text(i18n('windows_pip_reset_position_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('reset'))),
        ],
      ),
    );
    if (confirmed != true) return;
    SettingsService.to.window.clearWindowsPipGeometry();
    ToastUtil.show(i18n('windows_pip_reset_position_success'));
  }

  @override
  Widget build(BuildContext context) {
    final app = SettingsService.to.app;
    final player = SettingsService.to.player;
    final danmaku = SettingsService.to.danmaku;
    final vol = SettingsService.to.vol;
    final window = SettingsService.to.window;
    final isWindows = PlatformUtils.isWindows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSectionCaption(i18n('audio_settings')),
        ZishuSwitchLine.rx(title: i18n('global_mute'), desc: i18n('global_mute_subtitle'), rx: vol.globalVolumeMute),
        ZishuSliderLine(
          title: i18n('desktop_default_volume'),
          min: 0,
          max: 1,
          readValue: () => vol.defaultDesktopVolume.v,
          onChanged: (value) => vol.defaultDesktopVolume.v = double.parse(value.toStringAsFixed(2)),
          displayOf: (value) => '${(value * 100).toStringAsFixed(0)}%',
        ),
        ZishuSectionCaption(i18n('video_quality_settings')),
        ZishuDropdownLine<String>(
          title: i18n('prefer_resolution'),
          desc: i18n('prefer_resolution_subtitle'),
          values: PlayerConsts.resolutions,
          labelOf: _resolutionLabel,
          readValue: () => player.resolvedPreferResolution,
          onChanged: player.changePreferResolution,
        ),
        ZishuDropdownLine<String>(
          title: i18n('mobile_quality'),
          desc: i18n('mobile_quality_subtitle'),
          values: PlayerConsts.resolutions,
          labelOf: _resolutionLabel,
          readValue: () => player.resolvedPreferResolutionCellular,
          onChanged: player.changePreferResolutionCellular,
        ),
        ZishuSectionCaption(i18n('playback_behavior_settings')),
        // 竖屏直播(原 PortraitLiveSettingsPage 内联,枚举选择改紧凑下拉)。
        _portraitSection(context),
        // 在线人数口径(原 AudienceMetricSettingsPage 内联)。
        _audienceSection(context),
        ZishuSwitchLine.rx(
          title: i18n('exit_float_window'),
          desc: i18n('exit_float_window_subtitle'),
          rx: player.floatPlay,
        ),
        if (isWindows)
          ZishuSwitchLine(
            title: i18n('windows_pip_always_on_top'),
            desc: i18n('windows_pip_always_on_top_subtitle'),
            read: () => player.windowsPipAlwaysOnTop.v,
            onChanged: _setPipAlwaysOnTop,
          ),
        if (isWindows)
          ZishuSwitchLine(
            title: i18n('windows_pip_remember_position'),
            desc: i18n('windows_pip_remember_position_subtitle'),
            read: () => window.rememberPipPosition.v,
            onChanged: (value) => window.rememberPipPosition.v = value,
          ),
        if (isWindows)
          ZishuSettingLine(
            title: i18n('windows_pip_reset_position'),
            desc: i18n('windows_pip_reset_position_subtitle'),
            onTap: () => unawaited(_confirmPipReset(context)),
          ),
        ZishuSwitchLine.rx(
          title: i18n('enable_fullscreen_default'),
          desc: i18n('enable_fullscreen_default_subtitle'),
          rx: app.enableFullScreenDefault,
        ),
        ZishuSectionCaption(i18n('danmaku_settings')),
        ZishuSwitchLine.rx(
          title: i18n('show_danmaku'),
          desc: i18n('show_danmaku_subtitle'),
          rx: danmaku.enableDanmakuDisplay,
        ),
        Obx(
          () => ZishuSettingLine(
            title: i18n('change_danmaku_font_family'),
            desc: '${i18n('current_font_prefix')}: ${danmaku.danmakuFontFamilyName.v}',
            trailing: zishuLineChevron(context),
            onTap: () => ZishuPageHostDialog.show(context, page: const FontFamilyManagerPage(isDanmakuSettings: true)),
          ),
        ),
        ZishuSettingLine(
          title: i18n('danmaku_filter'),
          trailing: zishuLineChevron(context),
          onTap: () => ZishuPageHostDialog.show(
            context,
            page: const DanmuShieldPage(),
            ensureBinding: _ensureDanmuShieldController,
          ),
        ),
      ],
    );
  }

  static void _ensureDanmuShieldController() {
    if (!Get.isRegistered<DanmuShieldController>()) Get.lazyPut(() => DanmuShieldController(), fenix: true);
  }

  /// 竖屏直播子段:开关 + 枚举紧凑下拉 + 重置。
  Widget _portraitSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSectionCaption(i18n('portrait_live_settings')),
        ZishuSwitchLine(
          title: i18n('portrait_smart_detection'),
          desc: i18n('portrait_smart_detection_desc'),
          read: () => SettingsService.to.player.enablePortraitStreamAdaptation.v,
          onChanged: (value) {
            SettingsService.to.player.enablePortraitStreamAdaptation.v = value;
            unawaited(_refreshPresentation());
          },
        ),
        ZishuSwitchLine.rx(
          title: i18n('portrait_adaptive_height'),
          desc: i18n('portrait_adaptive_height_desc'),
          rx: SettingsService.to.player.portraitAdaptiveHeight,
        ),
        ZishuDropdownLine<PortraitLayoutMode>(
          title: i18n('portrait_layout_mode'),
          desc: i18n('portrait_layout_mode_desc'),
          values: PortraitLayoutMode.values,
          labelOf: (value) => switch (value) {
            PortraitLayoutMode.balanced => i18n('portrait_layout_balanced'),
            PortraitLayoutMode.immersive => i18n('portrait_layout_immersive'),
            PortraitLayoutMode.compatibility => i18n('portrait_layout_compatibility'),
          },
          readValue: () => SettingsService.to.player.portraitLayoutMode,
          onChanged: (value) => SettingsService.to.player.portraitLayoutModeName.v = value.name,
        ),
        ZishuDropdownLine<PortraitFullscreenPolicy>(
          title: i18n('portrait_fullscreen_policy'),
          desc: i18n('portrait_fullscreen_policy_desc'),
          values: PortraitFullscreenPolicy.values,
          labelOf: (value) => switch (value) {
            PortraitFullscreenPolicy.followSource => i18n('portrait_fullscreen_follow_source'),
            PortraitFullscreenPolicy.followSystem => i18n('portrait_fullscreen_follow_system'),
            PortraitFullscreenPolicy.landscape => i18n('portrait_fullscreen_landscape'),
          },
          readValue: () => SettingsService.to.player.portraitFullscreenPolicy,
          onChanged: (value) {
            SettingsService.to.player.portraitFullscreenPolicyName.v = value.name;
            unawaited(_refreshPresentation());
          },
        ),
        ZishuDropdownLine<PortraitFullscreenDisplayMode>(
          title: i18n('portrait_fullscreen_display_mode'),
          desc: i18n('portrait_fullscreen_display_mode_desc'),
          values: PortraitFullscreenDisplayMode.values,
          labelOf: _fullscreenDisplayLabel,
          readValue: () => SettingsService.to.player.portraitFullscreenDisplayMode,
          onChanged: (value) => SettingsService.to.player.portraitFullscreenDisplayModeName.v = value.name,
        ),
        ZishuDropdownLine<PortraitDanmakuMode>(
          title: i18n('portrait_danmaku_mode'),
          desc: i18n('portrait_danmaku_mode_desc'),
          values: PortraitDanmakuMode.values,
          labelOf: (value) => switch (value) {
            PortraitDanmakuMode.followGlobal => i18n('portrait_danmaku_follow_global'),
            PortraitDanmakuMode.upperQuarter => i18n('portrait_danmaku_upper_quarter'),
            PortraitDanmakuMode.reduced => i18n('portrait_danmaku_reduced'),
            PortraitDanmakuMode.hidden => i18n('portrait_danmaku_hidden'),
          },
          readValue: () => SettingsService.to.player.portraitDanmakuMode,
          onChanged: (value) => SettingsService.to.player.portraitDanmakuModeName.v = value.name,
        ),
        ZishuSwitchLine.rx(
          title: i18n('portrait_remember_room_override'),
          desc: i18n('portrait_remember_room_override_desc'),
          rx: SettingsService.to.player.rememberPortraitRoomOverride,
        ),
        ZishuSwitchLine.rx(
          title: i18n('portrait_show_diagnostics'),
          desc: i18n('portrait_show_diagnostics_desc'),
          rx: SettingsService.to.player.showPortraitDiagnostics,
        ),
        ZishuSettingLine(
          title: i18n('portrait_reset_settings'),
          desc: i18n('portrait_reset_settings_desc'),
          onTap: () {
            SettingsService.to.player.resetPortraitStreamSettings();
            unawaited(_refreshPresentation());
            ToastUtil.show(i18n('settings_reset_done'));
          },
        ),
      ],
    );
  }

  /// 在线人数口径子段:模式两 chip + 平台开关紧凑横排。
  Widget _audienceSection(BuildContext context) {
    final app = SettingsService.to.app;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSectionCaption(i18n('audience_metric_settings')),
        Obx(
          () => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              ZishuOptionChip(
                label: i18n('audience_mode_heat'),
                selected: !app.preferRealOnlineCounts.v,
                onTap: () => app.preferRealOnlineCounts.v = false,
              ),
              ZishuOptionChip(
                label: i18n('audience_mode_online'),
                selected: app.preferRealOnlineCounts.v,
                onTap: () => app.preferRealOnlineCounts.v = true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.xs),
          child: Text(i18n('audience_ranking_rule_desc'), style: context.textCaption),
        ),
        for (final platform in _audiencePlatforms)
          _AudiencePlatformLine(id: platform.$1, labelKey: platform.$2, detailKey: platform.$3),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.xs),
          child: Text(i18n('audience_metric_fallback_desc'), style: context.textCaption),
        ),
      ],
    );
  }
}

/// 在线人数平台表(与 AudienceMetricSettingsPage 同源):(id, 名称 key, 说明 key)。
const List<(String, String, String)> _audiencePlatforms = [
  ('bilibili', 'site_bilibili', 'audience_bilibili_detail'),
  ('douyu', 'site_douyu', 'audience_douyu_detail'),
  ('huya', 'site_huya', 'audience_huya_detail'),
  ('douyin', 'site_douyin', 'audience_douyin_detail'),
  ('kuaishou', 'site_kuaishou', 'audience_kuaishou_detail'),
  ('cc', 'site_cc', 'audience_cc_detail'),
  ('twitch', 'site_twitch', 'audience_twitch_detail'),
  ('soop', 'site_soop', 'audience_soop_detail'),
  ('yy', 'site_yy', 'audience_yy_detail'),
  ('acfun', 'site_acfun', 'audience_acfun_detail'),
  ('picarto', 'site_picarto', 'audience_picarto_detail'),
  ('twitcasting', 'site_twitcasting', 'audience_twitcasting_detail'),
  ('missevan', 'site_missevan', 'audience_missevan_detail'),
  ('inke', 'site_inke', 'audience_inke_detail'),
  ('kilakila', 'site_kilakila', 'audience_kilakila_detail'),
  ('xiaohongshu', 'site_xiaohongshu', 'audience_xiaohongshu_detail'),
  ('niconico', 'site_niconico', 'audience_niconico_detail'),
  ('weibo', 'site_weibo', 'audience_weibo_detail'),
  ('looklive', 'site_looklive', 'audience_looklive_detail'),
];

/// 单平台在线人数行:不支持并发展示的平台只展示能力说明(不可开)。
class _AudiencePlatformLine extends StatelessWidget {
  const _AudiencePlatformLine({required this.id, required this.labelKey, required this.detailKey});

  final String id;
  final String labelKey;
  final String detailKey;

  @override
  Widget build(BuildContext context) {
    final app = SettingsService.to.app;
    final capability = LiveRoom.audienceCapabilityFor(id);
    if (!capability.supportsConcurrentOnline) {
      return ZishuSettingLine(title: i18n(labelKey), desc: i18n('audience_source_not_exposed'), enabled: false);
    }
    return ZishuSwitchLine(
      title: i18n(labelKey),
      desc: i18n(detailKey),
      read: () => app.isRealOnlineEnabledFor(id),
      onChanged: (value) => app.setRealOnlineEnabledFor(id, value),
    );
  }
}

// ---------------------------------------------------------------------------
// 画中画弹幕
// ---------------------------------------------------------------------------

/// 「画中画弹幕」紧凑版(原 PipDanmakuSettingsPage 的设置段):开关 + 颜色 +
/// 紧凑滑杆 + 计数按钮;预览画布与重置确认保留重置、略去预览(见交付说明)。
class ZishuPipDanmakuSettingsContent extends StatelessWidget {
  const ZishuPipDanmakuSettingsContent({super.key});

  static DanmakuSettingsController get _danmaku => SettingsService.to.danmaku;

  static Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('pip_danmaku_reset')),
        content: Text(i18n('pip_danmaku_reset_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('reset'))),
        ],
      ),
    );
    if (confirmed == true) _danmaku.resetPipDanmaku();
  }

  static Future<void> _showColorPicker(BuildContext context) async {
    final isZh = Get.locale?.languageCode == 'zh';
    await showAppColorPickerDialog(
      context: context,
      initialColor: Color(_danmaku.pipDanmakuColor.v),
      title: i18n('pip_danmaku_color'),
      enableOpacity: false,
      labels: buildAppColorPickerLabels(translate: (key) => i18n(key), isChinese: isZh, enableOpacity: false),
      customColorSwatchesAndNames: AppConsts.colorsNameMap,
      onColorChanged: (color) => _danmaku.pipDanmakuColor.v = color.toARGB32(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final danmaku = _danmaku;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSwitchLine.rx(title: i18n('pip_danmaku_enable'), rx: danmaku.enablePipDanmaku),
        Obx(
          () => !danmaku.enablePipDanmaku.v
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ZishuSwitchLine.rx(title: i18n('danmaku_no_emoji'), rx: danmaku.pipDanmakuNoEmojiMode),
                    ZishuSwitchLine.rx(title: i18n('pip_danmaku_auto_scale'), rx: danmaku.pipDanmakuAutoScale),
                    ZishuSwitchLine.rx(
                      title: i18n('pip_danmaku_original_color'),
                      rx: danmaku.pipDanmakuUseOriginalColor,
                    ),
                    if (!danmaku.pipDanmakuUseOriginalColor.v)
                      Obx(
                        () => ZishuSettingLine(
                          title: i18n('pip_danmaku_color'),
                          trailing: ColorIndicator(
                            width: 20,
                            height: 20,
                            borderRadius: 10,
                            color: Color(danmaku.pipDanmakuColor.v),
                          ),
                          onTap: () => unawaited(_showColorPicker(context)),
                        ),
                      ),
                    ZishuSliderLine(
                      title: i18n('font_size'),
                      min: 8,
                      max: 24,
                      readValue: () => danmaku.pipDanmakuFontSize.v,
                      onChanged: (value) => danmaku.pipDanmakuFontSize.v = value,
                      displayOf: (value) => value.toStringAsFixed(1),
                    ),
                    ZishuSliderLine(
                      title: i18n('font_weight'),
                      min: 100,
                      max: 900,
                      stepSize: 100,
                      readValue: () => danmaku.pipDanmakuFontWeight.value.toDouble(),
                      onChanged: (value) => danmaku.pipDanmakuFontWeight.value = value.round(),
                      displayOf: (value) => i18n(AppConsts.fontWeightLabels[value.round()] ?? 'font_weight_normal'),
                    ),
                    ZishuSliderLine(
                      title: i18n('speed'),
                      min: 20,
                      max: 400,
                      readValue: () => danmaku.pipDanmakuSpeed.v,
                      onChanged: (value) => danmaku.pipDanmakuSpeed.v = value,
                      displayOf: (value) => value.toStringAsFixed(0),
                    ),
                    ZishuSliderLine(
                      title: i18n('opacity'),
                      min: 0.1,
                      max: 1,
                      readValue: () => danmaku.pipDanmakuOpacity.v,
                      onChanged: (value) => danmaku.pipDanmakuOpacity.v = value,
                      displayOf: (value) => '${(value * 100).toInt()}%',
                    ),
                    ZishuSliderLine(
                      title: i18n('danmaku_area'),
                      min: 0.1,
                      max: 1,
                      readValue: () => danmaku.pipDanmakuArea.v,
                      onChanged: (value) => danmaku.pipDanmakuArea.v = value,
                      displayOf: (value) => '${(value * 100).toInt()}%',
                    ),
                    Obx(
                      () => ZishuSettingLine(
                        title: i18n('pip_danmaku_max_visible'),
                        trailing: CountButton(
                          minValue: 1,
                          maxValue: 20,
                          selectedValue: danmaku.pipDanmakuMaxVisibleCount.v,
                          onChanged: (value) => danmaku.pipDanmakuMaxVisibleCount.v = value,
                        ),
                      ),
                    ),
                    ZishuSliderLine(
                      title: i18n('pip_danmaku_interval'),
                      min: 0.05,
                      max: 2,
                      stepSize: 0.05,
                      readValue: () => danmaku.pipDanmakuEmitInterval.v,
                      onChanged: (value) => danmaku.pipDanmakuEmitInterval.v = value,
                      displayOf: (value) => '${value.toStringAsFixed(2)}s',
                    ),
                    ZishuSwitchLine(
                      title: '${i18n('danmaku_fps')} · ${i18n('dynamic_follow_display')}',
                      desc: i18n('pip_danmaku_fps_policy_desc'),
                      read: () => danmaku.pipDanmakuAutoFps.v,
                      onChanged: (value) => danmaku.pipDanmakuAutoFps.v = value,
                    ),
                    Obx(
                      () => danmaku.pipDanmakuAutoFps.v
                          ? Padding(
                              padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
                              child: Text(
                                '${danmaku.resolvedDanmakuFps(pip: true, refreshRateMode: SettingsService.to.app.refreshRateMode)} FPS',
                                style: context.textCaption,
                              ),
                            )
                          : ZishuSliderLine(
                              title: i18n('danmaku_fps'),
                              min: 15,
                              max: 240,
                              readValue: () => danmaku.pipDanmakuFps.v.toDouble(),
                              onChanged: (value) => danmaku.pipDanmakuFps.v = value.round(),
                              displayOf: (value) => '${value.toInt()} FPS',
                            ),
                    ),
                    ZishuSettingLine(title: i18n('pip_danmaku_reset'), onTap: () => unawaited(_confirmReset(context))),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 播放内核
// ---------------------------------------------------------------------------

/// 「播放内核」紧凑版(原 PlayerKernelSettingsPage):内核下拉(切引擎)+
/// 硬解 / 强杀开关 + mpv 高级项(输出/解码器改紧凑下拉);页内的播放器代理
/// 行不再重复(网络代理组已有同源设置)。
class ZishuPlayerKernelContent extends StatelessWidget {
  const ZishuPlayerKernelContent({super.key});

  static String _normalizedKey() =>
      normalizeVideoPlayerKeyForPlatform(SettingsService.to.player.videoPlayerKey.v, defaultTargetPlatform);

  static bool get _isMediaKit => PlayerConsts.engines[_normalizedKey()] == PlayerEngine.mediaKit;

  static void _switchEngine(String key) {
    SettingsService.to.player.videoPlayerKey.v = key;
    GlobalPlayerService.instance.player.switchEngine(PlayerConsts.engines[key]!, isManual: true);
  }

  static String _mpvLabel(MpvOptionKind kind, String key) =>
      mpvOptionLabel(kind, key, defaultTargetPlatform, zh: Get.locale?.languageCode == 'zh');

  static List<String> _mpvKeys(MpvOptionKind kind) => mpvOptionsForPlatform(
    kind,
    defaultTargetPlatform,
    zh: Get.locale?.languageCode == 'zh',
  ).map((o) => o.key).toList();

  /// mpv 单选项紧凑下拉(videoOutputDriver / audioOutputDriver / videoHardwareDecoder)。
  static Widget _mpvDropdown(MpvOptionKind kind, {required String title, required RxString value}) {
    return ZishuDropdownLine<String>(
      title: title,
      values: _mpvKeys(kind),
      labelOf: (key) => _mpvLabel(kind, key),
      readValue: () => normalizedMpvOption(kind, value.v, defaultTargetPlatform),
      onChanged: (key) => value.v = key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = SettingsService.to.player;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuDropdownLine<String>(
          title: i18n('kernel_switch'),
          desc: i18n('kernel_switch_subtitle'),
          values: availableVideoPlayerKeysForPlatform(defaultTargetPlatform),
          labelOf: (key) => i18n(PlayerConsts.names[key] ?? PlayerConsts.names[PlayerConsts.defaultKey]!),
          readValue: _normalizedKey,
          onChanged: _switchEngine,
        ),
        ZishuSwitchLine.rx(title: i18n('enable_codec'), desc: i18n('gpu_decode'), rx: player.enableCodec),
        if (PlatformUtils.isWindows)
          Obx(
            () => _isMediaKit
                ? ZishuSwitchLine.rx(
                    title: i18n('enable_rtx_vsr'),
                    desc: i18n('enable_rtx_vsr_subtitle'),
                    rx: player.enableRtxVsr,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ZishuSwitchLine.rx(
          title: i18n('force_destroy_player'),
          desc: i18n('force_destroy_player_subtitle'),
          rx: player.useHardStopOnExit,
        ),
        Obx(
          () => !_isMediaKit
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ZishuSectionCaption(i18n('mpv_advanced_settings')),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
                      child: Text(
                        i18n('mpv_warning_text'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textCaption,
                      ),
                    ),
                    ZishuSwitchLine.rx(title: i18n('custom_output_hwdec'), rx: player.customPlayerOutput),
                    _mpvDropdown(
                      MpvOptionKind.videoOutput,
                      title: i18n('video_output_driver'),
                      value: player.videoOutputDriver,
                    ),
                    _mpvDropdown(
                      MpvOptionKind.audioOutput,
                      title: i18n('audio_output_driver'),
                      value: player.audioOutputDriver,
                    ),
                    _mpvDropdown(
                      MpvOptionKind.hardwareDecoder,
                      title: i18n('hardware_decoder'),
                      value: player.videoHardwareDecoder,
                    ),
                    ZishuSettingLine(title: i18n('reset'), danger: true, onTap: () => player.resetMpvPlayerSettings()),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 网络代理
// ---------------------------------------------------------------------------

/// 代理地址输入净化(与原页同口径:normalizeProxyHost 实时归一)。
final TextInputFormatter _zishuProxyHostFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  final normalized = normalizeProxyHost(newValue.text);
  if (normalized == newValue.text) return newValue;
  return TextEditingValue(
    text: normalized,
    selection: TextSelection.collapsed(offset: normalized.length),
    composing: TextRange.empty,
  );
});

/// 「网络代理」紧凑版(原 NetworkProxySettingsPage):两组「开关 + 地址/端口」,
/// 字段一行横排(地址占 3 份、端口占 2 份)。
class ZishuNetworkProxyContent extends StatefulWidget {
  const ZishuNetworkProxyContent({super.key});

  @override
  State<ZishuNetworkProxyContent> createState() => _ZishuNetworkProxyContentState();
}

class _ZishuNetworkProxyContentState extends State<ZishuNetworkProxyContent> {
  final _proxy = SettingsService.to.proxy;

  late final TextEditingController _appHostController;
  late final TextEditingController _appPortController;
  late final TextEditingController _playerHostController;
  late final TextEditingController _playerPortController;
  bool _appPortInvalid = false;
  bool _playerPortInvalid = false;

  @override
  void initState() {
    super.initState();
    _appHostController = TextEditingController(text: _proxy.appProxyHost.v);
    _appPortController = TextEditingController(text: _proxy.appProxyPort.v.toString());
    _playerHostController = TextEditingController(text: _proxy.proxyHost.v);
    _playerPortController = TextEditingController(text: _proxy.proxyPort.v.toString());
    _appPortInvalid = parseProxyPortInput(_appPortController.text) == null;
    _playerPortInvalid = parseProxyPortInput(_playerPortController.text) == null;
  }

  @override
  void dispose() {
    _appHostController.dispose();
    _appPortController.dispose();
    _playerHostController.dispose();
    _playerPortController.dispose();
    super.dispose();
  }

  void _updatePort(String rawValue, {required bool isAppProxy}) {
    final port = parseProxyPortInput(rawValue);
    final invalid = port == null;
    if (isAppProxy) {
      if (_appPortInvalid != invalid) setState(() => _appPortInvalid = invalid);
      if (port != null) _proxy.appProxyPort.v = port;
      return;
    }
    if (_playerPortInvalid != invalid) setState(() => _playerPortInvalid = invalid);
    if (port != null) _proxy.proxyPort.v = port;
  }

  Widget _endpointFields(
    TextEditingController hostController,
    TextEditingController portController, {
    required bool isAppProxy,
    required bool portInvalid,
    required String portHint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: hostController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [_zishuProxyHostFormatter],
              decoration: zishuDenseInput(context, i18n('proxy_address_label'), hint: '127.0.0.1'),
              onChanged: (value) {
                if (isAppProxy) {
                  _proxy.appProxyHost.v = normalizeProxyHost(value);
                } else {
                  _proxy.proxyHost.v = normalizeProxyHost(value);
                }
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: zishuDenseInput(
                context,
                i18n('proxy_port_label'),
                hint: portHint,
                errorText: portInvalid ? i18n('proxy_port_invalid') : null,
              ),
              onChanged: (value) => _updatePort(value, isAppProxy: isAppProxy),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSectionCaption(i18n('app_proxy_group_title')),
        ZishuSwitchLine.rx(
          title: i18n('enable_app_proxy'),
          desc: i18n('enable_app_proxy_desc'),
          rx: _proxy.enableAppProxy,
        ),
        Obx(
          () => _proxy.enableAppProxy.v
              ? _endpointFields(
                  _appHostController,
                  _appPortController,
                  isAppProxy: true,
                  portInvalid: _appPortInvalid,
                  portHint: '7890',
                )
              : const SizedBox(width: double.infinity),
        ),
        ZishuSectionCaption(i18n('player_proxy_group_title')),
        ZishuSwitchLine.rx(
          title: i18n('enable_player_proxy'),
          desc: i18n('enable_player_proxy_desc'),
          rx: _proxy.enableProxy,
        ),
        Obx(
          () => _proxy.enableProxy.v
              ? _endpointFields(
                  _playerHostController,
                  _playerPortController,
                  isAppProxy: false,
                  portInvalid: _playerPortInvalid,
                  portHint: '1080',
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 本地互动
// ---------------------------------------------------------------------------

/// 「本地互动」紧凑版(原 LocalInteractionSettingsPage):开关 + 昵称/称号/
/// 平台包 chips + 徽章与礼物开关 + 经历经济 + 弹幕样式编辑器(原 widget 复用)。
class ZishuLocalInteractionContent extends StatefulWidget {
  const ZishuLocalInteractionContent({super.key});

  @override
  State<ZishuLocalInteractionContent> createState() => _ZishuLocalInteractionContentState();
}

class _ZishuLocalInteractionContentState extends State<ZishuLocalInteractionContent> {
  late final LocalInteractionController _controller;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<LocalInteractionController>();
    _nameController = TextEditingController(text: _controller.userName.v);
  }

  @override
  void dispose() {
    // 与原页同口径:离开设置时把未提交的昵称草稿落库。
    _controller.updateName(_nameController.text);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSwitchLine.rx(
          title: i18n('local_interaction_enable'),
          desc: i18n('local_interaction_enable_desc'),
          rx: _controller.enabled,
        ),
        Obx(
          () => !_controller.enabled.v
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ZishuSectionCaption(i18n('local_user_profile')),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
                      child: TextField(
                        controller: _nameController,
                        maxLength: 20,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _controller.updateName,
                        decoration: zishuDenseInput(context, i18n('local_user_name'), counterText: ''),
                      ),
                    ),
                    ZishuSectionCaption(i18n('local_title_select')),
                    Obx(
                      () => Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final title in LocalInteractionController.titles)
                            ZishuOptionChip(
                              label: i18n('local_title_$title'),
                              selected: _controller.selectedTitle.v == title,
                              onTap: () => _controller.selectedTitle.v = title,
                            ),
                        ],
                      ),
                    ),
                    ZishuSwitchLine.rx(
                      title: i18n('local_overlay_message'),
                      desc: i18n('local_overlay_message_desc'),
                      rx: _controller.showAsDanmaku,
                    ),
                    ZishuSwitchLine.rx(
                      title: i18n('local_show_platform_badge'),
                      desc: i18n('local_show_platform_badge_desc'),
                      rx: _controller.showPlatformBadge,
                    ),
                    ZishuSwitchLine.rx(
                      title: i18n('local_show_level_badge'),
                      desc: i18n('local_show_level_badge_desc'),
                      rx: _controller.showLevelBadge,
                    ),
                    ZishuSwitchLine.rx(
                      title: i18n('local_gift_effects'),
                      desc: i18n('local_gift_effects_desc'),
                      rx: _controller.enableGiftEffects,
                    ),
                    Obx(
                      () => ZishuSettingLine(
                        title: i18n('local_interaction_status'),
                        desc: '${_controller.coins.v} · Lv.${_controller.level}',
                      ),
                    ),
                    ZishuSectionCaption(i18n('local_experience_economy')),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
                      child: Text(i18n('local_experience_economy_desc'), style: context.textCaption),
                    ),
                    Obx(
                      () => Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final value in const [500, 2000, 10000])
                            ZishuOptionChip(
                              label: '+$value',
                              selected: false,
                              onTap: () => _controller.recharge(value),
                            ),
                          if (_controller.history.isNotEmpty)
                            ZishuOptionChip(
                              label: i18n('local_clear_history'),
                              selected: false,
                              onTap: _controller.clearHistory,
                            ),
                        ],
                      ),
                    ),
                    ZishuSectionCaption(i18n('local_platform_pack')),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
                      child: Text(i18n('local_platform_pack_desc'), style: context.textCaption),
                    ),
                    Obx(
                      () => Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final pack in LocalInteractionController.platformPacks)
                            ZishuOptionChip(
                              label: '${pack.badge} ${pack.name}',
                              selected: _controller.previewPlatform.v == pack.id,
                              onTap: () => _controller.previewPlatform.v = pack.id,
                            ),
                        ],
                      ),
                    ),
                    ZishuSectionCaption(i18n('local_danmaku_style')),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
                      child: LocalDanmakuStyleEditor(controller: _controller),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
                      child: Text(i18n('local_interaction_room_entry_desc'), style: context.textCaption),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 缓存与数据
// ---------------------------------------------------------------------------

/// 「缓存与数据」紧凑版(原 CacheDataSettingsPage):容量/缩略图/清除/下载目录。
class ZishuCacheDataContent extends StatefulWidget {
  const ZishuCacheDataContent({super.key});

  @override
  State<ZishuCacheDataContent> createState() => _ZishuCacheDataContentState();
}

class _ZishuCacheDataContentState extends State<ZishuCacheDataContent> {
  bool _clearBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshSize(showFailure: false));
  }

  void _showMessage(String message, {bool failed = false}) {
    if (!mounted) return;
    Get.snackbar(failed ? i18n('error') : i18n('done'), message, snackPosition: SnackPosition.bottom);
  }

  Future<void> _refreshSize({bool showFailure = true}) async {
    try {
      if (showFailure) {
        await SettingsService.to.cache.handleManualRefresh();
      } else {
        await SettingsService.to.cache.getCacheSize();
      }
    } catch (_) {
      if (showFailure) _showMessage(i18n('cache_operation_failed'), failed: true);
    }
  }

  Future<void> _refreshThumbnails() async {
    try {
      await SettingsService.to.cache.refreshImageCache();
      _showMessage(i18n('thumbnails_refreshed'));
    } catch (_) {
      _showMessage(i18n('cache_operation_failed'), failed: true);
    }
  }

  Future<void> _confirmClearCache() async {
    if (_clearBusy || !mounted) return;
    setState(() => _clearBusy = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(i18n('confirm_clear_local_cache')),
          content: Text(i18n('confirm_clear_local_cache_desc')),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('cancel'))),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('clear'))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      try {
        final result = await SettingsService.to.cache.clearCache();
        if (result.succeeded) {
          _showMessage(i18n('cache_cleared'));
        } else {
          _showMessage(
            i18n('cache_clear_incomplete', args: {'size': result.remainingSizeMB.toStringAsFixed(2)}),
            failed: true,
          );
        }
      } catch (_) {
        _showMessage(i18n('cache_operation_failed'), failed: true);
      }
    } finally {
      if (mounted) setState(() => _clearBusy = false);
    }
  }

  /// 下载目录选取与可用性校验(与原页同口径)。
  Future<void> _pickDownloadDirectory() async {
    try {
      final selected = await FileUtils.pickDirectory();
      if (selected == null || selected.trim().isEmpty) return;
      await SettingsService.to.cache.setDownloadDirectory(selected);
      if (!await CacheController.isCustomDownloadDirectoryUsable()) {
        await FileUtils.requestStoragePermission();
      }
      if (!await CacheController.isCustomDownloadDirectoryUsable()) {
        _showMessage(i18n('download_directory_permission_hint'), failed: true);
        if (Platform.isAndroid) await openAppSettings();
        return;
      }
      _showMessage(i18n('download_directory_updated'));
    } catch (_) {
      _showMessage(i18n('download_directory_pick_failed'), failed: true);
    }
  }

  Future<void> _resetDownloadDirectory() async {
    try {
      await SettingsService.to.cache.useDefaultDownloadDirectory();
      _showMessage(i18n('download_directory_updated'));
    } catch (_) {
      _showMessage(i18n('download_directory_pick_failed'), failed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = SettingsService.to.cache;
    final tokens = context.tokens;
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZishuSettingLine(
            title: i18n('current_cache_size'),
            desc: '${cache.cacheSizeMB.value.toStringAsFixed(2)} MB',
            trailing: cache.isScanning.value
                ? zishuMiniSpinner(context)
                : IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    iconSize: 16,
                    color: tokens.textSecondary,
                    tooltip: i18n('refresh'),
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: cache.isBusy ? null : () => unawaited(_refreshSize()),
                  ),
            onTap: cache.isBusy ? null : () => unawaited(_refreshSize()),
          ),
          ZishuSettingLine(
            title: i18n('refresh_thumbnails'),
            desc: i18n('refresh_thumbnails_desc'),
            enabled: !cache.isBusy,
            trailing: cache.isRefreshingImages.value ? zishuMiniSpinner(context) : null,
            onTap: cache.isBusy ? null : () => unawaited(_refreshThumbnails()),
          ),
          ZishuSettingLine(
            title: i18n('clear_local_cache'),
            desc: i18n('clear_local_cache_desc'),
            danger: true,
            enabled: !cache.isBusy && !_clearBusy,
            trailing: cache.isClearing.value || _clearBusy ? zishuMiniSpinner(context, color: tokens.error) : null,
            onTap: cache.isBusy || _clearBusy ? null : () => unawaited(_confirmClearCache()),
          ),
          ZishuSettingLine(
            title: i18n('download_directory'),
            desc: cache.downloadDirectory.v.trim().isEmpty
                ? i18n('download_directory_default_label')
                : cache.downloadDirectory.v,
            onTap: () => unawaited(_pickDownloadDirectory()),
          ),
          if (cache.downloadDirectory.v.trim().isNotEmpty)
            ZishuSettingLine(
              title: i18n('download_directory_reset'),
              onTap: () => unawaited(_resetDownloadDirectory()),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 配置预览
// ---------------------------------------------------------------------------

/// 「配置预览」紧凑版(原 LocalConfigPreviewPage):摘要统计一行化 +
/// 原始 JSON 折叠树(限高,内部滚动)。
class ZishuConfigPreviewContent extends StatefulWidget {
  const ZishuConfigPreviewContent({super.key});

  @override
  State<ZishuConfigPreviewContent> createState() => _ZishuConfigPreviewContentState();
}

class _ZishuConfigPreviewContentState extends State<ZishuConfigPreviewContent> {
  Map<String, dynamic> _configData = {};
  bool _isLoading = true;
  String _errorMsg = '';
  int _favoriteCount = 0;
  int _historyCount = 0;
  int _tagCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalConfig();
  }

  void _loadLocalConfig() {
    try {
      final data = BackupController.to.exportAllSettings();
      final favoriteData = data['favorite'] as Map<String, dynamic>? ?? {};
      final favoriteRooms = favoriteData['favoriteRooms'] as List? ?? [];
      final historyData = data['history'] as Map<String, dynamic>? ?? {};
      final historyList = historyData['historyRooms'] ?? historyData['historyList'] ?? [];
      final tagData = data['tags'] as Map<String, dynamic>? ?? {};
      final tagList = tagData['tags'] as List? ?? [];

      _favoriteCount = favoriteRooms.length;
      _historyCount = historyList is List ? historyList.length : 0;
      _tagCount = tagList.length;
      _configData = json.decode(json.encode(data)) as Map<String, dynamic>;
    } catch (error) {
      _errorMsg = error.toString();
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: zishuMiniSpinner(context)),
      );
    }
    if (_errorMsg.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Text(_errorMsg, style: context.textCaption.copyWith(color: tokens.error)),
      );
    }
    final backupVersion = _configData['backupVersion'] ?? 0;
    final moduleCount = BackupController.countConfigSections(_configData);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
          child: Text(
            '${i18n('local_backup_config')} · backup v$backupVersion · ${i18n('config_modules')} $moduleCount',
            style: context.textCaption,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _PreviewStat(label: i18n('favorites'), value: '$_favoriteCount'),
              _PreviewStat(label: i18n('history'), value: '$_historyCount'),
              _PreviewStat(label: i18n('tags'), value: '$_tagCount'),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 280),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: tokens.surfaceSoft,
            borderRadius: AppRadius.allSm,
            border: Border.all(color: tokens.border),
          ),
          child: SingleChildScrollView(child: JsonWidget(json: _configData, initialExpandDepth: 2)),
        ),
      ],
    );
  }
}

/// 配置预览的统计小胶囊:数值 w700 + 标签 caption。
class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: context.textBody.copyWith(fontSize: AppFontSize.bodySecondary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Text(label, style: context.textCaption),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 备份
// ---------------------------------------------------------------------------

/// 「备份」紧凑版(原 BackupPage):云备份三个入口改为对话框宿主 +
/// 本地备份四动作 + 备份目录 + 日志段,行为与原页逐一同源。
class ZishuBackupContent extends StatefulWidget {
  const ZishuBackupContent({super.key});

  @override
  State<ZishuBackupContent> createState() => _ZishuBackupContentState();
}

enum _BackupAction { create, createFavorites, restore, restoreFavorites, directory }

class _ZishuBackupContentState extends State<ZishuBackupContent> {
  final LogController _logController = LogController.to;
  _BackupAction? _busyAction;

  String get _backupDirectory => SettingsService.to.backup.backupDirectory.v;

  Future<void> _runAction(_BackupAction action, String failureMessageKey, Future<void> Function() operation) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    try {
      await operation();
    } catch (_) {
      if (mounted) ToastUtil.show(i18n(failureMessageKey));
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  Widget? _busyIndicator(_BackupAction action, BuildContext context) {
    if (_busyAction != action) return null;
    return zishuMiniSpinner(context);
  }

  Future<void> _openLogDirectory() async {
    try {
      final logDir = await LogFileWriter.resolveLogDirectory();
      if (!await logDir.exists()) {
        ToastUtil.show(i18n('log_dir_not_exist'));
        return;
      }
      if (!await FileUtils.openFileOrUrl(logDir.path)) {
        ToastUtil.show(i18n('open_log_dir_failed'));
      }
    } catch (_) {
      ToastUtil.show(i18n('open_log_dir_failed'));
    }
  }

  Future<void> _openLogBrowser(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) ToastUtil.show(i18n('open_log_browser_failed'));
    } catch (_) {
      if (mounted) ToastUtil.show(i18n('open_log_browser_failed'));
    }
  }

  static void _ensureWebDavController() {
    if (!Get.isRegistered<WebDavPageController>()) Get.lazyPut(() => WebDavPageController(), fenix: true);
  }

  static void _ensureRemoteSyncService() {
    if (!Get.isRegistered<RemoteSyncService>()) Get.lazyPut(RemoteSyncService.new, fenix: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSectionCaption(i18n('cloud_backup')),
        // 账号行:连接中/未初始化/未登录/已登录四态文案与原页一致。
        Obx(
          () => ZishuSettingLine(
            title: auth.isConnecting
                ? i18n('firebase_connecting_title')
                : (auth.isInitSuccess
                      ? (auth.isLogin ? i18n('firebase_mine') : i18n('firebase_sign_in'))
                      : i18n('firebase_init_failed')),
            desc: auth.isConnecting
                ? i18n('firebase_connecting_desc')
                : (auth.isInitSuccess
                      ? (auth.isLogin ? i18n('firebase_logged_in_desc') : i18n('firebase_login_desc'))
                      : i18n('firebase_init_failed_desc')),
            enabled: !auth.isConnecting,
            trailing: auth.isConnecting ? zishuMiniSpinner(context) : null,
            onTap: () {
              if (!auth.isInitSuccess) {
                if (!auth.isConnecting) auth.startAsyncInit();
                return;
              }
              unawaited(ZishuPageHostDialog.show(context, page: auth.isLogin ? const MinePage() : const SignInPage()));
            },
          ),
        ),
        ZishuSettingLine(
          title: i18n('webdav'),
          desc: i18n('backup_to_webdav'),
          trailing: zishuLineChevron(context),
          onTap: () =>
              ZishuPageHostDialog.show(context, page: const WebDavPage(), ensureBinding: _ensureWebDavController),
        ),
        ZishuSettingLine(
          title: i18n('remote_sync'),
          desc: i18n('remote_sync_subtitle'),
          trailing: zishuLineChevron(context),
          onTap: () =>
              ZishuPageHostDialog.show(context, page: const RemoteSyncPage(), ensureBinding: _ensureRemoteSyncService),
        ),
        ZishuSectionCaption(i18n('local_backup')),
        ZishuSettingLine(
          title: i18n('create_backup'),
          desc: i18n('create_backup_subtitle'),
          trailing: _busyIndicator(_BackupAction.create, context),
          onTap: _busyAction == null
              ? () => unawaited(
                  _runAction(_BackupAction.create, 'create_backup_failed', () async {
                    await BackupRecoveryService().createAppSettingsBackup(_backupDirectory);
                  }),
                )
              : null,
        ),
        ZishuSettingLine(
          title: i18n('recover_backup'),
          desc: i18n('recover_backup_subtitle'),
          trailing: _busyIndicator(_BackupAction.restore, context),
          onTap: _busyAction == null
              ? () => unawaited(
                  _runAction(
                    _BackupAction.restore,
                    'recover_backup_failed',
                    BackupRecoveryService().recoverSettingsFromFile,
                  ),
                )
              : null,
        ),
        ZishuSettingLine(
          title: i18n('create_favorite_backup'),
          desc: i18n('favorite_backup_scope_hint'),
          trailing: _busyIndicator(_BackupAction.createFavorites, context),
          onTap: _busyAction == null
              ? () => unawaited(
                  _runAction(_BackupAction.createFavorites, 'create_favorite_backup_failed', () async {
                    await BackupRecoveryService().createFavoriteBackup(_backupDirectory);
                  }),
                )
              : null,
        ),
        ZishuSettingLine(
          title: i18n('recover_favorite_backup'),
          desc: i18n('favorite_backup_scope_hint'),
          trailing: _busyIndicator(_BackupAction.restoreFavorites, context),
          onTap: _busyAction == null
              ? () => unawaited(
                  _runAction(
                    _BackupAction.restoreFavorites,
                    'recover_favorite_backup_failed',
                    BackupRecoveryService().recoverFavoriteSettingsFromFile,
                  ),
                )
              : null,
        ),
        ZishuSettingLine(
          title: i18n('backup_directory'),
          desc: _backupDirectory.isEmpty ? i18n('please_set_backup_directory') : _backupDirectory,
          trailing: _busyIndicator(_BackupAction.directory, context),
          onTap: _busyAction == null
              ? () => unawaited(
                  _runAction(_BackupAction.directory, 'backup_directory_update_failed', () async {
                    await BackupRecoveryService().updateBackupDirectory();
                  }),
                )
              : null,
        ),
        ZishuSectionCaption(i18n('log_manage')),
        Obx(() {
          final applying = _logController.isApplyingLogStatus.v;
          final statusKey = _logController.logStatusKey.v;
          final subtitleKey = applying
              ? 'local_log_applying'
              : statusKey.isNotEmpty
              ? statusKey
              : 'enable_local_log_desc';
          return ZishuSwitchLine(
            title: i18n('enable_local_log'),
            desc: i18n(subtitleKey),
            read: () => _logController.storedEnableLog.v,
            onChanged: applying ? null : (value) => unawaited(_logController.setLoggingEnabled(value)),
          );
        }),
        Obx(() {
          if (!_logController.enableLog ||
              _logController.isApplyingLogStatus.v ||
              _logController.serverPort.value == 0) {
            return const SizedBox(width: double.infinity);
          }
          final uri = Uri(
            scheme: 'http',
            host: _logController.serverAddress.value,
            port: _logController.serverPort.value,
          );
          return ZishuSettingLine(
            title: i18n('view_logs_in_browser'),
            desc: uri.toString(),
            onTap: () => unawaited(_openLogBrowser(uri)),
          );
        }),
        ZishuSettingLine(
          title: i18n('open_log_dir'),
          desc: i18n('open_log_dir_desc'),
          onTap: () => unawaited(_openLogDirectory()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// IPTV
// ---------------------------------------------------------------------------

/// 「IPTV」紧凑版(原 IptvPage):自动同步开关 + 间隔下拉 + UA/网络导入/
/// EPG 源选择等弹窗保留(原页本就是 dialog 交互),频道列表管理以对话框宿主
/// 弹出;入口默认 EPG 资源引导(AutoSyncScheduler)不内联,见交付说明。
class ZishuIptvContent extends StatefulWidget {
  const ZishuIptvContent({super.key});

  @override
  State<ZishuIptvContent> createState() => _ZishuIptvContentState();
}

class _ZishuIptvContentState extends State<ZishuIptvContent> {
  bool _importing = false;

  IptvSettingsController get _iptv => SettingsService.to.iptv;

  void _showMessage(String message) {
    if (!mounted) return;
    ToastUtil.show(message);
  }

  // ---- 自定义 UA(原 _UserAgentDialog 紧凑版)----

  Future<void> _showUaDialog() async {
    final controller = TextEditingController(text: _iptv.customIptvUserAgent.v);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('edit_ua_title')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(i18n('custom_ua_desc'), style: Theme.of(dialogContext).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                maxLines: 5,
                maxLength: 500,
                autofocus: true,
                decoration: zishuDenseInput(dialogContext, i18n('custom_ua_title'), hint: 'Mozilla/5.0...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel'))),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(i18n('confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    _iptv.customIptvUserAgent.v = value;
    _showMessage(i18n('settings_saved'));
  }

  // ---- 播放列表 / EPG 导入(原导入弹窗紧凑版)----

  Future<void> _showImportDialog({required bool isEpg}) async {
    if (_importing) {
      _showMessage(i18n('iptv_import_in_progress'));
      return;
    }
    final fromNetwork = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n(isEpg ? 'dialog_import_epg_title' : 'dialog_import_playlist_title')),
        content: Text(i18n(isEpg ? 'epg_file_type' : 'playlist_file_type')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel'))),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(i18n('local_import'))),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(i18n('network_import'))),
        ],
      ),
    );
    if (fromNetwork == null) return;
    if (fromNetwork) {
      await _showNetworkImportDialog(isEpg: isEpg);
    } else {
      await _importLocal(isEpg: isEpg);
    }
  }

  Future<void> _importLocal({required bool isEpg}) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final success = isEpg
          ? await EpgImportManager().importFromLocalPicker()
          : await IptvImportManager().importFromLocalPicker();
      if (!success) return;
    } catch (_) {
      _showMessage(i18n(isEpg ? 'epg_import_failed' : 'local_import_failed'));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 网络导入(原 _NetworkImportDialog 紧凑版:URL + 名称 + 校验 + 提交态)。
  Future<void> _showNetworkImportDialog({required bool isEpg}) async {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _NetworkImportDialogBody(
        isEpg: isEpg,
        urlController: urlController,
        nameController: nameController,
        submit: (url, name) async {
          final success = isEpg
              ? await EpgImportManager().importFromNetworkUrl(url, name)
              : await IptvImportManager().importFromNetworkUrl(url, name);
          return success;
        },
      ),
    );
    urlController.dispose();
    nameController.dispose();
    if (ok == true) _showMessage(i18n('settings_saved'));
  }

  // ---- EPG 源选择(原 _EpgSourceDialog 紧凑版)----

  Future<void> _showEpgSourceDialog() async {
    List<database.EpgSource> sources;
    try {
      sources = await Get.find<DbService>().db.getAllEpgSources();
    } catch (_) {
      _showMessage(i18n('epg_sources_load_failed'));
      return;
    }
    if (!mounted) return;
    if (sources.isEmpty) {
      _showMessage(i18n('no_epg_sources_found'));
      return;
    }
    final selected = await showDialog<database.EpgSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n('select_epg_source')),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        content: SizedBox(
          width: 420,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (dialogContext, index) {
              final source = sources[index];
              final active = _iptv.selectedSourceId.v == source.id;
              return ListTile(
                dense: true,
                leading: Icon(
                  active ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 20,
                  color: active ? Theme.of(dialogContext).colorScheme.primary : null,
                ),
                title: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(source.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(dialogContext).pop(source),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(i18n('cancel')))],
      ),
    );
    if (selected == null) return;
    _iptv.selectedSourceId.v = selected.id;
    _iptv.selectedSourceName.v = selected.name;
    _showMessage(i18n('epg_source_switched'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSettingLine(
          title: i18n('iptv_list_manage'),
          desc: i18n('download_guide_sub'),
          trailing: zishuLineChevron(context),
          onTap: () => ZishuPageHostDialog.show(context, page: const IptvManagePage()),
        ),
        ZishuSectionCaption(i18n('auto_sync_settings')),
        ZishuSwitchLine.rx(title: i18n('auto_sync_title'), desc: i18n('auto_sync_desc'), rx: _iptv.isAutoSyncEnabled),
        Obx(
          () => _iptv.isAutoSyncEnabled.v
              ? ZishuDropdownLine<int>(
                  title: i18n('sync_interval_title'),
                  desc: i18n('sync_interval_hours', args: {'hour': '${_iptv.autoSyncHoursInterval.v}'}),
                  values: const [2, 6, 12, 24, 48, 72],
                  labelOf: (hours) => '$hours ${i18n('hours')}',
                  readValue: () => _iptv.autoSyncHoursInterval.v,
                  onChanged: (hours) {
                    _iptv.autoSyncHoursInterval.v = hours;
                    _showMessage(i18n('settings_saved'));
                  },
                )
              : const SizedBox(width: double.infinity),
        ),
        Obx(
          () => ZishuSettingLine(
            title: i18n('custom_ua_title'),
            desc: _iptv.customIptvUserAgent.v,
            onTap: () => unawaited(_showUaDialog()),
          ),
        ),
        ZishuSectionCaption(i18n('playlist_settings')),
        ZishuSettingLine(
          title: i18n('import_playlist'),
          desc: i18n('playlist_file_type'),
          enabled: !_importing,
          trailing: _importing ? zishuMiniSpinner(context) : null,
          onTap: _importing ? null : () => unawaited(_showImportDialog(isEpg: false)),
        ),
        ZishuSectionCaption(i18n('epg_settings')),
        ZishuSettingLine(
          title: i18n('import_epg_source'),
          desc: i18n('epg_file_type'),
          enabled: !_importing,
          trailing: _importing ? zishuMiniSpinner(context) : null,
          onTap: _importing ? null : () => unawaited(_showImportDialog(isEpg: true)),
        ),
        Obx(
          () => ZishuSettingLine(
            title: i18n('active_epg_source'),
            desc: _iptv.selectedSourceId.v.isEmpty ? i18n('please_select_epg_source') : _iptv.selectedSourceName.v,
            onTap: () => unawaited(_showEpgSourceDialog()),
          ),
        ),
      ],
    );
  }
}

/// 网络导入弹窗体(URL/名称校验 + 提交 busy,字段由调用方持有便于销毁)。
class _NetworkImportDialogBody extends StatefulWidget {
  const _NetworkImportDialogBody({
    required this.isEpg,
    required this.urlController,
    required this.nameController,
    required this.submit,
  });

  final bool isEpg;
  final TextEditingController urlController;
  final TextEditingController nameController;
  final Future<bool> Function(String url, String name) submit;

  @override
  State<_NetworkImportDialogBody> createState() => _NetworkImportDialogBodyState();
}

class _NetworkImportDialogBodyState extends State<_NetworkImportDialogBody> {
  bool _submitting = false;
  String? _errorKey;

  Future<void> _submit() async {
    if (_submitting) return;
    final url = widget.urlController.text.trim();
    final name = widget.nameController.text.trim();
    final validation = url.isEmpty
        ? 'enter_download_link'
        : !FileUtils.isValidUrl(url)
        ? 'invalid_download_link'
        : name.isEmpty
        ? 'enter_file_name'
        : null;
    if (validation != null) {
      setState(() => _errorKey = validation);
      return;
    }
    setState(() {
      _submitting = true;
      _errorKey = null;
    });
    bool succeeded = false;
    try {
      succeeded = await widget.submit(url, name);
    } catch (_) {
      // 保留可编辑草稿,失败给通用文案(对齐原页口径)。
    }
    if (!mounted) return;
    if (succeeded) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _errorKey = 'network_import_failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(i18n('enter_download_url')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.urlController,
              readOnly: _submitting,
              autofocus: true,
              decoration: zishuDenseInput(context, i18n('download_url')),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: widget.nameController,
              readOnly: _submitting,
              decoration: zishuDenseInput(context, i18n('file_name')),
            ),
            if (_errorKey != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                i18n(_errorKey!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_submitting) ...[const SizedBox(height: AppSpacing.sm), const LinearProgressIndicator()],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(i18n(_submitting ? 'close' : 'cancel')),
        ),
        FilledButton(onPressed: _submitting ? null : () => unawaited(_submit()), child: Text(i18n('confirm'))),
      ],
    );
  }
}
