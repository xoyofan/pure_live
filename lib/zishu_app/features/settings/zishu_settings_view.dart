/// zishu 风格设置视图(手风琴版,2026-10 用户裁决):组头点击原地展开/收起,
/// 同一时刻至多展开一组(互斥单开),**不再跳子页看核心设置**。
///
/// 分组口径:
/// - 「通用」(默认展开):紧凑布局 / 标题自动翻译 / 后台播放 三个开关 +
///   自动刷新间隔下拉,**核心设置内联**,长尾的「导航与显示」保留入口行;
/// - 「外观」:主题模式三选 + 主题色板圆点(抄 `ThemeSettingsPage` 精简版);
/// - 「平台」:平台顺序与可见 + 平台显示与授权入口行(跳子页)+ 一行说明;
/// - 其余组(IPTV / 刷新 / 视频 / 播放内核 / 网络代理 / 本地互动 / 数据 /
///   备份):保留原有入口行列表(跳既有子页),内容不动。
///
/// 统一入口:外壳经 [openZishuSettingsDialog] 以对话框形态打开本视图
/// (对齐 zishu `openSettingsDialog` 口径,不再推整页)。
library;

import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/iptv/iptv_page.dart';
import 'package:pure_live/modules/settings/pages/cache_data_settings_page.dart';
import 'package:pure_live/modules/settings/pages/local_config_preveiw.dart';
import 'package:pure_live/modules/settings/pages/local_interaction_settings_page.dart';
import 'package:pure_live/modules/settings/pages/navigation_settings_page.dart';
import 'package:pure_live/modules/settings/pages/pip_danmaku_settings_page.dart';
import 'package:pure_live/modules/settings/pages/platform_order_settings_page.dart';
import 'package:pure_live/modules/settings/pages/platform_settings_page.dart';
import 'package:pure_live/modules/settings/pages/player_kernel_settings_page.dart';
import 'package:pure_live/modules/settings/pages/network_proxy_settings_page.dart';
import 'package:pure_live/modules/settings/pages/refresh_settings.dart';
import 'package:pure_live/modules/settings/pages/video_settings_page.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 缺失的 i18n key(仅有 `config_preview`,无描述 key),中文常量兜底。
const String _kConfigPreviewDesc = '查看本地已保存的配置内容';

/// 缺失的 i18n key(zh.json 无 translate/翻译 相关键,见交付报告),中文常量兜底;
/// 建议补 `title_translation` / `title_translation_desc`。
const String _kTitleTranslationLabel = '标题自动翻译';

/// 开关行的 caption 描述:说明走免费在线接口、失败回原文。
const String _kTitleTranslationDesc = '开启后直播间标题经免费在线接口译为中文,失败时显示原文';

/// 缺失的 i18n key(zh.json 仅有 `room_card_appearance`,无独立「外观」键),
/// 中文常量兜底;建议补 `appearance_settings`。
const String _kAppearanceGroupLabel = '外观';

/// 「平台」组的一行说明(缺失 i18n key,中文常量兜底):改动落在
/// `app.savedPlatformIds`,外壳顶栏/侧栏按它 Obx 渲染,故即时生效。
const String _kPlatformOrderNote = '改动即时生效:外壳顶栏平台入口与侧栏色块会同步应用新的排序与显隐';

/// zishu 设置索引:可嵌入任意宿主(Shell 选项卡 / 对话框)。
///
/// [embedded] = true 时隐藏页顶大标题(宿主自己画标题行,对齐 zishu
/// `SettingsView.embedded` 语义),分组与滚动行为不变。
class ZishuSettingsView extends StatefulWidget {
  const ZishuSettingsView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ZishuSettingsView> createState() => _ZishuSettingsViewState();
}

class _ZishuSettingsViewState extends State<ZishuSettingsView> {
  /// 当前展开的组下标(互斥单开);null = 全部收起。「通用」组(下标 0)默认展开。
  int? _expandedIndex = 0;

  void _toggle(int index) {
    setState(() => _expandedIndex = _expandedIndex == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    // 背景交宿主 Scaffold;本视图只用 token 度量,不取色板。
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded) ...[
                Text(i18n('settings_title'), style: context.textTitle.copyWith(fontSize: AppFontSize.headline)),
                const SizedBox(height: AppSpacing.lg),
              ],
              _AccordionSection(
                title: i18n('general'),
                icon: Icons.tune_outlined,
                expanded: _expandedIndex == 0,
                onToggle: () => _toggle(0),
                children: [
                  // 紧凑布局:绑 app.enableDenseFavorites(RxBool,
                  // app_settings_controller.dart:43),room_grid_view 消费。
                  _SettingsSwitchRow(
                    icon: Icons.view_agenda_outlined,
                    title: i18n('enable_dense_favorites_mode'),
                    subtitle: i18n('enable_dense_favorites_mode_subtitle'),
                    rx: SettingsService.to.app.enableDenseFavorites,
                  ),
                  // 标题自动翻译开关:绑 app.enableTitleTranslation
                  // (RxBool,hiveBool 默认 false),ZishuRoomCard 的 TranslatedText 消费。
                  _SettingsSwitchRow(
                    icon: Icons.translate_rounded,
                    title: _kTitleTranslationLabel,
                    subtitle: _kTitleTranslationDesc,
                    rx: SettingsService.to.app.enableTitleTranslation,
                  ),
                  // 后台播放:绑 app.enableBackgroundPlay(RxBool,
                  // app_settings_controller.dart:44)。子页的 Android 权限申请流程
                  // 不内联,zishu 桌面壳下直接写 Rx(live_audio_service 读同一 Rx)。
                  _SettingsSwitchRow(
                    icon: Icons.music_note_outlined,
                    title: i18n('enable_background_play'),
                    subtitle: i18n('enable_background_play_subtitle'),
                    rx: SettingsService.to.app.enableBackgroundPlay,
                  ),
                  // 自动刷新间隔:app.autoRefreshTime(RxInt,默认 3,
                  // app_settings_controller.dart:42),简化为 1/3/5/10 分钟下拉。
                  _SettingsDropdownRow(
                    icon: Icons.timer_outlined,
                    title: i18n('auto_refresh_time'),
                    subtitle: i18n('auto_refresh_time_subtitle'),
                    rx: SettingsService.to.app.autoRefreshTime,
                    options: const [1, 3, 5, 10],
                  ),
                  // 长尾入口(内容未内联,保留跳子页):导航与显示。
                  _SettingsRow(
                    icon: Icons.menu_outlined,
                    title: i18n('navigation_display_settings'),
                    subtitle: i18n('navigation_display_settings_desc'),
                    onTap: () => Get.to(() => const NavigationSettingsPage()),
                  ),
                ],
              ),
              _AccordionSection(
                title: _kAppearanceGroupLabel,
                icon: Icons.palette_outlined,
                expanded: _expandedIndex == 1,
                onToggle: () => _toggle(1),
                children: const [_AppearanceSettingsContent()],
              ),
              _AccordionSection(
                title: i18n('platform'),
                icon: Icons.apps_outlined,
                expanded: _expandedIndex == 2,
                onToggle: () => _toggle(2),
                children: [
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
                  // 一行说明:改动落在 savedPlatformIds,外壳 Obx 即时同步。
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(_kPlatformOrderNote, style: context.textCaption),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('iptv_settings'),
                icon: Icons.tv_outlined,
                expanded: _expandedIndex == 3,
                onToggle: () => _toggle(3),
                children: [
                  _SettingsRow(
                    icon: Icons.tv_outlined,
                    title: i18n('iptv_settings'),
                    subtitle: i18n('manage_iptv_sources'),
                    onTap: () => Get.to(() => const IptvPage()),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('refresh_settings'),
                icon: Icons.refresh_rounded,
                expanded: _expandedIndex == 4,
                onToggle: () => _toggle(4),
                children: [
                  _SettingsRow(
                    icon: Icons.refresh_rounded,
                    title: i18n('refresh_settings'),
                    subtitle: i18n('refresh_settings_subtitle'),
                    onTap: () => Get.to(() => const RefreshSettingsPage()),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('video_settings'),
                icon: Icons.movie_outlined,
                expanded: _expandedIndex == 5,
                onToggle: () => _toggle(5),
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
              _AccordionSection(
                title: i18n('player_kernel_settings'),
                icon: Icons.memory_outlined,
                expanded: _expandedIndex == 6,
                onToggle: () => _toggle(6),
                children: [
                  _SettingsRow(
                    icon: Icons.memory_outlined,
                    title: i18n('player_kernel'),
                    subtitle: i18n('player_kernel_desc'),
                    onTap: () => Get.to(() => const PlayerKernelSettingsPage()),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('network_proxy_settings'),
                icon: Icons.public_outlined,
                expanded: _expandedIndex == 7,
                onToggle: () => _toggle(7),
                children: [
                  _SettingsRow(
                    icon: Icons.public_outlined,
                    title: i18n('custom_network_proxy'),
                    subtitle: i18n('custom_network_proxy_desc'),
                    onTap: () => Get.to(() => const NetworkProxySettingsPage()),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('local_interaction_settings'),
                icon: Icons.auto_awesome_outlined,
                expanded: _expandedIndex == 8,
                onToggle: () => _toggle(8),
                children: [
                  _SettingsRow(
                    icon: Icons.auto_awesome_outlined,
                    title: i18n('local_interaction_title'),
                    subtitle: i18n('local_interaction_settings_desc'),
                    onTap: () => Get.to(() => const LocalInteractionSettingsPage()),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('data_manage'),
                icon: Icons.storage_outlined,
                expanded: _expandedIndex == 9,
                onToggle: () => _toggle(9),
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
              _AccordionSection(
                title: i18n('backup_manage'),
                icon: Icons.cloud_outlined,
                expanded: _expandedIndex == 10,
                onToggle: () => _toggle(10),
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

/// 手风琴组:surface 卡 + 「图标块 + 标题 + 旋转 chevron」组头(点击
/// [onToggle] 切换)+ [AnimatedSize] 原地展开/收起的内容区。
///
/// 组头图标块沿用行项的 36×36 `surfaceRaised` 底;标题 w600;chevron 用
/// `expand_more_rounded`,展开时旋转半圈([AppMotion.fast])。
class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final IconData icon;

  /// 是否展开(由宿主的 `_expandedIndex` 计算传入)。
  final bool expanded;

  /// 点击组头回调(宿主切换 `_expandedIndex`)。
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allLg,
        border: Border.all(color: tokens.border),
      ),
      child: Column(
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
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textBody.copyWith(fontSize: AppFontSize.subtitle, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
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
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xs),
                        ...children,
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「外观」组内容:主题模式三选 + 主题色板圆点。
///
/// 抄 `ThemeSettingsPage` 的口径精简而来:模式写
/// `theme.changeThemeMode`(写 hive + `Get.changeThemeMode`),颜色写
/// `theme.changeThemeColorSwitch(hex)`(写 hive + 重建明暗两套主题);
/// 选中态读 `resolvedThemeModeName` / `resolvedThemeColorHex`(归一化的
/// 大写无 `#` 6 位 hex,与 `Color.hex` 同格式可直接比)。
class _AppearanceSettingsContent extends StatelessWidget {
  const _AppearanceSettingsContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n('change_theme_mode'), style: context.textCaption),
          const SizedBox(height: AppSpacing.sm),
          Obx(() {
            final current = SettingsService.to.theme.resolvedThemeModeName;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in AppConsts.themeModes.keys)
                  _ZishuOptionChip(
                    label: i18n(AppConsts.themeModeI18n[name]!),
                    selected: current == name,
                    onTap: () => SettingsService.to.theme.changeThemeMode(name),
                  ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.md),
          Text(i18n('change_theme_color'), style: context.textCaption),
          const SizedBox(height: AppSpacing.sm),
          Obx(() {
            final currentHex = SettingsService.to.theme.resolvedThemeColorHex;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in AppConsts.themeColors.entries)
                  _ThemeColorDot(
                    color: entry.value,
                    selected: entry.value.hex == currentHex,
                    onTap: () => SettingsService.to.theme.changeThemeColorSwitch(entry.value.hex),
                  ),
              ],
            );
          }),
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

/// 一行开关设置:图标块 + 标题 + 描述同 [_SettingsRow],尾部以 Switch 替代
/// chevron。值绑定外部 RxBool(写入即经 HiveRx 自动持久化),内部 Obx 即时刷新。
class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({required this.icon, required this.title, required this.subtitle, required this.rx});

  final IconData icon;
  final String title;
  final String subtitle;

  /// 开关绑定的响应式布尔(如 `SettingsService.to.app.enableTitleTranslation`)。
  final RxBool rx;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(
      () => Padding(
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
            Switch(value: rx.v, onChanged: (value) => rx.v = value),
          ],
        ),
      ),
    );
  }
}

/// 一行下拉设置:图标块 + 标题 + 描述同 [_SettingsRow],尾部以下拉替代
/// chevron。值绑定外部 RxInt(写入即经 HiveRx 自动持久化)。
class _SettingsDropdownRow extends StatelessWidget {
  const _SettingsDropdownRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rx,
    required this.options,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// 下拉绑定的响应式整数(如 `SettingsService.to.app.autoRefreshTime`)。
  final RxInt rx;

  /// 候选档位(如自动刷新间隔 1/3/5/10 分钟)。
  final List<int> options;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(() {
      // DropdownButton.value 必须命中 items:已存值不在候选档位(如历史遗留
      // 的 2 分钟)时把它并入候选,避免断言失败、也让展示如实反映当前值。
      final values = <int>{...options, rx.v}.toList()..sort();
      return Padding(
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
            DropdownButton<int>(
              value: rx.v,
              underline: const SizedBox.shrink(),
              isDense: true,
              icon: Icon(Icons.expand_more_rounded, size: 16, color: tokens.textSecondary),
              style: context.textBody,
              items: [
                for (final value in values)
                  DropdownMenuItem<int>(value: value, child: Text('$value ${i18n('minutes')}')),
              ],
              onChanged: (value) {
                if (value != null) rx.v = value;
              },
            ),
          ],
        ),
      );
    });
  }
}

/// zishu 风格单选 chip(样式对齐 follow 筛选 chips,见
/// `zishu_follow_filters.dart` 的 `_PlatformChip`):选中 accent 淡底 +
/// accent 描边 + w700,未选中 surface 底 + border 描边 + w400。
class _ZishuOptionChip extends StatelessWidget {
  const _ZishuOptionChip({required this.label, required this.selected, required this.onTap});

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

/// 主题色板圆点:色底圆形,选中时 `textPrimary` 描边(2px,恒宽避免跳动)。
class _ThemeColorDot extends StatelessWidget {
  const _ThemeColorDot({required this.color, required this.selected, required this.onTap});

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? tokens.textPrimary : Colors.transparent, width: 2),
        ),
      ),
    );
  }
}

/// 设置对话框宽度/高度上限(对齐 zishu settings_view 的 760×840,math.min 需 double)。
const double _kSettingsDialogWidth = 760;
const double _kSettingsDialogMaxHeight = 840;

/// 打开 zishu 设置弹窗(外壳顶栏设置钮 / 用户菜单「设置」/ 窄屏底栏设置项共用)。
///
/// 对齐 zishu `openSettingsDialog` 口径:showDialog + Dialog 框(宽高取
/// min(视口, 760×840)、surface 底、allLg 圆角、barrier 用 tokens.barrier),
/// 内嵌 [ZishuSettingsView](embedded 隐藏页顶大标题,弹窗自画标题行)。
Future<void> openZishuSettingsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.tokens.barrier,
    builder: (_) => const _ZishuSettingsDialogFrame(),
  );
}

/// 设置弹窗外框:标题行(设置 + 关闭)+ 内嵌设置视图。
class _ZishuSettingsDialogFrame extends StatelessWidget {
  const _ZishuSettingsDialogFrame();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(viewport.width * 0.92, _kSettingsDialogWidth);
    final height = math.min(viewport.height * 0.82, _kSettingsDialogMaxHeight);
    return Dialog(
      key: const Key('zishu-settings-dialog'),
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.allLg),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Text(
                    i18n('settings_title'),
                    style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle, color: tokens.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('zishu-settings-dialog-close'),
                    tooltip: i18n('cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    iconSize: 18,
                    color: tokens.textSecondary,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Expanded(child: ZishuSettingsView(embedded: true)),
          ],
        ),
      ),
    );
  }
}
