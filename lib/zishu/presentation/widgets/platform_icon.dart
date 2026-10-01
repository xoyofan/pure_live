import 'package:flutter/material.dart';

import 'package:pure_live/core/sites.dart';

import '../platform_brands.dart';

/// 平台图标:统一走 pure_live 官方映射 [Sites.logoForId]
/// (与 README.md 平台表格同一套 `assets/images/<platform>.png` 素材,
/// 含 iptv.png 与退役站兜底 logo.png;「全部」除外,见 build 内特判);
/// 不在站点表里的 id(如 zishu 品牌表别名 xhs)回退品牌色首字母。
class PlatformIcon extends StatelessWidget {
  const PlatformIcon({super.key, required this.id, this.size = 28});

  final String id;
  final double size;

  static const Map<String, String> _labels = {
    'all': '全',
    'bilibili': '哔',
    'douyin': '抖',
    'douyu': '斗',
    'huya': '虎',
    'kuaishou': '快',
    'soop': 'S',
    'twitch': 'T',
    'xhs': '红',
    'youtube': '▶',
    'yy': 'YY',
  };

  /// 兜底字形的品牌色:取自 [PlatformBrandCatalog](平台色表的**唯一真源**)。
  static final Map<String, Color> _colors = {
    for (final brand in PlatformBrandCatalog.navPlatforms) brand.id: brand.color,
  };

  @override
  Widget build(BuildContext context) {
    final normalizedId = id.trim().toLowerCase();
    // 「全部」入口不走素材映射:官方 all.png 是无关素材(蓝底「文」字圆标),
    // 按 zishu 口径渲染 Material 的 all_inclusive(∞)字形。
    if (normalizedId == Sites.allSite) {
      return Icon(Icons.all_inclusive, size: size);
    }
    // 站点表内的 id 走官方素材映射;表外 id(zishu 品牌别名等)走字母兜底。
    final asset = normalizedId == Sites.allSite || Sites.supportedSiteIds.contains(normalizedId)
        ? Sites.logoForId(normalizedId)
        : null;
    final color = _colors[normalizedId] ?? Theme.of(context).colorScheme.primary;
    // 字形前景取平台色表的**按平台定义**(与 PlatformBadge 同源)。
    final glyphColor =
        PlatformBrandCatalog.byId(normalizedId)?.chipForeground ?? PlatformBrandCatalog.chipForegroundLight;
    final fallback = _labels[normalizedId] ?? (normalizedId.isEmpty ? '?' : normalizedId.substring(0, 1));
    final radius = BorderRadius.circular(size * 0.22);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: radius,
        child: asset == null
            ? ColoredBox(
                color: color,
                child: Center(
                  child: Text(
                    fallback,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: glyphColor,
                      fontSize: normalizedId == 'yy'
                          ? size * 0.36
                          : size * 0.42, // ignore: design_token 几何比例(字母字形随图标盒缩放),非排版字号档
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              )
            : Image.asset(
                asset,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: color,
                  child: Center(
                    child: Text(
                      fallback,
                      style: TextStyle(
                        color: PlatformBrandCatalog.chipForegroundLight,
                        fontSize: size * 0.42, // ignore: design_token 几何比例(字母字形随图标盒缩放),非排版字号档
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
