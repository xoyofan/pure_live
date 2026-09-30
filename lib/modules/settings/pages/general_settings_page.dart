import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/exit_settings_controller.dart';
import 'package:pure_live/common/services/settings/window_size_controller.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

class GeneralSettingsPage extends GetView<SettingsService> {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("general"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ZishuGroup(
                    title: i18n("general"),
                    children: [
                      if (Platform.isAndroid || Platform.isWindows)
                        Obx(() {
                          final info = DisplayModeService.info.value;
                          final mode = SettingsService.to.app.refreshRateMode;
                          final suffix = info == null
                              ? ''
                              : ' · ${info.currentRefreshRate.toStringAsFixed(0)} / ${info.maxRefreshRate.toStringAsFixed(0)} Hz';
                          return _ZishuRow(
                            icon: Remix.speed_up_line,
                            title: i18n('refresh_rate_mode'),
                            subtitle: '${_refreshRateModeLabel(mode)} · ${_refreshRateModeDescription(mode)}$suffix',
                            subtitleMaxLines: null,
                            onTap: () => _showRefreshRateModeDialog(context),
                          );
                        }),
                      if (Platform.isWindows)
                        Obx(() {
                          final info = DisplayModeService.info.value;
                          final mode = info == null
                              ? i18n('display_mode_detecting')
                              : '${info.width} × ${info.height} · '
                                    '${info.currentRefreshRate.toStringAsFixed(0)} Hz '
                                    '(${i18n('display_mode_max')} ${info.maxRefreshRate.toStringAsFixed(0)} Hz)';
                          return _ZishuRow(
                            icon: Remix.speed_up_line,
                            title: i18n('windows_dynamic_refresh_rate'),
                            subtitle: '${i18n('windows_dynamic_refresh_rate_subtitle')}\n$mode',
                            subtitleMaxLines: null,
                            onTap: () => DisplayModeService.refreshInfo(),
                          );
                        }),
                      if (Platform.isWindows)
                        _ZishuSwitchRow(
                          title: i18n('open_new_window'),
                          subtitle: i18n("open_new_window_subtitle"),
                          value: SettingsService.to.app.enableNewWindowPlay,
                          icon: Icons.add_to_photos_outlined,
                        ),
                      _ZishuSwitchRow(
                        title: i18n('splash_animation'),
                        subtitle: i18n("splash_animation_subtitle"),
                        value: SettingsService.to.app.showSplashPage,
                        icon: Remix.rocket_2_line,
                      ),
                      _ZishuSwitchRow(
                        title: i18n('enable_auto_check_update'),
                        value: SettingsService.to.app.enableAutoCheckUpdate,
                        icon: Remix.refresh_line,
                      ),
                      _ZishuSwitchRow(
                        title: i18n('use_github_origin_for_updates'),
                        subtitle: i18n('use_github_origin_for_updates_desc'),
                        value: SettingsService.to.app.useGitHubOriginForUpdates,
                        icon: Remix.github_line,
                        subtitleMaxLines: null,
                      ),
                      _ZishuSwitchRow(
                        title: i18n('enable_countdown_close'),
                        subtitle: i18n('enable_countdown_close_subtitle'),
                        value: SettingsService.to.exit.enableAutoShutDownTime,
                        icon: Remix.timer_line,
                      ),
                      Obx(() {
                        final bool isEnabled = SettingsService.to.exit.enableAutoShutDownTime.v;
                        final int configMinutes = SettingsService.to.exit.autoShutDownTime.v;

                        return StreamBuilder<int>(
                          key: ValueKey('${isEnabled}_$configMinutes'),
                          stream: SettingsService.to.exit.stopWatchTimer.rawTime,
                          builder: (context, snapshot) {
                            final int value = snapshot.data ?? 0;
                            String subtitleText = "";

                            if (!isEnabled || value == 0) {
                              subtitleText = "$configMinutes ${i18n('minutes')}";
                            } else {
                              final displayTime = StopWatchTimer.getDisplayTime(value, hours: true, milliSecond: false);
                              subtitleText = "${i18n('remaining_time')}: $displayTime";
                            }

                            return _ZishuRow(
                              iconWidget: AnimatedTimerIcon(
                                enabled: isEnabled,
                                remainingMs: value,
                                totalMinutes: configMinutes,
                              ),
                              title: i18n('countdown_duration'),
                              subtitle: subtitleText,
                              onTap: () => _showCountdownDurationDialog(context),
                            );
                          },
                        );
                      }),
                      if (Platform.isWindows) ...[
                        Obx(() {
                          final tokens = context.tokens;
                          final startup = SettingsService.to.startup;
                          final applying = startup.isApplyingStartup.v;
                          final statusKey = startup.startupStatusKey.v;
                          final subtitleKey = applying
                              ? 'startup_applying'
                              : statusKey.isNotEmpty
                              ? statusKey
                              : 'startup_subtitle';
                          return _ZishuRow(
                            key: const ValueKey('windows-startup-switch'),
                            icon: Remix.windows_line,
                            title: i18n('startup'),
                            subtitle: i18n(subtitleKey),
                            subtitleColor: statusKey.isNotEmpty && !applying ? tokens.error : null,
                            trailing: Switch(
                              value: startup.enableStartUp.v,
                              onChanged: applying ? null : (value) => unawaited(startup.setStartupEnabled(value)),
                            ),
                          );
                        }),
                        _ZishuRow(
                          icon: Remix.aspect_ratio_line,
                          title: i18n("window_size"),
                          subtitle:
                              "${SettingsService.to.window.resolvedStoredWidth.toInt()} × ${SettingsService.to.window.resolvedStoredHeight.toInt()}",
                          onTap: () => _showWindowSizeDialog(context),
                        ),
                        _ZishuSwitchRow(
                          title: i18n("no_exit_confirm"),
                          value: SettingsService.to.exit.dontAskExit,
                          icon: Remix.error_warning_line,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _refreshRateModeLabel(AppRefreshRateMode mode) {
    return switch (mode) {
      AppRefreshRateMode.powerSaving => i18n('refresh_rate_power_saving'),
      AppRefreshRateMode.balanced => i18n('refresh_rate_balanced'),
      AppRefreshRateMode.performance => i18n('refresh_rate_performance'),
    };
  }

  String _refreshRateModeDescription(AppRefreshRateMode mode) {
    return switch (mode) {
      AppRefreshRateMode.powerSaving => i18n('refresh_rate_power_saving_desc'),
      AppRefreshRateMode.balanced => i18n('refresh_rate_balanced_desc'),
      AppRefreshRateMode.performance => i18n('refresh_rate_performance_desc'),
    };
  }

  String _refreshRateEnergyLabel(AppRefreshRateMode mode) {
    return switch (mode) {
      AppRefreshRateMode.powerSaving => i18n('refresh_rate_energy_low'),
      AppRefreshRateMode.balanced => i18n('refresh_rate_energy_medium'),
      AppRefreshRateMode.performance => i18n('refresh_rate_energy_high'),
    };
  }

  void _showRefreshRateModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(i18n('refresh_rate_mode')),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: Text(i18n('refresh_rate_mode_hint'), style: Theme.of(dialogContext).textTheme.bodySmall),
              ),
              Obx(
                () => RadioGroup<AppRefreshRateMode>(
                  groupValue: SettingsService.to.app.refreshRateMode,
                  onChanged: (mode) {
                    if (mode == null) return;
                    SettingsService.to.app.setRefreshRateMode(mode);
                    Navigator.pop(dialogContext);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: AppRefreshRateMode.values
                        .map(
                          (mode) => RadioListTile<AppRefreshRateMode>(
                            value: mode,
                            title: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(_refreshRateModeLabel(mode)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(dialogContext).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _refreshRateEnergyLabel(mode),
                                    style: Theme.of(dialogContext).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(_refreshRateModeDescription(mode)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWindowSizeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _WindowSizeDialog(initialSize: SettingsService.to.window.storedSize),
    );
  }

  void _showCountdownDurationDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (context) => const _CountdownDurationDialog());
  }
}

/// zishu 分组卡片:surface + AppRadius.allMd + hairline tokens.border 描边,
/// elevation 0(无投影)。与 ZishuSettingsView 的 `_SettingsGroup` 同构,
/// 半径按本轨口径取 allMd。
class _ZishuGroup extends StatelessWidget {
  const _ZishuGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allMd,
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: context.textBody.copyWith(fontWeight: FontWeight.w700, color: tokens.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// zishu 设置行:图标块(36×36 surfaceRaised) + 标题 + 描述 + 右侧控件。
/// 有 [onTap] 的行 hover 用 surfaceRaised,涟漪/按压/焦点层取 accent
/// (AppStateLayer);无 onTap 的行(开关行)不包 InkWell。
class _ZishuRow extends StatelessWidget {
  const _ZishuRow({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 2,
    this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String title;

  /// 描述文案;null/空串不渲染该行。
  final String? subtitle;
  final Color? subtitleColor;

  /// 描述行数上限;传 null 表示不限(长描述不截断)。
  final int? subtitleMaxLines;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final Widget iconBlock = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
      child: Center(child: iconWidget ?? Icon(icon, size: 18, color: tokens.textSecondary)),
    );

    final Widget? right =
        trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, size: 18, color: tokens.textSecondary) : null);

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          iconBlock,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textBody.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: subtitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: context.textCaption.copyWith(color: subtitleColor),
                  ),
                ],
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: AppSpacing.lg), right],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: content,
    );
  }
}

/// zishu 开关行:行为与 `context.buildSwitchTile` 完全一致
/// (Obx 包裹 + `value.value = val` 自动提交 + 可选 onChanged 回调),
/// 仅替换行外观为 _ZishuRow + 裸 Switch。
class _ZishuSwitchRow extends StatelessWidget {
  const _ZishuSwitchRow({
    this.icon,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 2,
    // ignore: unused_element_parameter 保留对称 API:行组件家族统一可选参数
    this.subtitleColor,
    required this.value,
    // ignore: unused_element_parameter
    this.onChanged,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final int? subtitleMaxLines;
  final Color? subtitleColor;
  final RxBool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _ZishuRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        subtitleMaxLines: subtitleMaxLines,
        subtitleColor: subtitleColor,
        trailing: Switch(
          value: value.value,
          onChanged: (val) {
            value.value = val;
            onChanged?.call(val);
          },
        ),
      ),
    );
  }
}

class _WindowSizeDialog extends StatefulWidget {
  const _WindowSizeDialog({required this.initialSize});

  final Size initialSize;

  @override
  State<_WindowSizeDialog> createState() => _WindowSizeDialogState();
}

class _WindowSizeDialogState extends State<_WindowSizeDialog> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  String? _errorText;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController(text: widget.initialSize.width.toInt().toString());
    _heightController = TextEditingController(text: widget.initialSize.height.toInt().toString());
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText != null) setState(() => _errorText = null);
  }

  Future<void> _apply() async {
    final size = WindowSizeController.tryParseWindowSize(_widthController.text, _heightController.text);
    if (size == null) {
      setState(() => _errorText = i18n('window_size_out_of_range'));
      return;
    }
    setState(() {
      _errorText = null;
      _isApplying = true;
    });
    try {
      await windowManager.setSize(size, animate: true);
      await windowManager.center();
      SettingsService.to.window.saveWindowSize(size);
      SettingsService.to.window.setTracking(true);
      if (!mounted) return;
      Navigator.of(context).pop();
      ToastUtil.show(i18n('save_success'));
    } catch (error) {
      debugPrint('Failed to apply startup window size: $error');
      if (!mounted) return;
      setState(() {
        _errorText = i18n('window_size_apply_failed');
        _isApplying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = [
      ('1080 × 720 (${i18n("default_option")})', const Size(1080, 720)),
      ('1280 × 720 (720P)', const Size(1280, 720)),
      ('1600 × 900', const Size(1600, 900)),
      ('1920 × 1080 (1080P)', const Size(1920, 1080)),
      ('2560 × 1440 (2K)', const Size(2560, 1440)),
    ];
    return AlertDialog(
      scrollable: true,
      title: Text(i18n('window_size')),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i18n('preset_options'), style: AppTextStyles.t13.copyWith(color: theme.hintColor)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((preset) {
                return ActionChip(
                  label: Text(preset.$1),
                  onPressed: _isApplying
                      ? null
                      : () {
                          _widthController.text = preset.$2.width.toInt().toString();
                          _heightController.text = preset.$2.height.toInt().toString();
                          _clearError();
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(i18n('custom_input'), style: AppTextStyles.t13.copyWith(color: theme.hintColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDimensionField(_widthController, i18n('width'), '1080')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×', style: AppTextStyles.t18),
                ),
                Expanded(child: _buildDimensionField(_heightController, i18n('height'), '720')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorText ?? i18n('window_size_range_hint'),
              key: const ValueKey('window-size-feedback'),
              style: AppTextStyles.t12.copyWith(color: _errorText == null ? theme.hintColor : theme.colorScheme.error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isApplying ? null : () => Navigator.of(context).pop(), child: Text(i18n('cancel'))),
        TextButton(
          onPressed: _isApplying ? null : _apply,
          child: _isApplying
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(
                  i18n('confirm'),
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildDimensionField(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      enabled: !_isApplying,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class _CountdownDurationDialog extends StatefulWidget {
  const _CountdownDurationDialog();

  @override
  State<_CountdownDurationDialog> createState() => _CountdownDurationDialogState();
}

class _CountdownDurationDialogState extends State<_CountdownDurationDialog> {
  static const List<int> _minutesOptions = [15, 30, 45, 60, 90, 120, 180];
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    final currentValue = SettingsService.to.exit.autoShutDownTime.v;
    _inputController = TextEditingController(
      text: _minutesOptions.contains(currentValue) ? '' : currentValue.toString(),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(i18n('select_countdown_duration')),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        width: MediaQuery.sizeOf(context).width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i18n('app_exit_timer_explain'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Obx(() {
              final selectedValue = SettingsService.to.exit.autoShutDownTime.v;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _minutesOptions.map<Widget>((minutes) {
                  final isSelected = selectedValue == minutes;
                  return ChoiceChip(
                    label: Text("$minutes ${i18n('minutes')}"),
                    selected: isSelected,
                    selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (!selected) return;
                      SettingsService.to.exit.updateShutDownTime(minutes);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 20),
            TextField(
              controller: _inputController,
              keyboardType: TextInputType.number,
              style: AppTextStyles.t14,
              maxLines: 1,
              decoration: InputDecoration(
                labelText: i18n('custom_duration'),
                suffixText: i18n('minutes'),
                helperText: i18n('app_exit_timer_custom_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel'))),
        FilledButton(
          onPressed: () {
            final parsedValue = int.tryParse(_inputController.text.trim());
            if (parsedValue == null ||
                parsedValue < ExitSettingsController.minAutoShutdownMinutes ||
                parsedValue > ExitSettingsController.maxAutoShutdownMinutes) {
              ToastUtil.show(i18n('app_exit_timer_custom_hint'));
              return;
            }
            SettingsService.to.exit.updateShutDownTime(parsedValue);
            Navigator.of(context).pop();
          },
          child: Text(i18n('save')),
        ),
      ],
    );
  }
}

class AnimatedTimerIcon extends StatelessWidget {
  final bool enabled;
  final int remainingMs;
  final int totalMinutes;

  const AnimatedTimerIcon({super.key, required this.enabled, required this.remainingMs, required this.totalMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;

    double turns = 0.0;
    if (enabled && totalMinutes > 0 && remainingMs > 0) {
      final double totalMs = totalMinutes * 60 * 1000;
      final double passedMs = totalMs - remainingMs;
      turns = (passedMs / (60 * 1000)) * 60.0;
    }

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: iconColor, width: 2),
            ),
          ),
          RotationTransition(
            turns: AlwaysStoppedAnimation(turns),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 7,
                  decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(1)),
                ),
                const SizedBox(height: 7),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
