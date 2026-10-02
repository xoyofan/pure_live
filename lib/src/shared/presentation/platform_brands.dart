import 'package:flutter/material.dart';
import 'package:live_parser/live_parser.dart';

/// 平台品牌规格:角标、tabs、筛选 chips 共用。
class PlatformBrand {
  const PlatformBrand({
    required this.id,
    required this.name,
    required this.color,
    this.chipForeground = PlatformBrandCatalog.chipForegroundLight,
    this.browseSupported = true,
  });

  final String id;
  final String name;

  /// 平台品牌色。**单一真源**:对齐 web `config/platformCatalog.ts` 的
  /// `PLATFORM_BRAND_COLORS[id].bg`。
  ///
  /// 图标底色、顶栏 tab 描边/光晕、封面角标、侧栏标签都用这一个值 ——
  /// web 也是同一份:启动时 `initPlatformBrandVars()`（main.js:57）把
  /// `info.bg` 内联注入 `--platform-{id}` / `-chip-bg` / `--sidebar-tag-{id}-bg`,
  /// **覆盖** theme.css/main.css 里的静态同名变量。
  ///
  /// 因此 theme.css:12 的 `--platform-bilibili: #00a1d6`（蓝）是**被覆盖的旧值**，
  /// 不是第二个真源：哔哩实渲染色是色表里的 **粉 `#fb7299`**。
  /// 同理斗鱼的静态 `#ff6b00` 也被 `#ff6a00` 覆盖。详见 `DESIGN.md` §2.3。
  final Color color;

  /// 平台色块(pill/chip)上的文字色。
  ///
  /// 不能按背景亮度自动算:参考实现的 chip 前景是**按平台硬编码**的
  /// (`--platform-{id}-chip-fg`,如虎牙黄底用 `#1a1a1a`,斗鱼橙底用 `#fff`),
  /// 自动估算会在橙色上给出深色字,与参考不一致。
  ///
  /// 取值见 [PlatformBrandCatalog.chipForegroundLight] /
  /// [PlatformBrandCatalog.chipForegroundDark]。
  final Color chipForeground;

  /// 该平台是否支持栏目浏览(不支持时展示房间号/URL 直达输入)。
  final bool browseSupported;
}

/// 平台品牌目录:色值、名称与 SFVideoLive 平台目录对齐。
///
/// `navigationPlatforms` / `searchPlatforms` 在真实解析构建中从 live_parser
/// 注册表能力动态裁剪；fixture 构建保留 `navPlatforms` 全量目录。
abstract final class PlatformBrandCatalog {
  /// 亮底平台色块/图标上的**白色**前景(`--platform-{id}-chip-fg: #fff`,
  /// 深底平台的通用默认)。
  ///
  /// 平台数据,不是主题量:压在品牌色上的前景由平台自身决定,深浅主题共用。
  static const Color chipForegroundLight = Color(0xFFFFFFFF);

  /// 亮底平台色块/图标上的**深色**前景(`--platform-huya-chip-fg: #1a1a1a`,
  /// 黄/橙等亮底平台用)。
  ///
  /// YY 的 `#FFD000` 底同样取这一档(见 `PlatformIcon` 的兜底字形)。
  static const Color chipForegroundDark = Color(0xFF1A1A1A);

  static const PlatformBrand all = PlatformBrand(
    id: 'all',
    name: '全平台',
    color: Color(0xFFF3D04E),
    // 「全平台」是品牌金底(亮底),web 无对应条目;按同族亮底的约定用深色字
    // (与 yy / huya 同理),不能用默认的白字。
    chipForeground: chipForegroundDark,
  );

  static const PlatformBrand douyu = PlatformBrand(id: 'douyu', name: '斗鱼', color: Color(0xFFFF6A00));

  static const PlatformBrand huya = PlatformBrand(
    id: 'huya',
    name: '虎牙',
    color: Color(0xFFFFB800),
    // 对齐 `--platform-huya-chip-fg: #1a1a1a`(黄底用深色字)。
    chipForeground: chipForegroundDark,
  );

  static const PlatformBrand bilibili = PlatformBrand(id: 'bilibili', name: '哔哩', color: Color(0xFFFB7299));

  static const PlatformBrand douyin = PlatformBrand(
    id: 'douyin',
    name: '抖音',
    color: Color(0xFFFE2C55),
    browseSupported: true,
  );

  static const PlatformBrand yy = PlatformBrand(
    id: 'yy',
    name: 'YY',
    color: Color(0xFFFFD000),
    // 对齐 web `platformCatalog.ts` 的 `yy: { bg: "#ffd000", fg: "#1a1a1a" }`
    // (黄底用深色字)。此前漏了这一档,与 platform_icon 的兜底字形取值不一致。
    chipForeground: chipForegroundDark,
  );

  static const PlatformBrand twitch = PlatformBrand(id: 'twitch', name: 'Twitch', color: Color(0xFF9146FF));

  static const PlatformBrand kuaishou = PlatformBrand(id: 'kuaishou', name: '快手', color: Color(0xFFFF4906));

  static const PlatformBrand soop = PlatformBrand(id: 'soop', name: 'SOOP', color: Color(0xFF00A8FF));

  static const PlatformBrand xhs = PlatformBrand(id: 'xhs', name: '小红书', color: Color(0xFFFF2442));

  static const PlatformBrand youtube = PlatformBrand(id: 'youtube', name: 'YouTube', color: Color(0xFFFF0000));

  /// pure_live 全量平台条目(`Sites.supportSites` 的其余各站),补齐
  /// lib/core/sites.dart:346 `_supportedSites` 的完整目录。
  ///
  /// - `id` = lib/core SiteIds 值:图标经 `Sites.logoForId(id)` 取
  ///   `assets/images/*.png`(部分站名不同,如 `pandalive` → panda.png、
  ///   `steambroadcast` → steam.png),id 与 SiteIds 对齐才能解析到素材。
  /// - `name` 取 assets/translations/zh.json 的 `site_*` 键值。
  /// - `color` 取 lib/modules/live_play/widgets/local_interaction/
  ///   local_interaction_controller.dart `platformPacks` 的同站
  ///   `accentColor`(pure_live 已有平台色系)。
  /// - `browseSupported` 按该站 LiveSite 是否 override `getCategores`:
  ///   未覆盖的站(liveme / tiktok / 17live)继承基类
  ///   lib/core/interface/live_site.dart:210 的空实现,置 false。
  ///   小红书沿用上方 `xhs` 条目(pure_live 侧 id 为 `xiaohongshu`)。
  static const PlatformBrand cc = PlatformBrand(id: 'cc', name: '网易CC', color: Color(0xFFFF4D7D));

  static const PlatformBrand acfun = PlatformBrand(id: 'acfun', name: 'AcFun 直播', color: Color(0xFFFD4C5D));

  static const PlatformBrand picarto = PlatformBrand(id: 'picarto', name: 'Picarto', color: Color(0xFF25BFA4));

  static const PlatformBrand twitcasting = PlatformBrand(
    id: 'twitcasting',
    name: 'TwitCasting',
    color: Color(0xFF294DDB),
  );

  static const PlatformBrand missevan = PlatformBrand(id: 'missevan', name: '猫耳 FM', color: Color(0xFFF38AAE));

  static const PlatformBrand inke = PlatformBrand(id: 'inke', name: '映客', color: Color(0xFFFF4F9A));

  static const PlatformBrand kilakila = PlatformBrand(id: 'kilakila', name: '克拉克拉', color: Color(0xFF7C5CFC));

  static const PlatformBrand niconico = PlatformBrand(id: 'niconico', name: 'niconico', color: Color(0xFF252525));

  static const PlatformBrand weibo = PlatformBrand(id: 'weibo', name: '微博直播', color: Color(0xFFFF8200));

  static const PlatformBrand showroom = PlatformBrand(id: 'showroom', name: 'SHOWROOM', color: Color(0xFFFF2B67));

  static const PlatformBrand chzzk = PlatformBrand(
    id: 'chzzk',
    name: 'CHZZK',
    color: Color(0xFF00FFA3),
    // 荧光绿亮底(同 yy / huya 的亮底约定),白字不可读,用深色字。
    chipForeground: chipForegroundDark,
  );

  static const PlatformBrand liveme = PlatformBrand(
    id: 'liveme',
    name: 'LiveMe',
    color: Color(0xFF7C4DFF),
    // LiveMeSite 未 override getCategores(基类空实现),不支持栏目浏览。
    browseSupported: false,
  );

  static const PlatformBrand tiktok = PlatformBrand(
    id: 'tiktok',
    name: 'TikTok LIVE',
    color: Color(0xFFFE2C55),
    // TikTokSite 未 override getCategores,不支持栏目浏览。
    browseSupported: false,
  );

  static const PlatformBrand bigo = PlatformBrand(id: 'bigo', name: 'Bigo Live', color: Color(0xFF6A5CFF));

  static const PlatformBrand pandalive = PlatformBrand(id: 'pandalive', name: 'PandaTV', color: Color(0xFFFE4D6A));

  static const PlatformBrand fc2live = PlatformBrand(id: 'fc2live', name: 'FC2 Live', color: Color(0xFFEA4C89));

  static const PlatformBrand steambroadcast = PlatformBrand(
    id: 'steambroadcast',
    name: 'Steam Broadcasts',
    color: Color(0xFF1B2838),
  );

  static const PlatformBrand jdlive = PlatformBrand(id: 'jdlive', name: '京东直播', color: Color(0xFFE1251B));

  static const PlatformBrand kugoulive = PlatformBrand(id: 'kugoulive', name: '酷狗直播', color: Color(0xFF19A7FF));

  static const PlatformBrand baidulive = PlatformBrand(id: 'baidulive', name: '百度直播', color: Color(0xFF2932E1));

  static const PlatformBrand sixroom = PlatformBrand(id: 'sixroom', name: '六间房直播', color: Color(0xFFFF5A5F));

  static const PlatformBrand looklive = PlatformBrand(id: 'looklive', name: 'LOOK 直播', color: Color(0xFFFF2C55));

  static const PlatformBrand seventeenLive = PlatformBrand(
    id: '17live',
    name: '17LIVE',
    color: Color(0xFFFF2D55),
    // SeventeenLiveSite 未 override getCategores,不支持栏目浏览。
    browseSupported: false,
  );

  static const PlatformBrand iptv = PlatformBrand(id: 'iptv', name: '网络', color: Color(0xFF00A2FF));

  static const bool realParserEnabled = bool.fromEnvironment('ZISHU_REAL_PARSER', defaultValue: false);

  /// 真实解析模式下按注册表的 browse 能力裁剪导航平台；同时要求实际
  /// 注册了 browse repository，避免「声明能力但不可用」的平台
  /// 出现在入口里。fixture 模式保留完整视觉目录，避免离线 UI 测试漂移。
  static List<PlatformBrand> get browsePlatforms => _platformsWith(
    (registration) => registration.capabilities.browse && registration.browse != null,
    requireBrowseSupport: true,
  );

  /// 搜索页按注册表的 search 能力裁剪平台筛选项；空实现(例如快手当前的
  /// 占位 search repository)不作为真实搜索入口暴露。
  ///
  /// 能力口径以 purelive 注册表为准,不受 `brand.browseSupported`(栏目浏览)
  /// 限制:17live 等无目录站有真搜索+链接直达(searchRooms 内建 URL 解析),
  /// 按 browseSupported 裁剪会把它们的搜索入口整块藏掉(用户口径
  /// 2026-10-02:直播地址相关能力映射完全以 purelive 为准)。
  static List<PlatformBrand> get searchPlatforms => _platformsWith(
    (registration) =>
        (registration.capabilities.roomSearch || registration.capabilities.anchorSearch) && registration.search != null,
    requireBrowseSupport: false,
  );

  static List<PlatformBrand> _platformsWith(
    bool Function(SiteRegistration registration) supported, {
    required bool requireBrowseSupport,
  }) => filterPlatforms(
    registry: buildSiteRegistry(),
    realParser: realParserEnabled,
    requireBrowseSupport: requireBrowseSupport,
    supported: supported,
  );

  /// 纯过滤逻辑(A11,可测):
  ///
  /// - `realParser: false`(fixture 构建)原样返回 [navPlatforms] 全量目录;
  /// - `realParser: true` 只保留「注册表有该站 && [supported] 能力为真 &&
  ///   (`requireBrowseSupport` 为假或品牌支持栏目浏览)」的站点 —— 浏览
  ///   入口要求 `registration.browse != null` 且品牌标了 browseSupported,
  ///   点击分类不会在 `ParserBrowseSource.fetchCategories` 抛
  ///   `StateError('站点 X 不支持分类浏览')`;搜索入口不设品牌位。
  @visibleForTesting
  static List<PlatformBrand> filterPlatforms({
    required SiteRegistry registry,
    required bool realParser,
    required bool requireBrowseSupport,
    required bool Function(SiteRegistration registration) supported,
  }) {
    if (!realParser) return navPlatforms;
    final result = <PlatformBrand>[all];
    for (final brand in navPlatforms.skip(1)) {
      final registration = registry[brand.id];
      if (registration != null && (!requireBrowseSupport || brand.browseSupported) && supported(registration)) {
        result.add(brand);
      }
    }
    return result;
  }

  /// 真实解析构建使用注册表的实际能力;fixture 构建保留完整导航目录。
  static List<PlatformBrand> get navigationPlatforms => _platformsWith(
    (registration) => registration.capabilities.browse && registration.browse != null,
    requireBrowseSupport: true,
  );

  static bool supportsBrowse(String site) => browsePlatforms.any((brand) => brand.id == site);

  static bool supportsSearch(String site) => searchPlatforms.any((brand) => brand.id == site);

  /// 平台是否支持**主播**搜索(昵称 / 抖音号),对齐 web
  /// `SearchDialog.vue:207` 的 `supportsAnchorSearch(site)`。
  ///
  /// 用于搜索弹框的「主播 / 房间」双档显隐:只支持房间搜索的平台
  /// 不出现主播档。
  static bool supportsAnchorSearch(String site) => _capabilitySearch(site, (c) => c.anchorSearch);

  /// 平台是否支持**房间**搜索(房间名 / 标题 / 房间号),对齐 web
  /// `SearchDialog.vue:208` 的 `supportsRoomSearch(site)`。
  static bool supportsRoomSearch(String site) => _capabilitySearch(site, (c) => c.roomSearch);

  /// 按能力位 + 是否注册了真实 search repository 判定。
  ///
  /// fixture 构建(离线 UI 测试)下与 [supportsSearch] 同口径放行:fixture
  /// 目录没有真实注册表,若此处收紧会让双档在测试里整块消失,失去覆盖。
  static bool _capabilitySearch(String site, bool Function(SiteCapabilities capabilities) test) {
    if (!realParserEnabled) return supportsSearch(site);
    final registration = buildSiteRegistry()[site];
    if (registration == null || registration.search == null) return false;
    return test(registration.capabilities);
  }

  /// 全量平台目录:前段为 zishu 精选位次(既有条目,位次不变),
  /// 追加段按 lib/core/sites.dart `_supportedSites` 的站点顺序排列。
  /// 真实解析构建下 [filterPlatforms] 会按注册表能力裁剪本表。
  static const List<PlatformBrand> navPlatforms = [
    all,
    douyu,
    huya,
    bilibili,
    douyin,
    yy,
    twitch,
    kuaishou,
    soop,
    xhs,
    youtube,
    cc,
    acfun,
    picarto,
    twitcasting,
    missevan,
    inke,
    kilakila,
    niconico,
    weibo,
    showroom,
    chzzk,
    liveme,
    tiktok,
    bigo,
    pandalive,
    fc2live,
    steambroadcast,
    jdlive,
    kugoulive,
    baidulive,
    sixroom,
    looklive,
    seventeenLive,
    iptv,
  ];

  static PlatformBrand? byId(String id) {
    for (final brand in navPlatforms) {
      if (brand.id == id) return brand;
    }
    return null;
  }
}
