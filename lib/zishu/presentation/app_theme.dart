import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'zishu_tokens.dart';

/// zishu 视觉基线注入:在 pure_live 既有 ThemeData 之上叠加 SFVideoLive
/// 深色基线(#181818 + 品牌紫 accent)的颜色体系与 `ZishuTokens` 扩展。
///
/// 结构沿用 zishu `app_theme.dart` 的 `_decorate`,去掉其 Riverpod 设置
/// 依赖与外置 token 热更(纯 live 的主题模式仍走自身 SettingsService):
/// 颜色真源即 `ZishuTokens.dark/light` 代码常量。
abstract final class ZishuTheme {
  static ZishuTokens tokensFor(Brightness brightness) =>
      brightness == Brightness.dark ? ZishuTokens.dark : ZishuTokens.light;

  static ThemeData decorate(ThemeData base) {
    final tokens = tokensFor(base.brightness);
    return base.copyWith(
      scaffoldBackgroundColor: tokens.background,
      // 控件强调色:对齐 pure_live web 线用户拍板的金色 accent(#f3d04e,
      // zishu exe 截图基线;zishu 代码后改紫霄紫,如需切换改回 tokens.accent)。
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
