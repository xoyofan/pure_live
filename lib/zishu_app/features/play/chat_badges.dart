// 聊天行徽章组件集(真源:zishu_flutter `side_panel/chat_badges.dart` +
// `chat_badge_image.dart` 的官方图片管线移植)。
//
// 各站协议字段 → LiveMessage 映射(引擎侧已填,渲染侧只消费):
// - 斗鱼 chatmsg:`bnn`/`bn`→badgeName,`bl`(兜底 `bnnl`/`fl`)→badgeLevel,
//   `bc` packed RGB→badgeColor 三色同值(协议单色),`brid`/`dfgm`/`diafid`
//   →badgeBrid/badgeMonths/badgeDiafid,`level`/`lv`→userLevel;
// - 虎牙 Tars 1400 `tDeco`:appId 10400 BadgeInfo{sBadgeName@3,iBadgeLevel@4}
//   →badgeName/badgeLevel,11200{iLevel@1}→userLevel;
// - 抖音 User.BadgeImageList 里 URL 含 'fansclub' 的官方图→badgeUrl,
//   描述子 #4 名称→badgeName、#3 等级(缺省回落 URL `badge_(\d+)`)→badgeLevel;
//   payGrade 不在裁剪 proto → userLevel 恒空;
// - B 站新老协议(渐变三色/描边)不动(默认分支)。
//
// 组件:
// - [ChatBadgeImage]:官方图片渲染管线(真源 `chat_badge_image.dart` 逐字
//   移植:远程 src 优先 CachedNetworkImage,本地资产兜底,失败帧尾回调
//   onFail;`chatWebImageFilter` 四5矩阵原样)。badgeAssetPath 保留
//   douyin fans 1..20 / douyin honor 1..75 / douyu fans 1..50 的本地路径
//   规则,但本仓库当前只有 bilibili/medal-frame.png 一张本地素材,其余
//   本地路径必然加载失败 → errorBuilder 直接 onFail,行为与真源「无资产」
//   一致(不拷素材);
// - [ZishuChatFanBadge]:分站粉丝牌 —— 抖音官方图(灰图换彩)优先、红渐变
//   圆盘兜底;虎牙官方底图优先、7 档渐变自绘胶囊兜底;斗鱼官方组合样式
//   ([_DouyuFanMedal]:桶图/房间前缀/等级/团名/钻粉 suffix)、协议色文字牌
//   legacy 回落;B 站 composed 渐变牌 + 无协议色官方边框图分支;
// - [douyinFansColoredBadgeUrl]/[douyinFansBadgeUrl]:抖音灰图换彩与官方
//   CDN 兜底 URL(真源 chat_badges.dart:32-80 口径移植);
// - [ZishuChatUserLevelBadge]:分站等级牌(斗鱼 LV 梯度胶囊 / 虎牙官方图
//   失败态兜底胶囊 / 其余通用灰底数字盒);userLevel 官方图协议位本轮未
//   解析,各分支不动;
// - [zishuFanBadgeVisible]:行内粉丝牌显隐闸门;
// - [zishuInlineBadge]:徽章内联进 Text.rich 段落的 WidgetSpan 包装。
//
// 颜色协议是十六进制字符串,由 [_parseBadgeHex] 宽容解析,失败回落
// `context.tokens.accent`(不臆造平台色)。

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

import 'douyu_fans_medal_assets.dart';

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

// ---- 官方图片渲染管线(真源 `chat_badge_image.dart` 逐字移植)----

/// Web `SideChatTab.vue` 对徽章/等级/表情图片的统一增强:
/// brightness(1.14) contrast(1.08) saturate(1.1)。Flutter 端用等价
/// 4×5 ColorFilter matrix,避免每个平台重复写滤镜。
const ColorFilter chatWebImageFilter = ColorFilter.matrix(<double>[
  1.328145,
  -0.088055,
  -0.008889,
  0,
  -0.1156,
  -0.026175,
  1.266265,
  -0.008889,
  0,
  -0.1156,
  -0.026175,
  -0.088055,
  1.345431,
  0,
  -0.1156,
  0,
  0,
  0,
  1,
  0,
]);

/// 徽章类别:fans=粉丝牌(团牌),userLevel=用户等级(荣誉/消费等级)。
enum ChatBadgeKind { fans, userLevel }

/// 抖音粉丝牌本地图上限(web manifest douyin.fansMax)。
const int kDouyinFansMaxLevel = 20;

/// 抖音荣誉等级本地图上限(web manifest douyin.honorMax)。
const int kDouyinHonorMaxLevel = 75;

/// 斗鱼粉丝牌本地图上限(web manifest douyu.fansMax)。
const int kDouyuFansMaxLevel = 50;

/// 按 web `platformBadgeStatic.ts` 规则解析徽章本地资产路径。
///
/// 返回 '' = 该站/类/档位无本地图(调用方应直接走文字态兜底):
/// - douyin fans `assets/badges/douyin/fans/{1..20}.png`(img-only 站);
/// - douyin userLevel `assets/badges/douyin/honor/{1..75}.png`;
/// - douyu fans `assets/badges/douyu/fans/{1..50}.png`(等级绘在官方 PNG 内);
/// - douyu userLevel:斗鱼消费等级 CDN 全 404,web 强制文字 → 恒 '';
/// - huya fans:粉丝牌不使用 v2 emblem(web `huyaFansBadgeStaticUrl` 已废弃)→ '';
/// - huya userLevel `assets/badges/huya/vip/v2/{identity}.png`
///   (消费/VIP emblem,7 档 identity 映射见 [_huyaVipEmblemIdentity]);
/// - bilibili:wealth 本轮不接入;粉丝牌边框走 [bilibiliMedalFrameAssetPath]。
String badgeAssetPath({required String site, required ChatBadgeKind kind, required int level}) {
  switch (site) {
    case 'douyin':
      return kind == ChatBadgeKind.fans
          ? _numberedPath('douyin/fans', level, kDouyinFansMaxLevel)
          : _numberedPath('douyin/honor', level, kDouyinHonorMaxLevel);
    case 'douyu':
      if (kind != ChatBadgeKind.fans) return '';
      return _numberedPath('douyu/fans', level, kDouyuFansMaxLevel);
    case 'huya':
      if (kind != ChatBadgeKind.userLevel) return '';
      return 'assets/badges/huya/vip/v2/${_huyaVipEmblemIdentity(level)}.png';
    default:
      return '';
  }
}

/// B 站粉丝牌官方边框图(web `bilibiliMedalFrameStaticUrl`;无协议渐变色时
/// 作底图、团名/等级文字叠层)。本仓库已拷入该素材
/// (`assets/badges/bilibili/medal-frame.png`)。
String bilibiliMedalFrameAssetPath() => 'assets/badges/bilibili/medal-frame.png';

/// `assets/badges/{dir}/{level}.png`,档位越界返回 ''。
String _numberedPath(String dir, int level, int max) {
  if (level <= 0 || level > max) return '';
  return 'assets/badges/$dir/$level.png';
}

/// 虎牙消费/VIP 等级 → v2 emblem identity
/// (web `resolveHuyaVipEmblemIdentity`:7 档,与官网 VIP 图标一致)。
int _huyaVipEmblemIdentity(int level) {
  final lv = level < 1 ? 1 : level;
  if (lv <= 4) return 1;
  if (lv <= 7) return 2;
  if (lv <= 10) return 3;
  if (lv <= 13) return 4;
  if (lv <= 16) return 11;
  if (lv <= 19) return 12;
  return 13;
}

/// 聊天行徽章图:远程 [ChatBadgeImage.src] 优先(CachedNetworkImage,
/// cacheKey=src),否则本地资产路径;解析失败/无资产 → `SizedBox.shrink` +
/// [ChatBadgeImage.onFail](调用方回落文字态),尺寸(高度)由调用方给定。
///
/// 默认 fit 按 kind 给定(web 全部 `object-fit: contain`,此处按 kind 显式
/// 分支,方形素材可改 cover):fans/userLevel 均为 contain;对齐 web
/// `object-position: left center` 左对齐,避免宽牌在窄位里居中裁切。
class ChatBadgeImage extends StatefulWidget {
  const ChatBadgeImage({
    super.key,
    required this.site,
    required this.kind,
    required this.level,
    required this.height,
    this.width,
    this.name,
    this.fit,
    this.src = '',
    this.assetPathOverride,
    this.useDiskCache = true,
    this.onFail,
  });

  final String site;
  final ChatBadgeKind kind;
  final int level;

  /// 预留:带牌名模板(如虎牙 `3/{size}/{dark}/{level}.{name}`)未来若改为
  /// 本地整牌可消费;当前路径规则未用到。
  final String? name;

  /// 渲染高度(调用方按 web 徽章高 1.15-1.48em @14px ≈ 16-21px 给定)。
  final double height;

  /// 渲染宽度(可选):给定后与 [height] 组成有界框,配 `BoxFit.cover`
  /// + 默认 `alignment: centerLeft` 实现「按内容区左对齐裁右」——
  /// 抖音宽模板粉丝牌(150×48)内容区只有左端 ~60 源px,右侧是渐变
  /// 延伸底,cover 左对齐正好裁掉延伸(2026-09-29 用户口径:图保留,
  /// 只收背景宽度)。
  final double? width;

  /// 覆写默认 fit(默认 fans/userLevel 均 contain)。
  final BoxFit? fit;

  /// 协议/平台直接下发的远程图 URL,优先于本地静态资源。
  final String src;

  /// 显式资产路径;用于 Bilibili medal-frame 等不走等级编号的固定素材。
  final String? assetPathOverride;

  /// 是否使用磁盘缓存;房间定制徽章可关闭,避免 URL 复用旧图。
  final bool useDiskCache;

  /// 加载失败/无资产回调(每个失败只回一次;输入变化后重置重试)。
  final VoidCallback? onFail;

  /// 解析后的资产路径('' = 无本地图);暴露给调用方/测试判定图片分支。
  String get assetPath => assetPathOverride ?? badgeAssetPath(site: site, kind: kind, level: level);

  @override
  State<ChatBadgeImage> createState() => _ChatBadgeImageState();
}

class _ChatBadgeImageState extends State<ChatBadgeImage> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant ChatBadgeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.site != widget.site ||
        oldWidget.kind != widget.kind ||
        oldWidget.level != widget.level ||
        oldWidget.name != widget.name ||
        oldWidget.src != widget.src ||
        oldWidget.assetPathOverride != widget.assetPathOverride) {
      // 行复用换内容后允许重新尝试图片(资产确实缺失会在一帧内再次回落)。
      _failed = false;
    }
  }

  /// 失败收敛:置 shrink 并在帧尾回调(禁止 build/errorBuilder 内 setState)。
  void _reportFail() {
    if (_failed || !mounted) return;
    _failed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFail?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final localPath = widget.assetPath;
    // 不限宽:素材按自身比例(BoxFit.contain)完整呈现,左右两侧不做裁切。
    // 抖音 honor 的 96×48 长胶囊曾按内容区裁到 76/48 并改 cover,实测会把
    // 图标与数字边缘切掉,真源 2026-09-27 回退为「原比例整图 + contain」。
    final fit = widget.fit ?? _defaultFit(widget.kind);
    // 对齐 web `object-position: left center`,避免宽牌在窄位里居中。
    const alignment = Alignment.centerLeft;
    if (widget.src.isNotEmpty) {
      final Widget networkImage = widget.useDiskCache
          ? CachedNetworkImage(
              imageUrl: widget.src,
              cacheKey: widget.src,
              height: widget.height,
              width: widget.width,
              fit: fit,
              alignment: alignment,
              filterQuality: FilterQuality.medium,
              placeholder: (_, _) => SizedBox(height: widget.height, width: widget.width),
              errorWidget: (context, error, stackTrace) {
                if (localPath.isEmpty) {
                  _reportFail();
                  return const SizedBox.shrink();
                }
                return _assetImage(localPath, fit, alignment);
              },
            )
          : Image.network(
              widget.src,
              height: widget.height,
              width: widget.width,
              fit: fit,
              alignment: alignment,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                if (localPath.isEmpty) {
                  _reportFail();
                  return const SizedBox.shrink();
                }
                return _assetImage(localPath, fit, alignment);
              },
            );
      return ColorFiltered(colorFilter: chatWebImageFilter, child: networkImage);
    }
    if (localPath.isEmpty) {
      // 无资产:立即渲染 shrink(调用方经 onFail 回文字态)。
      _reportFail();
      return const SizedBox.shrink();
    }
    return _assetImage(localPath, fit, alignment);
  }

  Widget _assetImage(String path, BoxFit fit, Alignment alignment) => ColorFiltered(
    colorFilter: chatWebImageFilter,
    child: Image.asset(
      path,
      height: widget.height,
      width: widget.width,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        _reportFail();
        return const SizedBox.shrink();
      },
    ),
  );

  /// 按 kind 的默认 fit:两类素材均为官方整牌(内容含自身描边),contain
  /// 完整呈现;后续若有方形纯图标素材可在分支里改 cover。
  BoxFit _defaultFit(ChatBadgeKind kind) => switch (kind) {
    ChatBadgeKind.fans => BoxFit.contain,
    ChatBadgeKind.userLevel => BoxFit.contain,
  };
}

// ---- 抖音官方图 URL 口径(真源 chat_badges.dart:32-80 移植)----

/// 抖音粉丝牌**彩色化**:协议常下发未点亮的灰图,换回同尺寸彩色款。
///
/// 口径抄 web `apps/web/src/utils/badges/fanBadges/douyin.ts` 的
/// `resolveDouyinColoredFansBadgeUrl`:
/// - `pop_gray_super_badge` → `pop_super_badge`(实测两者同为 60×48,仅颜色差异,
///   2026-09-26 实测真实弹幕 513 条里 152 条是灰图、361 条是彩色 —— 不换则
///   近三成徽章显示为灰色);
/// - 其余灰图(`advanced_gray` 等)→ 官方紧凑款 `pop_super_badge_{lv}`
///   (2026-09-27 用户口径:三模板统一最右紧凑款,不再用 new_badge 中等款);
/// - 彩色协议图(v6 150×48 宽牌等)**原样返回**(2026-09-29 用户口径:
///   「之前的图是对的,当前换图错了」)—— 宽度由渲染侧按内容区裁剪
///   (见 [AppDouyinChatBadge.fanCroppedWidth]),不换图。
String douyinFansColoredBadgeUrl(String url, int level) {
  final text = url.trim();
  if (text.isEmpty) return '';
  if (RegExp(r'pop_gray_super_badge', caseSensitive: false).hasMatch(text)) {
    return text.replaceAll(RegExp(r'pop_gray_super_badge', caseSensitive: false), 'pop_super_badge');
  }
  if (_douyinGrayBadgePattern.hasMatch(text) && level > 0) {
    return douyinFansBadgeUrl(level);
  }
  return text;
}

final RegExp _douyinGrayBadgePattern = RegExp(r'advanced_gray|pop_gray_super_badge', caseSensitive: false);

/// 抖音粉丝牌官方 CDN 兜底图 URL。
///
/// 2026-09-27 用户口径(dyx-compare.png 三模板实测对比):同一等级抖音官方
/// CDN 有**三种宽度**的牌——`fansclub_level_v6`(150×48 → 高 21 时 65.6px
/// 长条)、`fansclub_new_badge`(90×48 → 39.4px 中等)、
/// `ranklist_fansclub_pop_super_badge`(60×48 → 26.2px 紧凑款)。抖音聊天间
/// 实际展示的是**最右的紧凑款**(协议主流图即 pop_super,CDN 实测 1..20 全
/// 200、21+ 404)。此前兜底/灰图换彩用 new_badge,同一房间出现 39.4 与
/// 26.2 两种宽度 —— 统一改用 pop_super 模板。
///
/// 档位 1..20 有图;越界返回 '' → 调用方走红色渐变圆盘文字态。
String douyinFansBadgeUrl(int level) {
  if (level <= 0 || level > kDouyinFansMaxLevel) return '';
  return 'https://p3-webcast.douyinpic.com/img/webcast/'
      'ranklist_fansclub_pop_super_badge_$level'
      '.png~tplv-obj.image';
}

/// 行内粉丝牌显隐闸门(对齐真源 `_FanBadge.visibleFor` 只卡 douyu 团名的
/// 口径,chat_badges.dart:163-164,叠加官方图分支的最低渲染条件):
/// - douyu:团名必须非空(组合样式团名层无名字不可渲染,真源同款);
/// - douyin/huya:有协议图 [url] 或有 [level] 即可(官方图/圆盘/自绘胶囊
///   均可脱离团名渲染;tooltip 有名带名);
/// - 通用(含 bilibili):仍要求团名非空(文字牌主体是团名,现行口径)。
bool zishuFanBadgeVisible({required String site, String? name, String? level, String? url}) {
  final hasName = name?.trim().isNotEmpty ?? false;
  if (site == 'douyu') return hasName;
  if (site == 'douyin' || site == 'huya') {
    final hasUrl = url?.trim().isNotEmpty ?? false;
    final hasLevel = level?.trim().isNotEmpty ?? false;
    return hasUrl || hasLevel;
  }
  return hasName;
}

/// 粉丝牌:分站渲染(真源 `_FanBadge` 各分支;官方图优先,既有文字态一律
/// 保留为加载失败/无协议图的兜底):
///
/// - 斗鱼:官方**组合样式**(真源 [_DouyuFanMedal] 全量移植,66×19:等级桶
///   背景图 + 房间前缀图(brid 匹配)+ 等级数字 + 团名 + 钻粉 suffix 层);
///   配置拉取失败/等级无桶 → legacy 回落 = 协议色 bc 文字牌(几何用现值);
///   斗鱼 kind 分档(supreme/noble/superfan/diamondfan)本轮不迁;
/// - 虎牙:官方底图分支(真源 450-468:`src=badgeUrl`,`useDiskCache:false`
///   —— 房间定制徽章避免 URL 复用旧图)失败/无 url → 现行自绘胶囊
///   (web `.chat-fan-badge--huya-composed` 同构:高 `1.15em`、最小宽
///   `3.4em`、圆角 2px、底色 `fanGradient(level)` 7 档);身份图标
///   (vFlag/vLogo)本轮不迁;
/// - 抖音:img-only 站(真源 302-353)。协议图先灰图换彩
///   ([douyinFansColoredBadgeUrl]),无协议图/换彩为空统一落官方紧凑款 CDN
///   ([douyinFansBadgeUrl]);图渲染 `BoxFit.cover` + 仅右圆角
///   `fanCropEndRadius`(宽模板左对齐裁右,显示宽 `fanCroppedWidth`);
///   两者皆空或加载失败 → 红渐变圆盘文字态;
/// - B 站(默认):有协议渐变色 → composed 渐变牌(不动);无协议色 →
///   官方边框图 `medal-frame.png` + 文字叠层(真源 565-613:`fanTextShadow`
///   压图可读,`fanPadLeft/fanPadRight`);边框图失败 → 中性深底文字牌。
class ZishuChatFanBadge extends StatefulWidget {
  const ZishuChatFanBadge({
    super.key,
    this.site = '',
    required this.name,
    this.level,
    this.colorStart,
    this.colorEnd,
    this.colorBorder,
    this.url,
    this.brid = 0,
    this.months = 0,
    this.diafid = 0,
  });

  /// 站点 id(LiveRoom.platform,真源 `site` 同名分档依据)。
  ///
  /// 缺省空串 = 老调用点(未带站点的旧弹幕列表)保持 B 站 composed 通用渲染。
  final String site;

  /// 粉丝牌团名(douyin/huya 官方图分支可不带,见 [zishuFanBadgeVisible])。
  final String name;

  /// 粉丝牌等级(原始字符串;null/空白 = 不展示等级数字)。
  final String? level;

  /// 渐变起/止与描边色(十六进制,见 [_parseBadgeHex])。
  final String? colorStart;
  final String? colorEnd;
  final String? colorBorder;

  /// 官方图 URL(LiveMessage.badgeUrl):douyin 协议图/虎牙房间底图。
  /// 空/null = 无官方图 → 直接走各站兜底。
  final String? url;

  /// 粉丝牌所属房间号(斗鱼协议 `brid`,房间自定义前缀图的匹配键)。
  final int brid;

  /// 斗鱼钻粉成长月数(协议 `dfgm`,>0 = 叠钻粉 suffix 层)。
  final int months;

  /// 斗鱼钻粉 suffix 装扮 id(协议 `diafid`)→ 查主播装扮表取 suffix 图。
  final int diafid;

  @override
  State<ZishuChatFanBadge> createState() => _ZishuChatFanBadgeState();
}

class _ZishuChatFanBadgeState extends State<ZishuChatFanBadge> {
  /// 官方图加载失败/缺失:回落文字态(输入变化后重置重试,真源
  /// `_FanBadgeState._imgFailed` 同口径)。
  bool _imgFailed = false;

  @override
  void didUpdateWidget(covariant ZishuChatFanBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.site != widget.site ||
        oldWidget.level != widget.level ||
        oldWidget.name != widget.name ||
        oldWidget.url != widget.url ||
        oldWidget.colorStart != widget.colorStart ||
        oldWidget.colorEnd != widget.colorEnd ||
        oldWidget.colorBorder != widget.colorBorder) {
      _imgFailed = false;
    }
  }

  void _markImgFailed() {
    if (mounted) setState(() => _imgFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final name = widget.name;
    final hasName = name.trim().isNotEmpty;
    final levelText = widget.level?.trim() ?? '';
    // 等级非数字按 0 档(与虎牙胶囊分档同口径;不臆造等级,只用于
    // 取图档位/兜底 CDN 模板,越界自然空)。
    final levelValue = int.tryParse(levelText) ?? 0;
    final officialUrl = widget.url?.trim() ?? '';

    // 抖音:官方图优先(灰图换彩 → 官方紧凑款 CDN),失败回落红渐变圆盘
    // (真源 chat_badges.dart:302-353)。
    if (site == 'douyin') {
      final colored = douyinFansColoredBadgeUrl(officialUrl, levelValue);
      final badgeUrl = colored.isNotEmpty ? colored : douyinFansBadgeUrl(levelValue);
      // 团名不再必须(真源 douyin 分支无团名闸门):tooltip 有名带名。
      final tooltip = hasName ? '${name.trim()} Lv.$levelText' : 'Lv.$levelText';
      if (badgeUrl.isNotEmpty && !_imgFailed) {
        return Tooltip(
          message: tooltip,
          child: ClipRRect(
            // 宽模板 cover 左对齐裁右后,右端裁切处补高度一半的圆头
            // (AppDouyinChatBadge.fanCropEndRadius)组成完整胶囊。
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(AppDouyinChatBadge.fanCropEndRadius)),
            child: ChatBadgeImage(
              site: site,
              kind: ChatBadgeKind.fans,
              level: levelValue,
              height: AppDouyinChatBadge.fanImageHeight,
              width: AppDouyinChatBadge.fanCroppedWidth,
              fit: BoxFit.cover,
              src: badgeUrl,
              // 本地 `assets/badges/douyin/fans/*` 实为粉翼大摆台(非官网
              // 样式),加载失败时宁可落红色渐变圆盘,也不回退到错的画风
              // (真源同口径:assetPathOverride 置空)。
              assetPathOverride: '',
              onFail: _markImgFailed,
            ),
          ),
        );
      }
      // 真源兜底圆盘原样:19.6 圆 + 红渐变(90deg,colors[0] 在左)+
      // 数字 caption/h1.1/w800。等级缺失时无数字可写(不造 0)。
      return Tooltip(
        message: tooltip,
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
    // 虎牙:官方底图分支(真源 450-468;底图内含等级圆标与团名区,独占
    // 整牌)。url 为空或加载失败 → 现行自绘胶囊(真源自绘兜底同构)。
    if (site == 'huya') {
      final tooltip = hasName ? '${name.trim()} Lv.$levelText' : '粉丝牌 Lv.$levelText';
      if (officialUrl.isNotEmpty && !_imgFailed) {
        return Tooltip(
          message: tooltip,
          child: SizedBox(
            height: AppHuyaChatBadge.fanHeight,
            child: ChatBadgeImage(
              site: site,
              kind: ChatBadgeKind.fans,
              level: levelValue,
              height: AppHuyaChatBadge.fanHeight,
              src: officialUrl,
              // 房间定制徽章关磁盘缓存,避免 URL 复用旧图(真源同口径)。
              useDiskCache: false,
              onFail: _markImgFailed,
            ),
          ),
        );
      }
      final hasLevel = levelText.isNotEmpty;
      // 底色分档:≤4 / 5–13 / 14–17 / 18–20 / 21–22 / 23–27 / ≥28
      // (AppHuyaChatBadge.fanGradient);等级非数字时按 0 档(≤4)。
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
        message: tooltip,
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
    // 斗鱼:官方组合样式(_DouyuFanMedal 全量移植);配置未就绪/等级无桶
    // 由其回落 legacy(= 现行协议色文字牌)。团名必须(真源 douyu 闸门)。
    if (site == 'douyu') {
      if (!hasName) return const SizedBox.shrink();
      return _DouyuFanMedal(
        level: levelValue,
        name: name.trim(),
        brid: widget.brid,
        months: widget.months,
        diafid: widget.diafid,
        legacyBuilder: () => _buildDouyuLegacyBadge(context),
      );
    }
    // B 站(默认):B 站 composed 渐变口径(真源 `_FanBadge` 的 bilibili
    // 分支)。
    //
    // - 渐变 `to left`:start 色在右、end 色在左(web
    //   `linear-gradient(to left, start, end)`);start/end 互补缺省
    //   (start=colorStart||colorEnd),均缺失/解析失败用 accent 兜底;
    // - 描边色 [colorBorder] 解析失败就不画边(对齐真源 `colorBorder != 0`);
    // - 高 `1.48em`、最小宽 `3.5em`、左右 `.5em`、列间距 `.2em`(composed)
    //   /`.18em`(has-bg)、文字 `.9em` 均取 `AppChatBadge.*`,字重 700,
    //   等级数字 tabular figures。
    final accent = context.tokens.accent;
    final startHex = _parseBadgeHex(widget.colorStart);
    final endHex = _parseBadgeHex(widget.colorEnd);
    // 互补缺省对齐真源 bilibili 分支:start=colorStart||colorEnd。
    final start = startHex ?? endHex ?? accent;
    final end = endHex ?? startHex ?? accent;
    final hasProtocolColor = startHex != null || endHex != null;
    final borderColor = _parseBadgeHex(widget.colorBorder);
    // web `.chat-fan-badge__content { gap: .18em; font-size: .9em }`;
    // composed 分支把 gap 覆写为 `.2em`(真源 528-531)。
    final contentGap = hasProtocolColor ? AppChatBadge.biliFanGap : AppChatBadge.fanGap;
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
        if (levelText.isNotEmpty) ...[
          SizedBox(width: contentGap),
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
    // 无协议渐变色 → 官方边框图分支(真源 565-613):medal-frame.png 作
    // 底图(左对齐),文字叠层加 `fanTextShadow` 压图可读;边框图失败
    // (_imgFailed)落到下方中性深底文字牌,行为与真源「无资产」一致。
    if (!hasProtocolColor && !_imgFailed) {
      return Tooltip(
        message: hasName ? '${name.trim()} Lv.$levelText' : '粉丝团 Lv.$levelText',
        child: KeyedSubtree(
          key: const Key('bilibili-fan-badge'),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            child: Container(
              height: AppChatBadge.fanHeight,
              constraints: const BoxConstraints(minWidth: AppChatBadge.fanMinWidth),
              decoration: const BoxDecoration(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ChatBadgeImage(
                        site: site,
                        kind: ChatBadgeKind.fans,
                        level: levelValue,
                        height: AppChatBadge.fanHeight,
                        assetPathOverride: bilibiliMedalFrameAssetPath(),
                        onFail: _markImgFailed,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: AppChatBadge.fanPadLeft, right: AppChatBadge.fanPadRight),
                    child: Center(
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(shadows: AppChatBadge.fanTextShadow),
                        child: content,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // 有协议渐变色 → web `.chat-fan-badge--bilibili-composed`(不动);
    // 无协议色且官方框图失败 → 同盒中性深底占位(web 无协议图/色时走
    // 官方图片牌,flutter 无图 → 深底占位保持可读,真源同口径)。
    return Tooltip(
      message: hasName ? '${name.trim()} Lv.$levelText' : '粉丝团 Lv.$levelText',
      child: KeyedSubtree(
        key: const Key('bilibili-fan-badge'),
        child: _BadgeBox(
          height: AppChatBadge.biliFanHeight,
          minWidth: AppChatBadge.biliFanMinWidth,
          radius: AppRadius.pill,
          padding: const EdgeInsets.symmetric(horizontal: AppChatBadge.biliFanPadX),
          gradient: hasProtocolColor ? [start, end] : null,
          color: hasProtocolColor ? null : AppDouyuChatBadge.fanFallbackBg,
          border: borderColor,
          // web `linear-gradient(to left, start, end)`:start 在右、end 在左。
          gradientBegin: Alignment.centerRight,
          gradientEnd: Alignment.centerLeft,
          child: content,
        ),
      ),
    );
  }

  /// 斗鱼 legacy 回落 = 现行协议色文字牌(官方组合样式配置未就绪/等级无桶
  /// 时由 [_DouyuFanMedal] 调用;几何用现值:高 19、最小宽 66、等级
  /// 12/w700 tabular → 团名 12/w600,bc 单色平涂底 + 同色描边)。
  Widget _buildDouyuLegacyBadge(BuildContext context) {
    final accent = context.tokens.accent;
    // 互补缺省对齐真源 bilibili 分支:start=colorStart||colorEnd。
    // 斗鱼协议单色(start=end=border=bc)→ 实际渲染为平涂底 + 同色描边。
    final start = _parseBadgeHex(widget.colorStart) ?? _parseBadgeHex(widget.colorEnd) ?? accent;
    final end = _parseBadgeHex(widget.colorEnd) ?? _parseBadgeHex(widget.colorStart) ?? accent;
    final borderColor = _parseBadgeHex(widget.colorBorder);
    final levelText = widget.level?.trim() ?? '';
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
            widget.name.trim(),
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
      message: hasLevel ? '${widget.name.trim()} Lv.$levelText' : widget.name.trim(),
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
}

/// 斗鱼粉丝牌官方组合样式(真源 `side_panel/chat_badges.dart` 的
/// `_DouyuFanMedal` 全量移植,对齐官网 web `dy-fan-medal` lit 组件)。
///
/// 五层结构(2026-09-27 房间 96555 shadow DOM 实测):
/// 1. 背景图 `backdrop`:等级按 5 级一档分桶,配置源
///    `wconf.douyucdn.cn/resource/common/fans_medal_web_v5.json`(与官网
///    同一份数据,见 `DouyuFansMedalAssets`);
/// 2. 前缀图 `prefix`:房间自定义徽记,按 `brid` 匹配;底部对齐、顶部
///    溢出容器 3px(web 原样,24×22);
/// 3. 等级数字:web 是编译进 CSS 的 per-level 小图(AkrobatBlack 字形),
///    离线化成本高,这里用白字近似 —— 无前缀时占满左区 22×19,有前缀时
///    落在右侧 13×10 小盒;
/// 4. 团名 `name`:白字 12px 居中,右侧内缩 4px;
/// 5. 钻粉 suffix 层(月数>0):suffix 图 26×21 右贴底 + 月数字 15×12,
///    容器加宽 66→84、上限 140。
///
/// 配置未就绪/等级无桶 → [ZishuChatFanBadge] 传入的 legacyBuilder(现行
/// 协议色文字牌),不阻断显示。
class _DouyuFanMedal extends StatefulWidget {
  const _DouyuFanMedal({
    required this.level,
    required this.name,
    required this.legacyBuilder,
    this.brid = 0,
    this.months = 0,
    this.diafid = 0,
  });

  final int level;
  final String name;
  final int brid;

  /// 钻粉成长月数(>0 = 叠钻粉 suffix 层,容器加宽 66→84)。
  final int months;

  /// 钻粉 suffix 装扮 id(`diafid`)→ 查装扮表取主播购买款 suffix 图。
  final int diafid;
  final Widget Function() legacyBuilder;

  @override
  State<_DouyuFanMedal> createState() => _DouyuFanMedalState();
}

class _DouyuFanMedalState extends State<_DouyuFanMedal> {
  DouyuFansMedalConfig? _config;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await DouyuFansMedalAssets.instance.get();
    if (!mounted) return;
    if (config == null) {
      setState(() => _loadFailed = true);
      return;
    }
    setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final backdropUrl = config?.backdropUrl(widget.level);
    if (config == null && !_loadFailed) {
      // 配置在途:占位避免布局跳动,不闪旧样式。
      return SizedBox(width: AppDouyuChatBadge.medalWidth, height: AppDouyuChatBadge.medalHeight);
    }
    if (backdropUrl == null || backdropUrl.isEmpty) {
      // 配置拉取失败,或该等级没有桶图(理论上不会,commBg 覆盖 0..61+)
      // → 回落旧渲染。
      return widget.legacyBuilder();
    }
    final prefixUrl = _config?.prefixUrl(widget.brid);
    // suffix 图:有 diafid 且装扮表(inter_com_w_anchor_rights.json)命中
    // → 主播购买款(动图 webp);否则默认款(diamond_list[1] 的 6ab5daa PNG)。
    final suffixUrl = _config?.diamondSuffixUrl(widget.diafid) ?? kDouyuDiamondFanSuffixUrl;
    // 钻粉 suffix 层(月数>0):官网把钻粉钻石图结合在粉丝牌后面,容器
    // 加宽 66→84(computed 实测保底)。官网团名 span 按内容自适应、永不
    // 截断(overflow:visible 无 ellipsis),这里按团名实测宽度把容器继续
    // 撑开(suffix 上限 140),suffix 恒贴最右。
    //
    // 测量必须合并 DefaultTextStyle(2026-09-27 房间 84452「保飞派」被截
    // 成「保...」的根因):真实 Text 会继承 MaterialApp 主题的 fontFamily
    // (AppTypography.family),裸 TextStyle 的 TextPainter 用默认字体测宽,
    // CJK 字形推进宽度不同 → 测量宽 < 渲染宽 → 名字被 ellipsis。同因还
    // 要带上 textScaler;+2px 是亚像素/字距合成余量。
    final hasSuffix = widget.months > 0;
    final nameStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: AppDouyuChatBadge.medalNameFontSize,
        height: 1,
        color: AppOnBright.white,
        fontWeight: FontWeight.w600,
      ),
    );
    final namePainter = TextPainter(
      text: TextSpan(text: widget.name, style: nameStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final nameWidth = namePainter.width + 2;
    final minWidth = hasSuffix ? AppDouyuChatBadge.medalWidthWithSuffix : AppDouyuChatBadge.medalWidth;
    // 官网容器是内容自适应的 min-width:66/84,团名更长就继续撑开
    // (非 suffix 右缘让位 medalRightGap,suffix 右缘让位 suffix 区+间隙)。
    var badgeWidth = minWidth;
    final needed = hasSuffix
        ? AppDouyuChatBadge.medalLeftZone + nameWidth + 2 + AppDouyuChatBadge.medalSuffixWidth
        : AppDouyuChatBadge.medalLeftZone + nameWidth + AppDouyuChatBadge.medalRightGap;
    if (needed > badgeWidth) badgeWidth = needed;
    if (hasSuffix && badgeWidth > AppDouyuChatBadge.medalWidthWithSuffixMax) {
      badgeWidth = AppDouyuChatBadge.medalWidthWithSuffixMax;
    }
    return KeyedSubtree(
      key: const Key('douyu-fan-badge'),
      child: SizedBox(
        width: badgeWidth,
        height: AppDouyuChatBadge.medalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1) 背景图(等级桶)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: backdropUrl,
                fit: BoxFit.fill,
                cacheKey: backdropUrl,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => Container(color: AppDouyuChatBadge.fanFallbackBg),
              ),
            ),
            // 2) 房间自定义前缀图(底部对齐,顶部溢出 3px = web 原样)
            if (prefixUrl != null && prefixUrl.isNotEmpty)
              Positioned(
                left: 1,
                bottom: 0,
                width: AppDouyuChatBadge.medalPrefixWidth,
                height: AppDouyuChatBadge.medalPrefixHeight,
                child: CachedNetworkImage(
                  imageUrl: prefixUrl,
                  fit: BoxFit.contain,
                  cacheKey: prefixUrl,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // 3) 等级数字(白字近似 web 的 per-level 小图)。有前缀时 web
            //    computed 实测(2026-09-27):13×10 小盒、bottom:0 —— 数字
            //    **贴容器底**(用户报「数字太靠上」即此处当年误做整高居中);
            //    无前缀时 web 是整高数字图(0..19,字形本身略偏中下),
            //    文本居中近似可接受。
            Positioned(
              left: prefixUrl != null ? AppDouyuChatBadge.medalLevelSmallLeft : 1,
              width: prefixUrl != null ? AppDouyuChatBadge.medalLevelSmallWidth : AppDouyuChatBadge.medalLeftZone - 2,
              bottom: 0,
              height: prefixUrl != null ? AppDouyuChatBadge.medalLevelSmallHeight : AppDouyuChatBadge.medalHeight,
              child: Center(
                child: Text(
                  '${widget.level}',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: prefixUrl != null
                        ? AppDouyuChatBadge.medalLevelSmallFontSize
                        : AppDouyuChatBadge.medalLevelFontSize,
                    height: 1,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: [
                      // web 烘焙数字自带立体暗边;白字必须压暗才可读。
                      Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 1.5),
                    ],
                  ),
                ),
              ),
            ),
            // 4) 团名(有钻粉 suffix 时右缘让位 suffix 区,web
            //    `.container.has-suffix .name{right:30px}`)
            Positioned(
              left: AppDouyuChatBadge.medalLeftZone,
              right: hasSuffix ? AppDouyuChatBadge.medalNameRightWithSuffix : AppDouyuChatBadge.medalRightGap,
              top: 0,
              bottom: 0,
              child: Center(
                // 官网 .name overflow:visible、内容自适应永不截断(2026-09-27
                // 实测)。容器宽度已按文字实测撑开,visible 只是极端情况
                // (超长名触顶 140)下不截字、允许画出边界的兜底。
                child: Text(
                  widget.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: nameStyle,
                ),
              ),
            ),
            // 5) 钻粉 suffix 层(官网把钻粉钻石图**结合在粉丝牌后面**,即
            //    用户口径「gif 样式结合在粉丝牌后面」;默认款是静态 PNG,
            //    房间自定款动图 webp 协议未下发,降级统一默认款) + 月数
            //    白字。几何为 computed 实测:图 26×21 右侧贴底、顶溢 2px;
            //    月数字 15×12 贴底叠在图上。
            if (hasSuffix) ...[
              Positioned(
                right: AppDouyuChatBadge.medalSuffixRight,
                bottom: 0,
                width: AppDouyuChatBadge.medalSuffixWidth,
                height: AppDouyuChatBadge.medalSuffixHeight,
                child: CachedNetworkImage(
                  imageUrl: suffixUrl,
                  // 源图 33×24,官网按 CSS 档 30×21 缩放绘制(fill),contain
                  // 会因宽高比差异横向留白显得没靠右。
                  fit: BoxFit.fill,
                  cacheKey: suffixUrl,
                  filterQuality: FilterQuality.medium,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              Positioned(
                right: AppDouyuChatBadge.medalSuffixRight,
                bottom: 0,
                width: AppDouyuChatBadge.medalSuffixMonthWidth,
                height: AppDouyuChatBadge.medalSuffixMonthHeight,
                child: Center(
                  child: Text(
                    '${widget.months}',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: AppDouyuChatBadge.medalSuffixMonthFontSize,
                      height: 1,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: [Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 1.5)],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 用户等级牌:分站渲染(真源 `_UserLevelBadge` 各分支的文字态/兜底态;
/// userLevel 官方图协议位本轮未解析,各分支不动)。
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
