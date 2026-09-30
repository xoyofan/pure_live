// 聊天行徽章组件集(真源:zishu_flutter `side_panel/chat_badges.dart` 的通用子集)。
//
// 只搬「数据无源也能渲染」的通用分支,不含虎牙/斗鱼特化牌与图片徽章:
// - [ZishuChatFanBadge]:B 站 composed 渐变粉丝牌口径(名称 + 等级 +
//   渐变 start/end + 描边 border,尺寸取 `AppChatBadge.biliFan*`,
//   em=14 折算常量在 `lib/zishu/presentation/design_tokens.dart`);
// - [ZishuChatUserLevelBadge]:通用灰底数字盒(web `.chat-user-level`
//   基础类口径:高 `1.48em`、宽下限 `1.2em`、字号 `1em`、左右 `.22em`、圆角 0);
// - [zishuInlineBadge]:徽章内联进 Text.rich 段落的 WidgetSpan 包装。
//
// 颜色协议是十六进制字符串,由 [_parseBadgeHex] 宽容解析,失败回落
// `context.tokens.accent`(不臆造平台色)。

import 'package:flutter/material.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 宽容解析十六进制颜色字符串:`RRGGBB` / `AARRGGBB`,容许 `#`/`0x` 前缀;
/// 空串或格式非法返回 null(调用方用 accent 兜底)。
Color? _parseBadgeHex(String? raw) {
  var text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.startsWith('#')) text = text.substring(1);
  if (text.startsWith('0x') || text.startsWith('0X')) text = text.substring(2);
  if (text.length == 6) text = 'FF$text';
  if (text.length != 8) return null;
  final value = int.tryParse(text, radix: 16);
  return value == null ? null : Color(value);
}

/// 粉丝牌:B 站 composed 渐变口径(真源 `_FanBadge` 的 bilibili 分支,
/// chat_badges.dart:614-637)。
///
/// - 渐变 `to left`:start 色在右、end 色在左(web
///   `linear-gradient(to left, start, end)`);start/end 互补缺省
///   (start=colorStart||colorEnd),均缺失/解析失败用 accent 兜底;
/// - 描边色 [colorBorder] 解析失败就不画边(对齐真源 `colorBorder != 0`);
/// - 高 `1.48em`、最小宽 `3.5em`、左右 `.5em`、列间距 `.2em`、文字 `.9em`
///   均取 `AppChatBadge.biliFan*` / `fanFontSize`,字重 700,等级数字
///   tabular figures。
class ZishuChatFanBadge extends StatelessWidget {
  const ZishuChatFanBadge({
    super.key,
    required this.name,
    this.level,
    this.colorStart,
    this.colorEnd,
    this.colorBorder,
  });

  /// 粉丝牌团名(调用方保证非空白)。
  final String name;

  /// 粉丝牌等级(原始字符串;null/空白 = 不展示等级数字)。
  final String? level;

  /// 渐变起/止与描边色(十六进制,见 [_parseBadgeHex])。
  final String? colorStart;
  final String? colorEnd;
  final String? colorBorder;

  @override
  Widget build(BuildContext context) {
    final accent = context.tokens.accent;
    // 互补缺省对齐真源 bilibili 分支:start=colorStart||colorEnd。
    final start = _parseBadgeHex(colorStart) ?? _parseBadgeHex(colorEnd) ?? accent;
    final end = _parseBadgeHex(colorEnd) ?? _parseBadgeHex(colorStart) ?? accent;
    final borderColor = _parseBadgeHex(colorBorder);
    final levelText = level?.trim() ?? '';
    final hasLevel = levelText.isNotEmpty;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppChatBadge.fanFontSize,
              height: 1,
              color: AppOnBright.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (hasLevel) ...[
          const SizedBox(width: AppChatBadge.biliFanGap),
          Text(
            levelText,
            style: const TextStyle(
              fontSize: AppChatBadge.fanFontSize,
              height: 1,
              color: AppOnBright.white,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
    return Tooltip(
      message: hasLevel ? '${name.trim()} Lv.$levelText' : name.trim(),
      child: _BadgeBox(
        height: AppChatBadge.biliFanHeight,
        minWidth: AppChatBadge.biliFanMinWidth,
        radius: AppRadius.pill,
        padding: const EdgeInsets.symmetric(horizontal: AppChatBadge.biliFanPadX),
        gradient: [start, end],
        border: borderColor,
        // web `linear-gradient(to left, start, end)`:start 在右、end 在左。
        gradientBegin: Alignment.centerRight,
        gradientEnd: Alignment.centerLeft,
        child: content,
      ),
    );
  }
}

/// 通用用户等级牌:小数字盒(真源 `_UserLevelBadge` 的「其他平台」通用分支,
/// chat_badges.dart:1523-1572)。
///
/// web `.chat-user-level` 基础类口径:高 `1.48em`、`min-width: 1.2em`、
/// **圆角 0**(web 基础类就是 0,只有 bilibili/douyu 覆写成圆角)、文字
/// `1em` + 左右 `.22em` 内边距、灰底 `#6b7280` + 白字 700。
class ZishuChatUserLevelBadge extends StatelessWidget {
  const ZishuChatUserLevelBadge({super.key, required this.level});

  /// 等级文本(原始字符串,通常为数字)。
  final String level;

  @override
  Widget build(BuildContext context) {
    return _BadgeBox(
      height: AppChatBadge.levelHeight,
      minWidth: AppChatBadge.levelMinWidth,
      radius: 0,
      padding: const EdgeInsets.symmetric(horizontal: AppChatBadge.levelPadXWide),
      color: const Color(0xff6b7280),
      child: Text(
        level,
        style: const TextStyle(
          fontSize: AppChatBadge.levelFontSizeWide,
          height: 1,
          color: AppOnBright.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 徽章内联进 Text.rich 段落的 WidgetSpan(真源 `side_panel/chat_row.dart`
/// `_inlineBadge`):middle 对齐 + 行尾 2px 间距(web 徽章 margin-right
/// 0.14em,14px 基 ≈ 2px)。
///
/// 外层 `Row(mainAxisSize: min)` 还原无界宽约束 —— WidgetSpan 给的是有界宽,
/// 会把靠 `Container.alignment` 收缩的 [_BadgeBox] 拉满整行。
WidgetSpan zishuInlineBadge(Widget badge) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: Padding(
    padding: const EdgeInsets.only(right: 2),
    child: Row(mainAxisSize: MainAxisSize.min, children: [badge]),
  ),
);

/// 徽章底座:固定行高 + 渐变/纯色/描边 + 居中内容(真源 `_BadgeBox`
/// chat_badges.dart:1722-1775 原样移植)。
///
/// 渐变默认方向对齐 CSS `linear-gradient(90deg, A, B)`:colors[0] 在左;
/// B 站 `to left`(start 在右)由调用方显式传 [gradientBegin]/[gradientEnd] 覆写。
class _BadgeBox extends StatelessWidget {
  const _BadgeBox({
    required this.height,
    required this.child,
    this.minWidth = 0,
    this.radius = 999,
    this.gradient,
    this.color,
    this.border,
    this.gradientBegin = Alignment.centerLeft,
    this.gradientEnd = Alignment.centerRight,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
  });

  final double height;
  final double minWidth;
  final double radius;
  final List<Color>? gradient;
  final Color? color;
  final Color? border;
  final Alignment gradientBegin;
  final Alignment gradientEnd;

  /// 内容内边距。默认 4/1 是历史值;按 web 口径复刻时显式传入
  /// (如 B 站渐变牌 `.5em` = 7、用户等级文字 `.22em` = 3.08)。
  final EdgeInsetsGeometry padding;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      gradient: gradient == null ? null : LinearGradient(begin: gradientBegin, end: gradientEnd, colors: gradient!),
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border == null ? null : Border.all(color: border!, width: 1),
    );
    return Container(
      height: height,
      constraints: minWidth > 0 ? BoxConstraints(minWidth: minWidth) : null,
      padding: padding,
      alignment: Alignment.center,
      decoration: decoration,
      child: child,
    );
  }
}
