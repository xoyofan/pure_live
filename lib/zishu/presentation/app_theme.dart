import 'package:flutter/material.dart';

import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/get/get.dart';

import 'design_tokens.dart';

import 'package:pure_live/common/services/settings/theme_settings_controller.dart';

import 'zishu_tokens.dart';

/// zishu 视觉基线注入:在 pure_live 既有 ThemeData 之上叠加 SFVideoLive
/// 深色基线(#181818 + 品牌紫 accent)的颜色体系与 `ZishuTokens` 扩展。
///
/// 结构沿用 zishu `app_theme.dart` 的 `_decorate`,去掉其 Riverpod 设置
/// 依赖与外置 token 热更(纯 live 的主题模式仍走自身 SettingsService):
/// 颜色真源即 `ZishuTokens.dark/light` 代码常量。
///
/// 主题色分层:默认保持 zishu 金色基线(`ZishuTokens` 常量原样生效);用户
/// 在设置页显式选过主题色后,该色接管 brand/accent/brandBright。此前
/// main.dart 喂给 MyTheme(colorSchemeSeed)的用户色会被下方 colorScheme
/// 覆盖回金,即「用户选色不生效」的断链点;现由 [_withUserThemeColor] 在
/// decorate 入口合流,见其注释。
abstract final class ZishuTheme {
  static ZishuTokens tokensFor(Brightness brightness) =>
      brightness == Brightness.dark ? ZishuTokens.dark : ZishuTokens.light;

  /// 用户显式选过主题色时,返回用户色接管 accent/brand/brandBright 后的
  /// tokens;否则原样返回(保持金/紫常量基线)。
  ///
  /// 「显式选过」的判定:`resolvedThemeColorHex != defaultThemeColorHex`
  /// (默认蓝 #2196F3 视为未选)。两个 getter 同走 normalizeThemeColor,均为
  /// 无 `#` 大写 hex(theme_settings_controller.dart 的 13/28/97 行),字符串
  /// 比较安全。SettingsService 未注册(极早期启动/测试)时直接放行基线。
  ///
  /// 对比度不做强制兜底:浅色主题 + 暗色(或暗色主题 + 亮色)用户色在
  /// onPrimary/onAccent 等位上的可读性风险由选色的用户自担。
  static ZishuTokens _withUserThemeColor(ZishuTokens tokens) {
    if (!Get.isRegistered<SettingsService>()) return tokens;
    final theme = SettingsService.to.theme;
    if (theme.resolvedThemeColorHex == ThemeSettingsController.defaultThemeColorHex) return tokens;
    final user = theme.themeColor;
    return tokens.copyWith(accent: user, brand: user, brandBright: _brighter(user));
  }

  /// 用户色提亮一档(当 [brandBright] 用):HSL lightness +0.12,clamp 到
  /// [0,1]——HSLColor.fromAHSL 对 lightness 有 assert,必须先收窄。
  static Color _brighter(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0).toDouble()).toColor();
  }

  static ThemeData decorate(ThemeData base) {
    final tokens = _withUserThemeColor(tokensFor(base.brightness));
    return base.copyWith(
      scaffoldBackgroundColor: tokens.background,
      // 控件强调色:未选色时对齐 pure_live web 线用户拍板的金色 accent
      // (#f3d04e,zishu exe 截图基线;zishu 代码后改紫霄紫,如需切换改回
      // tokens.accent);用户选过色时 primary/secondary 随用户主题色
      // (见 _withUserThemeColor)。
      colorScheme: base.colorScheme.copyWith(
        primary: tokens.brand,
        onPrimary: AppOnBright.text,
        secondary: tokens.brand,
        surface: tokens.surface,
        onSurface: tokens.textPrimary,
        surfaceContainerHighest: tokens.surfaceRaised,
        error: tokens.error,
        outline: tokens.border,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: AppControls.sliderTrackHeight,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppControls.sliderThumbRadius),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: AppControls.sliderThumbRadius + 3),
      ),
      dividerColor: tokens.border,
      textTheme: base.textTheme.apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: tokens.surfaceSoft),
      cardTheme: base.cardTheme.copyWith(color: tokens.surface, elevation: 0),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.surface,
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.allSm),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: tokens.surfaceSoft,
        indicatorColor: tokens.accent.withValues(alpha: 0.2),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(color: tokens.accent),
      extensions: [tokens],
    );
  }
}
