/// 侧栏抽屉与顶部平台 hover 浮层**共用**的一级分区 + 二级分类构建逻辑
/// (移植 zishu 真源 `lib/src/shared/domain/category_sections.dart`,
/// 模型适配为本仓 `LiveCategory`/`LiveArea`;真源同文件注释原文:「抽屉
/// (首页左侧边栏)与顶部导航 hover 浮层共用」)。
///
/// 用户口径(2026-10-01):douyin 顶栏 hover 分类要与侧栏对齐,侧栏显示
/// 与 hover 一致的全部分类 —— 两处同一入口 [buildCategorySections],
/// **不设每区条数上限**。
///
/// 真源行为:[normalizeDrawerCategoryGroups] 按 site 归一(douyin 按 id
/// 序排;douyu/huya 先滤掉分组名匹配 颜值|正能量|语音|科技文化 的组与
/// 空组再按 id 序排;其余平台原样)→ [buildCategorySections] 滤空组出
/// sections;[isFlatCategoryGroups] 判定单组平台(twitch/soop/快手等)
/// 平铺无组标题。
///
/// id 形态差异:本仓 douyin_site 的分组 id 是复合串 `'{id_str},{type}'`
/// (见 `lib/core/site/douyin/douyin_site.dart` 的 getCategores,数据层
/// 不改),rank 匹配取**逗号前段**比对;真源 douyin 的 'yule'(娱乐大区,
/// 真源解析层合成的 id)本仓没有合成组,按组名「娱乐」等效映射到
/// 'yule' 的 rank(见 [_drawerGroupRank])。斗鱼/虎牙分组 id 为纯数字串,
/// 逗号前段比对与其全串等价。
///
/// 纯函数、无 IO,数据来自 `AreasListController.categories`(当前站点
/// 真实目录),由侧栏(`_SidebarHotCategories`)与浮层
/// (`ZishuPlatformCategoryFlyout`)共用。
library;

import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/model/live_category.dart';

/// 不展示的非游戏一级分区(对齐真源 `_kDrawerExcludedGroup`)。
final RegExp _kDrawerExcludedGroup = RegExp(r'颜值|正能量|语音|科技文化');

/// 一级分区排序(其余非排除分区排在后面;按平台原生一级 id)。
const Map<String, List<String>> _kDrawerGroupOrder = {
  'douyu': ['1', '15', '9', '22', '2'],
  'huya': ['1', '3', '8', '2'],
  'douyin': ['1', '2', '3', '4', '5', '6', '7', 'yule'],
};

/// 不在排序表内的分组统一追加在尾部(真源同款哨兵 rank)。
const int _kDrawerRankFallback = 999;

/// 组在排序表中的 rank:分组 id 取**逗号前段**比对(适配本仓 douyin
/// 复合 id `'{id_str},{type}'`);douyin 的「娱乐」组在本仓无 'yule'
/// 合成 id 的现实下按组名等效映射到 'yule' 的 rank(文件头注释)。
/// 不在表内 → [_kDrawerRankFallback]。
int _drawerGroupRank(String site, LiveCategory group) {
  final order = _kDrawerGroupOrder[site];
  if (order == null) return _kDrawerRankFallback;
  final idPrefix = group.id.split(',').first.trim();
  for (var i = 0; i < order.length; i++) {
    if (order[i] == idPrefix) return i;
  }
  if (site == 'douyin' && group.name.trim() == '娱乐') {
    final yule = order.indexOf('yule');
    if (yule >= 0) return yule;
  }
  return _kDrawerRankFallback;
}

/// 过滤非游戏一级分区与空组(对齐真源 `filterDrawerCategoryGroups`)。
List<LiveCategory> filterDrawerCategoryGroups(List<LiveCategory> groups) => [
  for (final group in groups)
    if (!_kDrawerExcludedGroup.hasMatch(group.name) && group.children.isNotEmpty) group,
];

/// 一级分区排序:douyu/huya/douyin 按 [_kDrawerGroupOrder],组内同序号
/// 按组名序;无排序表的平台保持原序(对齐真源 `sortDrawerCategoryGroups`)。
List<LiveCategory> sortDrawerCategoryGroups(String site, List<LiveCategory> groups) {
  if (!_kDrawerGroupOrder.containsKey(site) || _kDrawerGroupOrder[site]!.isEmpty) return groups;
  final sorted = List<LiveCategory>.of(groups)
    ..sort((a, b) {
      final left = _drawerGroupRank(site, a);
      final right = _drawerGroupRank(site, b);
      if (left != right) return left - right;
      return a.name.compareTo(b.name);
    });
  return sorted;
}

/// 斗鱼/虎牙/抖音:过滤并排序;其余平台原样返回(对齐真源
/// `normalizeDrawerCategoryGroups`)。
List<LiveCategory> normalizeDrawerCategoryGroups(String site, List<LiveCategory> groups) {
  if (site == 'douyin') return sortDrawerCategoryGroups(site, groups);
  if (site != 'douyu' && site != 'huya') return groups;
  return sortDrawerCategoryGroups(site, filterDrawerCategoryGroups(groups));
}

/// 平台只有一个大组(twitch/soop/快手等无一级分区结构)→ 隐藏组标题
/// 平铺渲染(对齐真源 `isFlatCategoryGroups`)。
bool isFlatCategoryGroups(List<LiveCategory> groups) => groups.length == 1;

/// 一级分区:组名(一级分类)+ 该组下的二级分类条目(真源
/// `CategorySection` 同构,模型为本仓 [LiveArea])。
class ZishuCategorySection {
  const ZishuCategorySection({required this.id, required this.name, required this.items});

  /// 平台原生一级分区 id(保留原始形态,含 douyin 复合串)。
  final String id;

  /// 一级分区名。
  final String name;

  /// 二级分类条目(不限条数,直接引用目录组的 children)。
  final List<LiveArea> items;
}

/// 一级分区 + 二级分类列表(侧栏 / 顶栏浮层共用同一入口,对齐真源
/// `buildCategorySections`:滤空组后逐组出 section)。
List<ZishuCategorySection> buildCategorySections(String site, List<LiveCategory> groups) {
  final normalized = normalizeDrawerCategoryGroups(site, groups);
  return [
    for (final group in normalized)
      if (group.children.isNotEmpty) ZishuCategorySection(id: group.id, name: group.name.trim(), items: group.children),
  ];
}
