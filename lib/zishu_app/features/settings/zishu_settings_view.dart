/// zishu 风格设置索引视图(骨架):surface 卡片分组 + 「图标 + 标题 + 描述 +
/// chevron」行,分组结构与 pure_live `modules/settings/settings_page.dart`
/// 同构(主题 / IPTV / 刷新 / 视频 / 播放内核 / 网络代理 / 本地互动 / 通用 /
/// 数据 / 备份)。每行仅做导航(`Get.to` 跳既有设置子页),**不自建任何设置
/// 逻辑**;图标与文案 1:1 映射自 settings_page.dart 对应入口。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/iptv/iptv_page.dart';
import 'package:pure_live/modules/settings/pages/cache_data_settings_page.dart';
import 'package:pure_live/modules/settings/pages/general_settings_page.dart';
import 'package:pure_live/modules/settings/pages/local_config_preveiw.dart';
import 'package:pure_live/modules/settings/pages/local_interaction_settings_page.dart';
import 'package:pure_live/modules/settings/pages/navigation_settings_page.dart';
import 'package:pure_live/modules/settings/pages/pip_danmaku_settings_page.dart';
import 'package:pure_live/modules/settings/pages/platform_order_settings_page.dart';
import 'package:pure_live/modules/settings/pages/platform_settings_page.dart';
import 'package:pure_live/modules/settings/pages/player_kernel_settings_page.dart';
import 'package:pure_live/modules/settings/pages/network_proxy_settings_page.dart';
import 'package:pure_live/modules/settings/pages/refresh_settings.dart';
import 'package:pure_live/modules/settings/pages/theme_settings_page.dart';
import 'package:pure_live/modules/settings/pages/video_settings_page.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 缺失的 i18n key(仅有 `config_preview`,无描述 key),中文常量兜底。
const String _kConfigPreviewDesc = '查看本地已保存的配置内容';

/// zishu 设置索引:可嵌入任意宿主(Shell 选项卡 / 对话框)。
///
/// [embedded] = true 时隐藏页顶大标题(宿主自己画标题行,对齐 zishu
/// `SettingsView.embedded` 语义),分组与滚动行为不变。
class ZishuSettingsView extends StatelessWidget {
  const ZishuSettingsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // 背景交宿主 Scaffold;本视图只用 token 度量,不取色板。
    // ignore: unused_local_variable
    final tokens = context.tokens;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!embedded) ...[
                Text(i18n('settings_title'), style: context.textTitle.copyWith(fontSize: AppFontSize.headline)),
                const SizedBox(height: AppSpacing.lg),
              ],
              _SettingsGroup(
                title: i18n('theme_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.palette_outlined,
                    title: i18n('theme_customization'),
                    subtitle: i18n('theme_customization_desc'),
                    onTap: () => Get.to(() => const ThemeSettingsPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('iptv_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.tv_outlined,
                    title: i18n('iptv_settings'),
                    subtitle: i18n('manage_iptv_sources'),
                    onTap: () => Get.to(() => const IptvPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('refresh_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.refresh_rounded,
                    title: i18n('refresh_settings'),
                    subtitle: i18n('refresh_settings_subtitle'),
                    onTap: () => Get.to(() => const RefreshSettingsPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('video_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.movie_outlined,
                    title: i18n('video'),
                    subtitle: i18n('video_desc'),
                    onTap: () => Get.to(() => const VideoSettingsPage()),
                  ),
                  _SettingsRow(
                    icon: Icons.picture_in_picture_alt_outlined,
                    title: i18n('pip_danmaku'),
                    subtitle: i18n('pip_danmaku_desc'),
                    onTap: () => Get.to(() => const PipDanmakuSettingsPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('player_kernel_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.memory_outlined,
                    title: i18n('player_kernel'),
                    subtitle: i18n('player_kernel_desc'),
                    onTap: () => Get.to(() => const PlayerKernelSettingsPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('network_proxy_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.public_outlined,
                    title: i18n('custom_network_proxy'),
                    subtitle: i18n('custom_network_proxy_desc'),
                    onTap: () => Get.to(() => const NetworkProxySettingsPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('local_interaction_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.auto_awesome_outlined,
                    title: i18n('local_interaction_title'),
                    subtitle: i18n('local_interaction_settings_desc'),
                    onTap: () => Get.to(() => const LocalInteractionSettingsPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('general_settings'),
                children: [
                  _SettingsRow(
                    icon: Icons.tune_outlined,
                    title: i18n('general'),
                    subtitle: i18n('general_desc'),
                    onTap: () => Get.to(() => const GeneralSettingsPage()),
                  ),
                  _SettingsRow(
                    icon: Icons.menu_outlined,
                    title: i18n('navigation_display_settings'),
                    subtitle: i18n('navigation_display_settings_desc'),
                    onTap: () => Get.to(() => const NavigationSettingsPage()),
                  ),
                  _SettingsRow(
                    icon: Icons.sort_outlined,
                    title: i18n('platform_order_settings'),
                    subtitle: i18n('platform_order_settings_desc'),
                    onTap: () => Get.to(() => const PlatformOrderSettingsPage()),
                  ),
                  _SettingsRow(
                    icon: Icons.apps_outlined,
                    title: i18n('platform_settings'),
                    subtitle: i18n('platform_settings_desc'),
                    onTap: () => Get.to(() => const PlatformSettingsPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('data_manage'),
                children: [
                  _SettingsRow(
                    icon: Icons.storage_outlined,
                    title: i18n('cache_and_data'),
                    subtitle: i18n('cache_and_data_desc'),
                    onTap: () => Get.to(() => const CacheDataSettingsPage()),
                  ),
                  // settings_page 原为 AppBar 顶栏动作,此处收进数据组当行入口。
                  _SettingsRow(
                    icon: Icons.description_outlined,
                    title: i18n('config_preview'),
                    subtitle: _kConfigPreviewDesc,
                    onTap: () => Get.to(() => const LocalConfigPreviewPage()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: i18n('backup_manage'),
                children: [
                  _SettingsRow(
                    icon: Icons.cloud_outlined,
                    title: i18n('backup_recover'),
                    subtitle: i18n('backup_recover_desc'),
                    onTap: () => Get.to(() => const BackupPage()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

/// surface 卡片分组容器(zishu `_SettingsGroup` 同构)。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allLg,
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textBody.copyWith(fontWeight: FontWeight.w700, color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

/// 一行设置入口:图标块 + 标题 + 描述 + chevron,整行点击跳既有子页。
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
              child: Icon(icon, size: 18, color: tokens.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textBody.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.textCaption),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Icon(Icons.chevron_right_rounded, size: 18, color: tokens.textSecondary),
          ],
        ),
      ),
    );
  }
}
