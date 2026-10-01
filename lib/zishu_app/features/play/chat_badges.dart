// 聊天行徽章组件集(真源:zishu_flutter `side_panel/chat_badges.dart` 的
// 文字态子集)。图片徽章管线(真源 ChatBadgeImage/官方 CDN 图)不迁 ——
// LiveMessage 无徽章图 URL 字段,斗鱼/虎牙/抖音按真源同名分支的
// 「文字态/兜底态」规格渲染,几何数值逐项对齐。
//
// 各站协议字段 → LiveMessage 映射(引擎侧已填,渲染侧只消费):
// - 斗鱼 chatmsg:`bnn`/`bn`→badgeName,`bl`(兜底 `bnnl`/`fl`)→badgeLevel,
//   `bc` packed RGB→badgeColor 三色同值(协议单色),`level`/`lv`→userLevel;
// - 虎牙 Tars 1400 `tDeco`:appId 10400 BadgeInfo{sBadgeName@3,iBadgeLevel@4}
//   →badgeName/badgeLevel,11200{iLevel@1}→userLevel;协议无徽章色值 →
//   粉丝牌底色走 AppHuyaChatBadge.fanGradient 等级 7 档、等级牌走官方图
//   失败态兜底胶囊;
// - 抖音 User.BadgeImageList 里 URL 含 'fansclub' 的官方图:描述子 #4 名称
//   →badgeName、#3 等级(缺省回落 URL `badge_(\d+)`)→badgeLevel;payGrade
//   不在裁剪 proto → userLevel 恒空;协议无色值(img-only 站)→ 粉丝牌
//   红渐变圆盘兜底;
// - B 站新老协议(渐变三色/描边)已有实现不动(默认分支)。
//
// 组件:
// - [ZishuChatFanBadge]:分站粉丝牌(斗鱼 bc 底色牌 / 虎牙 7 档渐变胶囊 +
//   等级圆盘 / 抖音红渐变圆盘 / B 站 composed 渐变牌);
// - [ZishuChatUserLevelBadge]:分站等级牌(斗鱼 LV 梯度胶囊 / 虎牙官方图
//   失败态兜底胶囊 / 其余通用灰底数字盒);
// - [zishuFanBadgeVisible]:行内粉丝牌显隐闸门(缺字段不渲染,现口径);
// - [zishuInlineBadge]:徽章内联进 Text.rich 段落的 WidgetSpan 包装。
//
// 颜色协议是十六进制字符串,由 [_parseBadgeHex] 宽容解析,失败回落
// `context.tokens.accent`(不臆造平台色)。

import 'package:flutter/material.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 等级梯度色表(真源 chat_badges.dart `_kTierGradients` 逐字移植;
/// 对齐 web badgeHelpers.ts LEVEL_TIER_GRADIENTS,90deg)。
const _kTierGradients = <List<Color>>[
  [Color(0xffdc2626), Color(0xfff97316)], // ≥最高档
  [Color(0xffea580c), Color(0xfffbbf24)],
  [Color(0xff7c3aed), Color(0xffa855f7)],
  [Color(0xff2563eb), Color(0xff3b82f6)],
  [Color(0xff059669), Color(0xff10b981)],
];
const _kTierFallback = <Color>[Color(0xff6b7280), Color(0xff9ca3af)];

/// level → 梯度档(真源 `_levelTier` 逐字移植;thresholds 从高到低,
/// 如斗鱼 [50,40,30,20,10])。
List<Color> _levelTier(int level, List<int> thresholds) {
  for (var i = 0; i < thresholds.length; i += 1) {
    if (level >= thresholds[i]) return _kTierGradients[i];
  }
  return _kTierFallback;
}

/// 虎牙消费等级官方图高(真源解析包 `kHuyaConsumeLevelBadgeHeight`;
/// 本仓库无该解析包 → 文件内落常量)。
const double _kHuyaConsumeLevelBadgeHeight = 20;

/// 抖音粉丝牌文字态圆盘边长(真源 douyin 兜底分支原值 19.6)。
const double _kDouyinFanDiscSize = 19.6;

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

/// 行内粉丝牌显隐闸门(真源 `_FanBadge.visibleFor` 的文字态等价,
/// chat_badges.dart:163-164):
/// - 通用口径(现行为):团名空白 → 不渲染;
/// - 抖音:圆盘只承载等级数字(img-only 站,团名不入盘)→ 等级也必须
///   非空,否则会渲染出一个空红圆。
bool zishuFanBadgeVisible({required String site, String? name, String? level}) {
  if (name?.trim().isNotEmpty != true) return false;
  if (site == 'douyin' && level?.trim().isNotEmpty != true) return false;
  return true;
}

/// 粉丝牌:分站渲染(真源 `_FanBadge` 各分支的文字态/兜底态)。
///
/// - 斗鱼:官方粉丝牌是「等级桶背景图 + 房间前缀图 + 等级数字 + 团名」
///   组合样式(真源 `_DouyuFanMedal`,66×19),图片层不迁 → 协议色 bc
///   (start/end 同值,十六进制宽容解析,失败回 accent)作底色的文字近似:
///   高 19、最小宽 66、「等级(12/w700 tabular)→ 团名(12/w600)」排布
///   同组合样式;
/// - 虎牙:web `.chat-fan-badge--huya-composed` 自绘口径(真源取不到官方
///   底图时的同构实现,chat_badges.dart:469-518):高 `1.15em`、最小宽
///   `3.4em`、圆角 2px、左 `.14em`/右 `.28em`、底色 `fanGradient(level)`
///   7 档渐变,内容 = 黑 22% 圆形等级徽记(直径 `1.05×.67em`,数字
///   `.67em`/w800)+ 团名(`.79em`/w700,最宽 64);协议无徽章色值,
///   badgeColor 三色不参与本站;
/// - 抖音:img-only 站(真源 chat_badges.dart:313-353),协议只给官方图;
///   图片管线不迁 → 真源「图失败兜底」同款红渐变圆盘:19.6 圆、90deg
///   `[fe2c55, ff6b35]`、等级数字 caption/w800(团名不入盘,对齐官方
///   紧凑款只含数字);
/// - B 站(默认):composed 渐变牌,已有实现不动。
class ZishuChatFanBadge extends StatelessWidget {
  const ZishuChatFanBadge({
    super.key,
    this.site = '',
    required this.name,
    this.level,
    this.colorStart,
    this.colorEnd,
    this.colorBorder,
  });

  /// 站点 id(LiveRoom.platform,真源 `site` 同名分档依据)。
  ///
  /// 缺省空串 = 老调用点(未带站点的旧弹幕列表)保持 B 站 composed 通用渲染。
  final String site;

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
    if (site == 'douyin') {
      final levelText = level?.trim() ?? '';
      // 真源兜底圆盘原样:19.6 圆 + 红渐变(90deg,colors[0] 在左)+
      // 数字 caption/h1.1/w800。
      return Tooltip(
        message: levelText.isNotEmpty ? '${name.trim()} Lv.$levelText' : name.trim(),
        child: _BadgeBox(
          height: _kDouyinFanDiscSize,
          minWidth: _kDouyinFanDiscSize,
          radius: 999,
          gradient: const [Color(0xfffe2c55), Color(0xffff6b35)],
          child: Text(
            levelText,
            style: const TextStyle(
              fontSize: AppFontSize.caption,
              height: 1.1,
              color: AppOnBright.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    if (site == 'huya') {
      final levelText = level?.trim() ?? '';
      final hasLevel = levelText.isNotEmpty;
      // 底色分档:≤4 / 5–13 / 14–17 / 18–20 / 21–22 / 23–27 / ≥28
      // (AppHuyaChatBadge.fanGradient);等级非数字时按 0 档(≤4)。
      final levelValue = int.tryParse(levelText) ?? 0;
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLevel) _HuyaFanLevelDisc(level: levelText),
          // web `.chat-fan-badge__level-disc { margin: 0 .14em 0 0 }`
          // (按徽记自身字号 .67em 折算 = 1.31)。
          if (hasLevel) const SizedBox(width: AppHuyaChatBadge.fanDiscGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 64),
            child: Text(
              name.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                // web `.chat-fan-badge__name--huya { font-size: .79em;
                // font-weight: 700 }`。
                fontSize: AppHuyaChatBadge.fanNameFontSize,
                height: 1,
                color: AppOnBright.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
      return Tooltip(
        message: hasLevel ? '${name.trim()} Lv.$levelText' : name.trim(),
        child: _BadgeBox(
          height: AppHuyaChatBadge.fanHeight,
          minWidth: AppHuyaChatBadge.fanMinWidth,
          // web `.chat-fan-badge--huya { border-radius: 2px }`:不是胶囊。
          radius: AppHuyaChatBadge.fanRadius,
          gradient: AppHuyaChatBadge.fanGradient(levelValue),
          padding: const EdgeInsets.only(left: AppHuyaChatBadge.fanPadLeft, right: AppHuyaChatBadge.fanPadRight),
          // 真源自绘分支 alignment: centerLeft(等级徽记贴左区)。
          alignment: Alignment.centerLeft,
          child: content,
        ),
      );
    }
    if (site == 'douyu') {
      final accent = context.tokens.accent;
      // 互补缺省对齐真源 bilibili 分支:start=colorStart||colorEnd。
      // 斗鱼协议单色(start=end=border=bc)→ 实际渲染为平涂底 + 同色描边。
      final start = _parseBadgeHex(colorStart) ?? _parseBadgeHex(colorEnd) ?? accent;
      final end = _parseBadgeHex(colorEnd) ?? _parseBadgeHex(colorStart) ?? accent;
      final borderColor = _parseBadgeHex(colorBorder);
      final levelText = level?.trim() ?? '';
      final hasLevel = levelText.isNotEmpty;
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasLevel)
            Text(
              levelText,
              style: const TextStyle(
                fontSize: AppDouyuChatBadge.medalLevelFontSize,
                height: 1,
                color: AppOnBright.white,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          if (hasLevel) const SizedBox(width: AppChatBadge.fanGap),
          Flexible(
            child: Text(
              name.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppDouyuChatBadge.medalNameFontSize,
                height: 1,
                color: AppOnBright.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
      return Tooltip(
        message: hasLevel ? '${name.trim()} Lv.$levelText' : name.trim(),
        child: _BadgeBox(
          height: AppDouyuChatBadge.medalHeight,
          minWidth: AppDouyuChatBadge.medalWidth,
          radius: AppRadius.pill,
          gradient: [start, end],
          border: borderColor,
          child: content,
        ),
      );
    }
    // B 站(默认):B 站 composed 渐变口径(真源 `_FanBadge` 的 bilibili
    // 分支,chat_badges.dart:614-637)。
    //
    // - 渐变 `to left`:start 色在右、end 色在左(web
    //   `linear-gradient(to left, start, end)`);start/end 互补缺省
    //   (start=colorStart||colorEnd),均缺失/解析失败用 accent 兜底;
    // - 描边色 [colorBorder] 解析失败就不画边(对齐真源 `colorBorder != 0`);
    // - 高 `1.48em`、最小宽 `3.5em`、左右 `.5em`、列间距 `.2em`、文字 `.9em`
    //   均取 `AppChatBadge.biliFan*` / `fanFontSize`,字重 700,等级数字
    //   tabular figures。
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

/// 用户等级牌:分站渲染(真源 `_UserLevelBadge` 各分支的文字态/兜底态)。
///
/// - 斗鱼:web 口径 `.chat-user-level--douyu` —— `LV{level}` 渐变文字胶囊
///   (真源 chat_badges.dart:1427-1454):高 `1.15em`、圆角 2px、字号
///   `.64em`、左右内边距 `.26em`,渐变取 tier 表 thresholds
///   [50,40,30,20,10](等级非数字回落灰档);
/// - 虎牙:官方 `consumeLevelBadgeV2` CDN 图(数字叠右下角)不迁 → 真源
///   「图加载失败」同款兜底胶囊(chat_badges.dart:1343-1364):高 20(解析
///   包 `kHuyaConsumeLevelBadgeHeight`)、宽下限 32(裁剪后口径)、pill、
///   surfaceRaised 底、白字 700;
/// - 抖音:userLevel 恒空(见文件头映射),行级闸门不会进到这里,保持
///   通用盒防呆;
/// - 其他(含 B 站):通用灰底数字盒(真源 `_UserLevelBadge` 的「其他平台」
///   通用分支,chat_badges.dart:1523-1572)。web `.chat-user-level` 基础类
///   口径:高 `1.48em`、`min-width: 1.2em`、**圆角 0**(web 基础类就是 0,
///   只有 bilibili/douyu 覆写成圆角)、文字 `1em` + 左右 `.22em` 内边距、
///   灰底 `#6b7280` + 白字 700。
class ZishuChatUserLevelBadge extends StatelessWidget {
  const ZishuChatUserLevelBadge({super.key, this.site = '', required this.level});

  /// 站点 id(LiveRoom.platform)。缺省空串 = 老调用点保持通用灰底数字盒。
  final String site;

  /// 等级文本(原始字符串,通常为数字)。
  final String level;

  @override
  Widget build(BuildContext context) {
    if (site == 'douyu') {
      return _BadgeBox(
        height: AppDouyuChatBadge.levelHeight,
        radius: AppDouyuChatBadge.levelRadius,
        padding: const EdgeInsets.symmetric(horizontal: AppChatBadge.levelPadX),
        // thresholds 从高到低(真源同款);非数字等级 → -1 落灰档。
        gradient: _levelTier(int.tryParse(level.trim()) ?? -1, const [50, 40, 30, 20, 10]),
        child: Text(
          'LV$level',
          style: const TextStyle(
            fontSize: AppChatBadge.levelFontSize,
            height: 1,
            color: AppOnBright.white,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      );
    }
    if (site == 'huya') {
      return _BadgeBox(
        height: _kHuyaConsumeLevelBadgeHeight,
        minWidth: AppHuyaChatBadge.levelWidthCropped,
        radius: AppRadius.pill,
        color: context.tokens.surfaceRaised,
        child: Text(
          level,
          style: const TextStyle(
            fontSize: AppFontSize.bodySecondary,
            height: 1.1,
            color: AppOnBright.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
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

/// 虎牙粉丝牌胶囊左侧的圆形等级徽记(真源 `_HuyaFanLevelDisc`,
/// chat_badges.dart:1582-1608):直径 `1.05×.67em`、底色 `rgba(0,0,0,.22)`
/// (AppHuyaChatBadge.fanLevelDiscBg)、数字 `.67em`/w800。
class _HuyaFanLevelDisc extends StatelessWidget {
  const _HuyaFanLevelDisc({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppHuyaChatBadge.fanLevelDisc,
      height: AppHuyaChatBadge.fanLevelDisc,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppHuyaChatBadge.fanLevelDiscBg, shape: BoxShape.circle),
      child: Text(
        level,
        style: const TextStyle(
          fontSize: AppHuyaChatBadge.fanLevelDiscFontSize,
          height: 1,
          color: AppOnBright.white,
          fontWeight: FontWeight.w800,
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
/// chat_badges.dart:1722-1775 原样移植,另加 [alignment] 覆写位 ——
/// 虎牙自绘分支真源用 centerLeft)。
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
    this.alignment = Alignment.center,
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

  /// 内容对齐(默认居中;虎牙自绘分支传 centerLeft 对齐真源)。
  final Alignment alignment;

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
      alignment: alignment,
      decoration: decoration,
      child: child,
    );
  }
}
