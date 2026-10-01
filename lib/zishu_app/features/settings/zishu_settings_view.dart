/// zishu 风格设置视图(手风琴版,2026-10 用户裁决):组头点击原地展开/收起,
/// 同一时刻至多展开一组(互斥单开),**不再跳子页看核心设置**。
///
/// 任务D(全面扁平化,2026-10)在 R10 基础上把组内残留的跳页行也改为就地
/// 展开:原 `Get.to` 独立设置页的行全部换成 [ZishuExpandLine] 嵌套手风琴
/// (点标题展开、再点收起,组内互斥单开),展开区为「复用 controller 逻辑 +
/// 重写紧凑 UI」的紧凑内容,不再 import 独立页面 widget。仅各页内部再下钻的
/// 重管理页(第三方授权 / 标签管理 / WebDAV / 远程同步 / 弹幕屏蔽 / 字体管理 /
/// IPTV 频道管理 / 账号页)按「更多设置类弹 dialog 入口」口径保留为对话框宿主。
///
/// 行样式口径(扁平化):
/// - 标题与说明**同一行**(说明弱化、超长 ellipsis,不再两行堆叠);
/// - 行高紧凑(上下 padding 压到 [AppSpacing.xs] 级);
/// - 开关一律 [CompactSwitch] 迷你开关(30×16,一行高度);下拉/滑杆同样一行化;
/// - 平台顺序与可见展开区为**紧凑横排 Wrap**(平台图标 + 名称 + 可见小开关 +
///   拖拽把手,保留拖拽排序与可见切换)。
///
/// 分组口径(11 组,与 R10 一致):通用(默认展开)/ 外观 / 平台 / IPTV /
/// 刷新 / 视频 / 播放内核 / 网络代理 / 本地互动 / 数据 / 备份。
///
/// 统一入口:外壳经 [openZishuSettingsDialog] 以对话框形态打开本视图
/// (对齐 zishu `openSettingsDialog` 口径,不再推整页);弹窗高度随内容
/// 自适应收缩(上限不变)。
library;

import 'dart:math' as math;

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

import 'zishu_settings_platform.dart';
import 'zishu_settings_rows.dart';
import 'zishu_settings_sections.dart';

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

  /// 当前组内展开的嵌套行下标(原「跳子页」行的就地展开,互斥单开);
  /// 切组时重置,新组默认全收起。
  int? _expandedChild;

  void _toggleGroup(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else {
        _expandedIndex = index;
        _expandedChild = null;
      }
    });
  }

  void _toggleChild(int index) {
    setState(() => _expandedChild = _expandedChild == index ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    // 背景交宿主 Scaffold;本视图只用 token 度量,不取色板。
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                onToggle: () => _toggleGroup(0),
                children: [
                  // 紧凑布局:绑 app.enableDenseFavorites(RxBool,
                  // app_settings_controller.dart:43),room_grid_view 消费。
                  ZishuSwitchLine.rx(
                    title: i18n('enable_dense_favorites_mode'),
                    desc: i18n('enable_dense_favorites_mode_subtitle'),
                    rx: SettingsService.to.app.enableDenseFavorites,
                  ),
                  // 标题自动翻译开关:绑 app.enableTitleTranslation
                  // (RxBool,hiveBool 默认 false),ZishuRoomCard 的 TranslatedText 消费。
                  ZishuSwitchLine.rx(
                    title: _kTitleTranslationLabel,
                    desc: _kTitleTranslationDesc,
                    rx: SettingsService.to.app.enableTitleTranslation,
                  ),
                  // 后台播放:绑 app.enableBackgroundPlay(RxBool,
                  // app_settings_controller.dart:44)。子页的 Android 权限申请流程
                  // 不内联,zishu 桌面壳下直接写 Rx(live_audio_service 读同一 Rx)。
                  ZishuSwitchLine.rx(
                    title: i18n('enable_background_play'),
                    desc: i18n('enable_background_play_subtitle'),
                    rx: SettingsService.to.app.enableBackgroundPlay,
                  ),
                  // 自动刷新间隔:app.autoRefreshTime(RxInt,默认 3,
                  // app_settings_controller.dart:42),简化为 1/3/5/10 分钟下拉。
                  ZishuDropdownLine<int>(
                    title: i18n('auto_refresh_time'),
                    desc: i18n('auto_refresh_time_subtitle'),
                    values: const [1, 3, 5, 10],
                    labelOf: (value) => '$value ${i18n('minutes')}',
                    readValue: () => SettingsService.to.app.autoRefreshTime.v,
                    onChanged: (value) => SettingsService.to.app.autoRefreshTime.v = value,
                  ),
                  // 长尾入口:导航与显示,就地展开(原跳 NavigationSettingsPage)。
                  ZishuExpandLine(
                    icon: Icons.menu_outlined,
                    title: i18n('navigation_display_settings'),
                    desc: i18n('navigation_display_settings_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuNavigationSettingsContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: _kAppearanceGroupLabel,
                icon: Icons.palette_outlined,
                expanded: _expandedIndex == 1,
                onToggle: () => _toggleGroup(1),
                children: const [_AppearanceSettingsContent()],
              ),
              _AccordionSection(
                title: i18n('platform'),
                icon: Icons.apps_outlined,
                expanded: _expandedIndex == 2,
                onToggle: () => _toggleGroup(2),
                children: [
                  // 平台顺序与可见:紧凑横排 Wrap + 拖拽排序 + 可见小开关。
                  ZishuExpandLine(
                    icon: Icons.sort_outlined,
                    title: i18n('platform_order_settings'),
                    desc: i18n('platform_order_settings_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuPlatformOrderContent(),
                  ),
                  // 平台显示与授权:偏好平台 chips + 授权/标签管理对话框入口。
                  ZishuExpandLine(
                    icon: Icons.apps_outlined,
                    title: i18n('platform_settings'),
                    desc: i18n('platform_settings_desc'),
                    expanded: _expandedChild == 1,
                    onToggle: () => _toggleChild(1),
                    child: const ZishuPlatformDisplayContent(),
                  ),
                  // 一行说明:改动落在 savedPlatformIds,外壳 Obx 即时同步。
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
                    child: Text(_kPlatformOrderNote, style: context.textCaption),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('iptv_settings'),
                icon: Icons.tv_outlined,
                expanded: _expandedIndex == 3,
                onToggle: () => _toggleGroup(3),
                children: [
                  ZishuExpandLine(
                    icon: Icons.tv_outlined,
                    title: i18n('iptv_settings'),
                    desc: i18n('manage_iptv_sources'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuIptvContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('refresh_settings'),
                icon: Icons.refresh_rounded,
                expanded: _expandedIndex == 4,
                onToggle: () => _toggleGroup(4),
                children: [
                  ZishuExpandLine(
                    icon: Icons.refresh_rounded,
                    title: i18n('refresh_settings'),
                    desc: i18n('refresh_settings_subtitle'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuRefreshSettingsContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('video_settings'),
                icon: Icons.movie_outlined,
                expanded: _expandedIndex == 5,
                onToggle: () => _toggleGroup(5),
                children: [
                  ZishuExpandLine(
                    icon: Icons.movie_outlined,
                    title: i18n('video'),
                    desc: i18n('video_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuVideoSettingsContent(),
                  ),
                  ZishuExpandLine(
                    icon: Icons.picture_in_picture_alt_outlined,
                    title: i18n('pip_danmaku'),
                    desc: i18n('pip_danmaku_desc'),
                    expanded: _expandedChild == 1,
                    onToggle: () => _toggleChild(1),
                    child: const ZishuPipDanmakuSettingsContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('player_kernel_settings'),
                icon: Icons.memory_outlined,
                expanded: _expandedIndex == 6,
                onToggle: () => _toggleGroup(6),
                children: [
                  ZishuExpandLine(
                    icon: Icons.memory_outlined,
                    title: i18n('player_kernel'),
                    desc: i18n('player_kernel_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuPlayerKernelContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('network_proxy_settings'),
                icon: Icons.public_outlined,
                expanded: _expandedIndex == 7,
                onToggle: () => _toggleGroup(7),
                children: [
                  ZishuExpandLine(
                    icon: Icons.public_outlined,
                    title: i18n('custom_network_proxy'),
                    desc: i18n('custom_network_proxy_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuNetworkProxyContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('local_interaction_settings'),
                icon: Icons.auto_awesome_outlined,
                expanded: _expandedIndex == 8,
                onToggle: () => _toggleGroup(8),
                children: [
                  ZishuExpandLine(
                    icon: Icons.auto_awesome_outlined,
                    title: i18n('local_interaction_title'),
                    desc: i18n('local_interaction_settings_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuLocalInteractionContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('data_manage'),
                icon: Icons.storage_outlined,
                expanded: _expandedIndex == 9,
                onToggle: () => _toggleGroup(9),
                children: [
                  ZishuExpandLine(
                    icon: Icons.storage_outlined,
                    title: i18n('cache_and_data'),
                    desc: i18n('cache_and_data_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuCacheDataContent(),
                  ),
                  // settings_page 原为 AppBar 顶栏动作,此处收进数据组就地展开。
                  ZishuExpandLine(
                    icon: Icons.description_outlined,
                    title: i18n('config_preview'),
                    desc: _kConfigPreviewDesc,
                    expanded: _expandedChild == 1,
                    onToggle: () => _toggleChild(1),
                    child: const ZishuConfigPreviewContent(),
                  ),
                ],
              ),
              _AccordionSection(
                title: i18n('backup_manage'),
                icon: Icons.cloud_outlined,
                expanded: _expandedIndex == 10,
                onToggle: () => _toggleGroup(10),
                children: [
                  ZishuExpandLine(
                    icon: Icons.cloud_outlined,
                    title: i18n('backup_recover'),
                    desc: i18n('backup_recover_desc'),
                    expanded: _expandedChild == 0,
                    onToggle: () => _toggleChild(0),
                    child: const ZishuBackupContent(),
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
/// 组头图标块沿用行项的 36×36 `surfaceRaised` 底(R10 口径保留);标题 w600;
/// chevron 用 `expand_more_rounded`,展开时旋转半圈([AppMotion.fast])。
/// 任务D:组内上下 padding 相比 R10 压缩一档(lg → md / sm → xs)。
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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
/// 任务D:标题与说明压成 caption 行 + 紧凑 Wrap,不再大间距堆叠。
class _AppearanceSettingsContent extends StatelessWidget {
  const _AppearanceSettingsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSectionCaption(i18n('change_theme_mode')),
        Obx(() {
          final current = SettingsService.to.theme.resolvedThemeModeName;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final name in AppConsts.themeModes.keys)
                ZishuOptionChip(
                  label: i18n(AppConsts.themeModeI18n[name]!),
                  selected: current == name,
                  onTap: () => SettingsService.to.theme.changeThemeMode(name),
                ),
            ],
          );
        }),
        ZishuSectionCaption(i18n('change_theme_color')),
        Obx(() {
          final currentHex = SettingsService.to.theme.resolvedThemeColorHex;
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
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

/// 设置对话框宽度上限与高度上限(对齐 zishu settings_view 的 760×840,
/// math.min 需 double)。
const double _kSettingsDialogWidth = 760;
const double _kSettingsDialogMaxHeight = 840;

/// 打开 zishu 设置弹窗(外壳顶栏设置钮 / 用户菜单「设置」/ 窄屏底栏设置项共用)。
///
/// 对齐 zishu `openSettingsDialog` 口径:showDialog + Dialog 框(宽取
/// min(视口, 760)、高随内容自适应、上限 min(视口×0.88, 840)、surface 底、
/// allLg 圆角、barrier 用 tokens.barrier),内嵌 [ZishuSettingsView]
/// (embedded 隐藏页顶大标题,弹窗自画标题行)。
Future<void> openZishuSettingsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.tokens.barrier,
    builder: (_) => const _ZishuSettingsDialogFrame(),
  );
}

/// 设置弹窗外框:标题行(设置 + 关闭)+ 内嵌设置视图。
///
/// 任务D:高度不再钉死,`ConstrainedBox(maxHeight)` + `Column(mainAxisSize.min)
/// + Flexible` 让弹窗随展开内容自适应收缩(全收起时更矮),内容超出时内部滚动。
class _ZishuSettingsDialogFrame extends StatelessWidget {
  const _ZishuSettingsDialogFrame();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(viewport.width * 0.92, _kSettingsDialogWidth);
    final maxHeight = math.min(viewport.height * 0.88, _kSettingsDialogMaxHeight);
    return Dialog(
      key: const Key('zishu-settings-dialog'),
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.allLg),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Flexible(child: ZishuSettingsView(embedded: true)),
            ],
          ),
        ),
      ),
    );
  }
}
