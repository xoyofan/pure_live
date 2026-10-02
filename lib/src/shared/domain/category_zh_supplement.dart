/// fork 本地分类中文补充表(pure_live 全平台扩展,web 真源没有这些平台)。
///
/// 与 `packages/live_parser` 的 `kCategoryGroups`(生成文件,勿手改)和
/// `kCrossCategories`(assets/config 生成)互补:那两表覆盖 web 真源的四家 +
/// twitch/soop;本表只补 fork 独有平台的展示层中文,键取**稳定标识**
/// (TwitCasting 用目录 key,上游标签语言会随请求变;其余用小写标签),
/// 未命中返回 null(调用方继续走 remap/跨平台表/原名回退)。
///
/// 纯同步常量表,只被 [displayCategoryName] 这类同步渲染路径消费。
library;

/// TwitCasting 顶部目录 data-channel key → 中文(首页抓取 2026-10-02)。
const Map<String, String> kTwitcastingZhByCid = {
  '_system_channel_popular': '热门',
  '_system_channel_4': '萌音',
  '_system_channel_5': '音乐',
  '_system_channel_6': '帅声',
  '_system_channel_8': '女生',
  '_system_channel_9': '男生',
  '_system_channel_12': '游戏',
  '_system_new': '最新',
  '_system_beginner': '新人',
  '_system_call_engaged': '连麦中',
  '_system_paidcast': '付费直播',
  '_system_studio': '工作室直播',
  '_system_games_only': '休闲游戏',
  '_system_transcription': '字幕直播',
  'boys_face': '男生露脸',
  'girls_face': '女生露脸',
  'boys_healingvoice_jp': '治愈男声',
  'girls_healingvoice_jp': '治愈女声',
  'boys_goodvoice_jp': '男声好声音',
  'girls_cutevoice_jp': '女声甜音',
  'boys_talk_jp': '男生杂谈',
  'girls_talk_jp': '女生杂谈',
};

/// Picarto 分类标签(小写) → 中文(官方 categories API 全量 2026-10-02)。
const Map<String, String> kPicartoZhByName = {
  'creative': '创作',
  'furry': '兽人',
  'drawing': '绘画',
  'music': '音乐',
  'hentai': '限制级',
  'gaming': '游戏',
  'adult': '成人内容',
  'illustration': '插画',
  'anime': '动漫',
  'character design': '角色设计',
  'manga': '漫画',
  '3d modeling': '3D 建模',
  'nature & landscape': '自然风景',
  'animation': '动画',
  'comic': '美漫',
  'irl': '户外',
  'podcast': '播客',
  'video editing': '视频剪辑',
  'concept art': '概念设计',
  'design': '设计',
};

/// SHOWROOM genre 名(小写,服务端英文本地化) → 中文(onlives 全量 2026-10-02)。
const Map<String, String> kShowroomZhByName = {
  'popularity': '人气',
  'newcomer': '新人',
  'music': '音乐',
  'idol': '偶像',
  'talent': '才艺',
  'voice actor': '声优',
  'comedian': '搞笑',
  'virtual': '虚拟主播',
  'model': '模特',
  'actor': '演员',
  'announcer': '播音',
  'creator': '创作者',
  'streamer': '主播',
  "men's": '男生',
  'karaoke': '卡拉OK',
  'game': '游戏',
  'new1day': '新开1天',
  'new7day': '新开7天',
  'new30day': '新开30天',
};

/// SOOP 目录英文名(小写) → 中文,只收 web 真源 remap 表未覆盖的热门项
/// (上游 2026-10 已撤 zh_CN 本地化,数据层取英文名,见 SoopSite.getHeaders;
/// remap 覆盖项不重复收录,长尾未命中回落英文)。
const Map<String, String> kSoopZhByName = {
  'virtual': '虚拟主播',
  'starcraft: remastered': '星际争霸：重制版',
  'starcraft ii': '星际争霸II',
  'sudden attack': '突击风暴',
  'travel': '旅行',
  'music/dance': '音乐/舞蹈',
  'zeus: god of pride': '宙斯：傲慢之神',
  'maple story': '冒险岛',
  'mukbang': '吃播',
  'fitness/workout': '健身运动',
  'music streaming': '音乐电台',
  'hobbies': '兴趣爱好',
  'lost ark': '命运方舟',
  'fishing/outdoor': '钓鱼/户外',
  'cryptocurrency': '加密货币',
  'dubbing/radio': '配音/电台',
  'international football': '国际足球',
  'korean professional soccer': '韩国职业足球',
  'baseball neutral': '棒球转播',
  'all mobile games': '全部手游',
  'stocks': '股票',
  'lineage': '天堂',
  'lineage classic': '天堂Classic',
  'the great merchant': '巨商',
  'headlines': '头条',
  'fortune': '占卜运势',
  'heroes of the storm': '风暴英雄',
  'diablo ii': '暗黑破坏神2',
  'diablo iii': '暗黑破坏神3',
  'talk/analysis': '谈话/分析',
  'amateur baseball': '业余棒球',
  'freestyle street basketball': '街头篮球',
  'limbus company': '边狱公司',
  'talesrunner': '超级跑跑',
  'religion': '宗教',
  'valheim': '英灵神殿',
};

/// Twitch 一级分组标签(SearchCategoryTags,小写) → 中文。
/// 二级分类名走 `remapCategoryName` 的 web 真源表;此处只补分组标签
/// (web 真源未收录,40 个全量收录)。
const Map<String, String> kTwitchGroupZhByName = {
  'adventure game': '冒险游戏',
  'party': '派对',
  'fps': '第一人称射击',
  'driving/racing game': '竞速游戏',
  'shooter': '射击',
  'gambling': '博彩',
  'card & board game': '卡牌桌游',
  'strategy': '策略',
  'fighting': '格斗',
  'stealth': '潜行',
  'game overlay': '游戏插件',
  'horror': '恐怖',
  'creative': '创意',
  '4x': '4X 策略',
  'educational game': '教育游戏',
  "shoot 'em up": '弹幕射击',
  'rpg': '角色扮演',
  'puzzle': '解谜',
  'simulation': '模拟',
  'moba': 'MOBA',
  'mystery': '悬疑',
  'irl': '户外',
  'survival': '生存',
  'metroidvania': '类银河恶魔城',
  'arcade': '街机',
  'action': '动作',
  'rhythm & music game': '节奏音乐',
  'indie game': '独立游戏',
  'flight simulator': '飞行模拟',
  'pinball': '弹球',
  'gambling game': '博彩游戏',
  'open world': '开放世界',
  'rts': '即时战略',
  'hidden objects': '找物解谜',
  'mobile game': '手游',
  'roguelike': '肉鸽',
  'point and click': '点击解谜',
  'platformer': '平台跳跃',
  'sports game': '体育游戏',
  'visual novel': '视觉小说',
  'mmo': '大型多人在线',
};

/// 查询键归一:trim + 小写(保留词内空格,键侧做同一归一)。
String _normalize(String? text) => (text ?? '').trim().toLowerCase();

final Map<String, String> _picartoZh = {
  for (final entry in kPicartoZhByName.entries) _normalize(entry.key): entry.value,
};

final Map<String, String> _showroomZh = {
  for (final entry in kShowroomZhByName.entries) _normalize(entry.key): entry.value,
};

final Map<String, String> _twitchGroupZh = {
  for (final entry in kTwitchGroupZhByName.entries) _normalize(entry.key): entry.value,
};

final Map<String, String> _twitcastingLabelZh = {
  for (final entry in kTwitcastingLabelFallback.entries) _normalize(entry.key): entry.value,
};

final Map<String, String> _soopZh = {for (final entry in kSoopZhByName.entries) _normalize(entry.key): entry.value};

/// fork 补充表中文名:TwitCasting 按稳定 cid 反查(标签语言不稳),
/// picarto/showroom 按 小写标签,twitch 一级分组标签,soop 补 remap 未覆盖项;
/// 未命中返回 null。
String? zhSupplementCategoryName(String? site, String? cid, String? name) {
  switch ((site ?? '').trim()) {
    case 'twitcasting':
      final cidKey = (cid ?? '').trim();
      if (cidKey.isNotEmpty) {
        final byCid = kTwitcastingZhByCid[cidKey];
        if (byCid != null) return byCid;
      }
      // 上游改版换 key 时按小写标签兜底(标签随请求语言变,仅作次选)。
      return _twitcastingLabelZh[_normalize(name)];
    case 'picarto':
      return _picartoZh[_normalize(name)];
    case 'showroom':
      return _showroomZh[_normalize(name)];
    case 'twitch':
      return _twitchGroupZh[_normalize(name)];
    case 'soop':
      return _soopZh[_normalize(name)];
    default:
      return null;
  }
}

/// TwitCasting 标签兜底表:cid 查不到(上游改版换 key)时按小写标签反查。
const Map<String, String> kTwitcastingLabelFallback = {
  'popular': '热门',
  'kawavo': '萌音',
  'music': '音乐',
  'ikebo': '帅声',
  'girls': '女生',
  'guys': '男生',
  'game': '游戏',
  'recent': '最新',
  'debut': '新人',
  'on collabo': '连麦中',
  'premier live': '付费直播',
  'studio streaming': '工作室直播',
  'twitcast games': '休闲游戏',
  'with live captions': '字幕直播',
  'soothing vo.': '治愈女声',
  'kawabo': '女声甜音',
  'streamers on cam.': '露脸',
};
