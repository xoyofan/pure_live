/// 设置页(U7):账号/外观/播放/弹幕四组设置,surface 卡片分组。
/// 主题/画质/弹幕变更即持久化。
///
/// 注:`SettingsState.serverUrl`(streaming-server 地址)字段与持久化仍保留
/// (Web 端后续接入),本轮只移除设置页上的录入 UI。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../shared/application/auth_provider.dart';
import '../../../shared/application/platform_prefs.dart';
import '../../../shared/presentation/design_tokens.dart';
import '../../../shared/presentation/platform_brands.dart';
import '../../../shared/presentation/widgets/platform_icon.dart';
import '../../../shared/presentation/zishu_tokens.dart';
import '../application/settings_provider.dart';
import '../widgets/follow_common.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key, this.embedded = false});

  static const Key mobileLoginKey = Key('mobile-login');

  /// 以对话框内嵌形态呈现:隐藏页顶的「设置」大标题(对话框自己画标题行),
  /// 其余分组与滚动行为不变。默认 false = 整页(/settings 深链)保持原样。
  final bool embedded;

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  /// 手机端没有顶栏头像,在设置页提供稳定的登录入口。
  /// 避免设置页被撑爆,也让既有用例的 `find.byType(DropdownButton<String>)`
  /// 仍只命中「全平台默认画质」一个控件。
  bool _platformQualityExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.embedded) ...[
                Text('设置', style: context.textTitle.copyWith(fontSize: AppFontSize.headline)),
                const SizedBox(height: AppSpacing.lg),
              ],
              _SettingsGroup(title: '账号', children: [_AccountSettingRow()]),
              _SettingsGroup(
                title: '外观',
                children: [
                  _SettingsRow(
                    label: '主题模式',
                    hint: '深色 / 浅色 / 跟随系统(顶栏主题按钮可快速切换深浅)',
                    trailing: _StyledDropdown<ThemeModeChoice>(
                      value: settings.themeMode,
                      items: [for (final mode in ThemeModeChoice.values) (value: mode, label: mode.label)],
                      onChanged: (mode) => ref.read(settingsProvider.notifier).setThemeMode(mode),
                    ),
                  ),
                ],
              ),
              _PlatformSettingsGroup(),
              _SettingsGroup(
                title: '播放',
                children: [
                  _SettingsRow(
                    label: '全平台默认画质',
                    hint: '各平台未单独配置时使用的画质',
                    trailing: _StyledDropdown<String>(
                      value: settings.defaultQuality,
                      items: [for (final quality in SettingsState.qualityOptions) (value: quality, label: quality)],
                      onChanged: (quality) => ref.read(settingsProvider.notifier).setDefaultQuality(quality),
                    ),
                  ),
                  _SettingsRow(
                    label: '视频硬件解码',
                    hint: '关闭后使用软件解码，用于排查黑屏和画面闪烁',
                    trailing: Switch(
                      key: const Key('settings-hwdec-toggle'),
                      value: settings.videoHardwareAcceleration,
                      onChanged: (value) => ref.read(settingsProvider.notifier).setVideoHardwareAcceleration(value),
                      overlayColor: controlStateLayer(tokens),
                    ),
                  ),
                  _SettingsRow(
                    label: '按平台配置默认画质',
                    hint: _platformQualityExpanded ? '点此收起' : '为单个平台指定不同默认档',
                    trailing: IconButton(
                      key: const Key('settings-toggle-platform-quality'),
                      tooltip: _platformQualityExpanded ? '收起平台画质配置' : '展开平台画质配置',
                      onPressed: () => setState(() => _platformQualityExpanded = !_platformQualityExpanded),
                      // 状态层走 token:hover 抬亮;键盘焦点/按压用 accent 低 alpha。
                      style: IconButton.styleFrom(
                        hoverColor: tokens.surfaceRaised,
                        highlightColor: AppStateLayer.pressedOf(tokens.accent),
                        focusColor: AppStateLayer.focusOf(tokens.accent),
                      ),
                      icon: Icon(
                        _platformQualityExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 18,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  // 折叠时不构建平台下拉:一是页面不至于被 11 行撑爆,二是让
                  // 既有用例的 `find.byType(DropdownButton<String>)` 仍只命中
                  // 「全平台默认画质」一个控件(见 settings_test)。
                  if (_platformQualityExpanded)
                    for (final brand in PlatformBrandCatalog.navigationPlatforms)
                      if (brand.id != 'all')
                        _SettingsRow(
                          label: brand.name,
                          hint: settings.defaultQualityBySite[brand.id] == null
                              ? '未单独配置,默认「${SettingsState.platformDefaultQuality[brand.id] ?? settings.defaultQuality}」'
                              : null,
                          trailing: _StyledDropdown<String>(
                            // 测试锚点:按平台寻址(settings-quality-{site})。
                            key: Key('settings-quality-${brand.id}'),
                            // 哨兵空串 = 「跟随全平台」;其余值为平台单独配置。
                            value: settings.defaultQualityBySite[brand.id] ?? '',
                            items: [
                              const (value: '', label: '跟随平台默认'),
                              for (final quality in SettingsState.qualityOptionsForSite(brand.id))
                                (value: quality, label: quality),
                            ],
                            onChanged: (quality) => ref
                                .read(settingsProvider.notifier)
                                .setDefaultQualityForSite(brand.id, quality.isEmpty ? null : quality),
                          ),
                        ),
                ],
              ),
              _SettingsGroup(
                title: '弹幕',
                children: [
                  _SettingsRow(
                    label: '弹幕显示',
                    hint: '播放时在画面上方叠加弹幕',
                    trailing: Switch(
                      key: const Key('settings-danmaku-toggle'),
                      value: settings.danmakuEnabled,
                      onChanged: (value) => ref.read(settingsProvider.notifier).setDanmakuEnabled(value),
                      // hover/焦点/按压状态层走 token(默认是 ThemeData 白 4%/12%)。
                      overlayColor: controlStateLayer(tokens),
                    ),
                  ),
                ],
              ),
              _SettingsGroup(
                title: '翻译',
                children: [
                  _SettingsRow(
                    label: '翻译为中文',
                    hint:
                        '首页/播放页标题与弹幕自动译为中文;走公共翻译服务,'
                        '失败或已是中文时显示原文',
                    trailing: Switch(
                      key: const Key('settings-translation-toggle'),
                      value: settings.translationEnabled,
                      onChanged: (value) => ref.read(settingsProvider.notifier).setTranslationEnabled(value),
                      // hover/焦点/按压状态层走 token(默认是 ThemeData 白 4%/12%)。
                      overlayColor: controlStateLayer(tokens),
                    ),
                  ),
                  _TranslationEndpointRow(
                    endpoint: settings.translationEndpoint,
                    enabled: settings.translationEnabled,
                    onSave: (url) => ref.read(settingsProvider.notifier).setTranslationEndpoint(url),
                  ),
                ],
              ),
              _SettingsGroup(
                title: '工具',
                children: [
                  // `/time` 对齐 web 语义是「解析耗时基准页」(冷解析 vs 缓存命中),
                  // 顶/底栏无入口,统一从这里进(web 同样是直接输 URL 访问)。
                  _SettingsRow(
                    label: '解析耗时基准',
                    hint: '冷解析与缓存命中墙钟对比(等价 web /time)',
                    trailing: TextButton(
                      key: const Key('settings-parse-benchmark'),
                      onPressed: () => context.push('/time'),
                      child: const Text('打开'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// surface 卡片分组容器。
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

/// 「平台」分区:横向平铺 chip,按住拖拽排序,chip 上的眼睛开关控制可见。
/// 可见平台按用户拖拽次序展示(顶栏/侧栏/首页同步),隐藏平台垫后灰化。
class _PlatformSettingsGroup extends ConsumerStatefulWidget {
  const _PlatformSettingsGroup();

  @override
  ConsumerState<_PlatformSettingsGroup> createState() => _PlatformSettingsGroupState();
}

class _PlatformSettingsGroupState extends ConsumerState<_PlatformSettingsGroup> {
  /// 当前拖拽中的平台 id(null = 没有拖拽)。
  String? _draggingId;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(platformCatalogProvider);
    final visible = ref.watch(visiblePlatformsProvider);
    final visibleIds = {for (final entry in visible) entry.id};
    final hidden = [
      for (final entry in catalog)
        if (!visibleIds.contains(entry.id)) entry,
    ];

    void reorder(String draggedId, String targetId) {
      if (draggedId == targetId) return;
      final ids = [for (final entry in visible) entry.id];
      final from = ids.indexOf(draggedId);
      final to = ids.indexOf(targetId);
      if (from < 0 || to < 0) return;
      ids.removeAt(from);
      ids.insert(to, draggedId);
      unawaited(ref.read(platformPrefsProvider.notifier).reorder(ids));
    }

    return _SettingsGroup(
      title: '平台',
      children: [
        Text('按住图标拖拽排序;点眼睛切换可见。关闭的平台从顶栏与侧栏隐藏。', style: context.textSecondary),
        const SizedBox(height: AppSpacing.sm),
        // ── 可见平台:横向平铺,按住拖拽排序 ──
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final entry in visible)
              _PlatformDragChip(
                key: ValueKey('platform-chip-${entry.id}'),
                entry: entry,
                visible: true,
                isDragging: _draggingId == entry.id,
                onDragStart: () => setState(() => _draggingId = entry.id),
                onDragEnd: () => setState(() => _draggingId = null),
                onAccept: (dragged) => reorder(dragged, entry.id),
                onToggle: () => ref.read(platformPrefsProvider.notifier).setVisibility(entry.id, false),
              ),
          ],
        ),
        // ── 隐藏平台 ──
        if (hidden.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('已隐藏', style: context.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final entry in hidden)
                _PlatformDragChip(
                  key: ValueKey('platform-hidden-${entry.id}'),
                  entry: entry,
                  visible: false,
                  isDragging: false,
                  onToggle: () => ref.read(platformPrefsProvider.notifier).setVisibility(entry.id, true),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 单个平台 chip:图标 + 名称 + 眼睛开关,按住拖拽排序。
class _PlatformDragChip extends StatelessWidget {
  const _PlatformDragChip({
    super.key,
    required this.entry,
    required this.visible,
    this.isDragging = false,
    this.onDragStart,
    this.onDragEnd,
    this.onAccept,
    this.onToggle,
  });

  final PlatformEntry entry;
  final bool visible;
  final bool isDragging;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final ValueChanged<String>? onAccept;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != entry.id,
      onAcceptWithDetails: (details) => onAccept?.call(details.data),
      builder: (context, candidate, rejected) {
        return LongPressDraggable<String>(
          // 250ms:默认 500ms(即"0.5 秒长按")用户反馈偏慢;再短易与滚动
          // 误触(慢速滑动页面时误入拖拽态)。
          delay: const Duration(milliseconds: 250),
          data: entry.id,
          onDragStarted: onDragStart,
          onDragEnd: (_) => onDragEnd?.call(),
          feedback: _chipContent(tokens, dragging: true),
          childWhenDragging: Opacity(opacity: 0.35, child: _chipContent(tokens)),
          child: Opacity(opacity: isDragging ? 0.35 : 1, child: _chipContent(tokens)),
        );
      },
    );
  }

  Widget _chipContent(ZishuTokens tokens, {bool dragging = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: visible ? tokens.accent : tokens.border),
        borderRadius: AppRadius.allSm,
        color: visible ? tokens.accent.withValues(alpha: 0.12) : tokens.surfaceRaised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlatformRowLogo(entry: entry, size: 18),
          const SizedBox(width: 6),
          Text(
            entry.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: visible ? FontWeight.w600 : FontWeight.w400,
              color: visible ? tokens.textPrimary : tokens.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 16,
              color: visible ? tokens.accent : tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 平台行 logo:与顶栏/侧栏同口径(pure_live 素材直读,缺失退 [PlatformIcon])。
class _PlatformRowLogo extends StatelessWidget {
  const _PlatformRowLogo({required this.entry, required this.size});

  final PlatformEntry entry;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      entry.logo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => PlatformIcon(id: entry.id, size: size),
    );
  }
}

/// 账号状态行:移动端没有顶栏头像时提供登录/退出入口。
class _AccountSettingRow extends ConsumerWidget {
  const _AccountSettingRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final authenticated = auth.phase == AuthPhase.authenticated;
    final label = authenticated
        ? (auth.session?.username ?? '已登录')
        : auth.phase == AuthPhase.restoring
        ? '恢复中…'
        : '未登录';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: context.tokens.accent,
        child: Icon(
          authenticated ? Icons.person_rounded : Icons.person_outline_rounded,
          color: AppOnBright.white,
          size: 18,
        ),
      ),
      title: Text(label, style: context.textBody),
      subtitle: Text(authenticated ? '登录状态已恢复，可同步我的关注' : '登录后同步我的关注', style: context.textSecondary),
      trailing: authenticated
          ? TextButton(
              key: SettingsView.mobileLoginKey,
              onPressed: () => ref.read(authProvider.notifier).logout(),
              child: const Text('退出登录'),
            )
          : FilledButton(
              key: SettingsView.mobileLoginKey,
              onPressed: auth.phase == AuthPhase.restoring
                  ? null
                  : () => showDialog<void>(context: context, builder: (_) => const LoginDialog()),
              child: const Text('登录'),
            ),
    );
  }
}

/// 一行设置:左标签/说明,右侧控件。
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.trailing, this.hint});

  final String label;
  final Widget trailing;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textBody.copyWith(fontWeight: FontWeight.w600)),
                if (hint != null) ...[const SizedBox(height: 2), Text(hint!, style: context.textSecondary)],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          trailing,
        ],
      ),
    );
  }
}

/// 统一样式的下拉选择(surface 底 + border 描边)。
class _StyledDropdown<T> extends StatelessWidget {
  const _StyledDropdown({super.key, required this.value, required this.items, required this.onChanged});

  final T value;
  final List<({T value, String label})> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: AppRadius.allSm,
        border: Border.all(color: tokens.border),
      ),
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: tokens.surfaceRaised,
        icon: Icon(Icons.expand_more_rounded, size: 16, color: tokens.textSecondary),
        style: context.textBody,
        items: [for (final item in items) DropdownMenuItem(value: item.value, child: Text(item.label))],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

/// 自定义翻译实例地址行:提交即保存;留空提交 = 回到内置公共实例。
///
/// 外部值变化(恢复持久化/他处保存)且输入框未聚焦时回填,避免打断输入。
class _TranslationEndpointRow extends ConsumerStatefulWidget {
  const _TranslationEndpointRow({required this.endpoint, required this.enabled, required this.onSave});

  final String endpoint;
  final bool enabled;
  final ValueChanged<String> onSave;

  @override
  ConsumerState<_TranslationEndpointRow> createState() => _TranslationEndpointRowState();
}

class _TranslationEndpointRowState extends ConsumerState<_TranslationEndpointRow> {
  late final TextEditingController _controller = TextEditingController(text: widget.endpoint);
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _TranslationEndpointRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endpoint != oldWidget.endpoint && widget.endpoint != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.endpoint;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    _focus.unfocus();
    widget.onSave(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _SettingsRow(
      label: '自定义翻译服务',
      hint: '可填自建 Lingva / SimplyTranslate 实例地址,留空用内置公共实例',
      trailing: SizedBox(
        width: 240,
        child: TextField(
          key: const Key('settings-translation-endpoint'),
          controller: _controller,
          focusNode: _focus,
          enabled: widget.enabled,
          onSubmitted: (_) => _commit(),
          onTapOutside: (_) => _commit(),
          style: context.textBody,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'https://…',
            hintStyle: context.textSecondary,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            filled: true,
            fillColor: tokens.surfaceRaised,
            border: OutlineInputBorder(
              borderRadius: AppRadius.allSm,
              borderSide: BorderSide(color: tokens.border),
            ),
            // 键盘焦点可见:描边转 accent(与搜索页输入框同法,不新增色值)。
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.allSm,
              borderSide: BorderSide(color: tokens.accent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.allSm,
              borderSide: BorderSide(color: tokens.border),
            ),
            suffixIcon: IconButton(
              key: const Key('settings-translation-endpoint-save'),
              tooltip: '保存',
              onPressed: _commit,
              icon: Icon(Icons.check_rounded, size: 16, color: tokens.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// 打开设置对话框(顶栏 / 底栏「我的」入口共用)。
///
/// 用户口径(2026-09-23):设置点击弹对话框而非跳整页;/settings 整页路由
/// 保留(深链与既有整页测试仍可用)。样式语言对齐 search_dialog 的对话框
/// (surface 底、allLg 圆角、视口收敛)。
Future<void> openSettingsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.tokens.barrier,
    builder: (_) => const _SettingsDialogFrame(),
  );
}

/// 设置对话框宽度/高度上限(对齐 search_dialog 的常量写法,math.min 需 double)。
const double _kSettingsDialogWidth = 760;
const double _kSettingsDialogMaxHeight = 840;

/// 设置对话框容器:标题行 + 关闭按钮 + 内嵌 [SettingsView](隐藏其页顶大标题)。
class _SettingsDialogFrame extends StatelessWidget {
  const _SettingsDialogFrame();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(viewport.width * 0.92, _kSettingsDialogWidth);
    final height = math.min(viewport.height * 0.82, _kSettingsDialogMaxHeight);
    return Dialog(
      key: const Key('settings-dialog'),
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
                    '设置',
                    style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle, color: tokens.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('settings-dialog-close'),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    iconSize: 18,
                    color: tokens.textSecondary,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Expanded(child: SettingsView(embedded: true)),
          ],
        ),
      ),
    );
  }
}
