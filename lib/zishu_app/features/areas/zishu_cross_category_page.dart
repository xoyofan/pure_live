import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_binding.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu_app/features/browse/zishu_browse_view.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_top_bar.dart';

/// 跨平台分类页(移植 zishu 真源 `/all/category/:key`,即
/// `CategoryView(site: 'all', categoryKey:)` 命中具体分类后的纯房间形态,
/// 对齐 web `all-category-rooms`):给定跨平台 key(如 `lol`),聚合所有
/// 可见平台(`savedPlatformIds` 顶栏同源口径)中映射到该跨平台分类的
/// 各站分类房间,交错混排进一张网格(真源 `CrossBrowseRepository` 默认
/// `CrossMergeMode.interleaved`),卡片复用 [ZishuRoomCard]
/// ([ZishuBrowseGrid] 即 zishu browse 目录的网格,自带平台角标)。
///
/// 数据编排对齐真源 `CrossBrowseRepository.fetchRooms` 的 per-site 桶:
/// - crossKey 反查各站分类:真源先 `siteCids` 白名单原生 cid 直拉、再按名
///   归一兜底(soop 韩文名经静态表桥接中文);我方目录数据在
///   `AreasListController(tag=siteId)`(LiveArea 带 areaType 等平台原生
///   字段,B 站 `parent_area_id` 就靠它),故按**目录反查**落地 —— 每站
///   目录展开子分类,`crossKeyForPlatformCategory` 命中目标 key(经
///   `crossCategoryKeysEqual` alias 归一;soop 走韩文名静态表桥接)即取
///   该 LiveArea,交给 `AreaRoomsBinding.createController` 拉房(与
///   kAreaRooms 路由同一数据管线);
/// - 单站未命中/目录失败即该站空缺,不拖垮其余平台(真源 per-site 失败
///   隔离同口径);全部空缺给空态;
/// - 加载更多:滚动近底对「还有余量」的站并发 `loadMoreData`,交错合并
///   随各站 list 到位原位补齐。
class ZishuCrossCategoryPage extends StatefulWidget {
  const ZishuCrossCategoryPage({super.key, required this.crossKey});

  /// 跨平台分类 key(路由参数;旧 key 经 `resolveCrossCategoryKey` 归一)。
  final String crossKey;

  @override
  State<ZishuCrossCategoryPage> createState() => _ZishuCrossCategoryPageState();
}

class _ZishuCrossCategoryPageState extends State<ZishuCrossCategoryPage> {
  /// 滚动近底提前量:剩 600px 起并发补页(一屏卡片高度的量级)。
  static const double _loadMoreAheadExtent = 600;

  /// 每可见平台一个房间桶(站点 + 该站分类房间流控制器)。控制器由
  /// `AreaRoomsBinding.createController` 产出,State 直接持实例不经 GetX
  /// 注册(避免与路由 binding 的同名 tag 相互覆盖,与
  /// `ZishuAreasView._SiteAreasPaneState` 的分类详情控制器同款处理),
  /// 销毁走 [onDelete](GetX 生命周期链)。
  final List<({Site site, BasePageScrollAndStateBone<LiveRoom> controller})> _buckets = [];

  /// 目录反查进行中(首帧占位)。
  bool _resolving = true;

  /// 合并网格的补页中标记(Rx:加载尾随其出现/消失)。
  final RxBool _loadingMore = false.obs;

  final ScrollController _scrollController = ScrollController();

  /// 展示名:命中映射用 canonical 中文名,否则回落归一后的 key。
  String get _displayName {
    final entry = findCrossCategoryByKey(widget.crossKey);
    final name = entry?.name ?? resolveCrossCategoryKey(widget.crossKey);
    return name.isEmpty ? widget.crossKey : name;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_resolveBuckets());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final bucket in _buckets) {
      bucket.controller.onDelete();
    }
    _buckets.clear();
    super.dispose();
  }

  /// 逐站反查目录并起各站首屏(串行,复用 [visibleTopBarSites] 的
  /// savedPlatformIds 顺序;桶随命中逐个出现,首屏不互相等待)。
  Future<void> _resolveBuckets() async {
    final targetKey = resolveCrossCategoryKey(widget.crossKey);
    for (final site in visibleTopBarSites()) {
      if (!mounted) return;
      final area = await _matchSiteArea(site, targetKey);
      if (area == null) continue;
      if (!mounted) return;
      final controller = AreaRoomsBinding.createController(site, area);
      setState(() => _buckets.add((site: site, controller: controller)));
      unawaited(controller.refreshData());
    }
    if (mounted) setState(() => _resolving = false);
  }

  /// crossKey 反查该站匹配的 LiveArea:目录未注册按 warmup 同参补注册
  /// (lazyPut fenix,AreasController 之后初始化直接复用同一份),目录为空
  /// 先 `loadData()`(幂等,进行中复用同一 Future);子分类逐条按跨平台
  /// key 归一比对。失败/未命中返回 null(该站本轮空缺)。
  Future<LiveArea?> _matchSiteArea(Site site, String targetKey) async {
    try {
      if (!Get.isRegistered<AreasListController>(tag: site.id)) {
        Get.lazyPut(() => AreasListController(site), tag: site.id, fenix: true);
      }
      final catalog = Get.find<AreasListController>(tag: site.id);
      if (catalog.categories.isEmpty) {
        await catalog.loadData();
      }
      for (final group in catalog.categories) {
        for (final area in group.children) {
          final key = crossKeyForPlatformCategory(site.id, area.areaId, area.areaName);
          if (crossCategoryKeysEqual(key, targetKey)) return area;
        }
      }
    } catch (_) {
      // 目录拉取失败按该站空缺隔离,不阻塞其余平台。
    }
    return null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > _loadMoreAheadExtent) return;
    unawaited(_loadMoreAll());
  }

  /// 对还有余量的站并发补页;`loadMoreData` 自带 `loadding` 防重入,
  /// 这里再挡一层避免滚动连发叠加。
  Future<void> _loadMoreAll() async {
    if (_loadingMore.value || _buckets.isEmpty) return;
    final targets = [
      for (final bucket in _buckets)
        if (bucket.controller.canLoadMore.value) bucket.controller,
    ];
    if (targets.isEmpty) return;
    _loadingMore.value = true;
    try {
      await Future.wait([for (final controller in targets) controller.loadMoreData()]);
    } finally {
      _loadingMore.value = false;
    }
  }

  /// 全站回到第一页(空态重试/下拉刷新同一条路)。
  Future<void> _refreshAll() async {
    await Future.wait([for (final bucket in _buckets) bucket.controller.refreshData()]);
  }

  /// 交错混排(真源 `CrossMergeMode.interleaved`):各站轮流取一条,
  /// 单站不满位由其余站补齐,首页不被单一平台霸屏。
  List<LiveRoom> _mergeInterleaved() {
    final merged = <LiveRoom>[];
    final cursors = List<int>.filled(_buckets.length, 0);
    var remaining = true;
    while (remaining) {
      remaining = false;
      for (var i = 0; i < _buckets.length; i++) {
        final bucket = _buckets[i].controller.list;
        if (cursors[i] < bucket.length) {
          merged.add(bucket[cursors[i]++]);
          remaining = true;
        }
      }
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(_displayName)),
      body: Obx(() {
        // 读补页标记保证加载尾随其出现/消失;各站 list 在下方混排时读取,
        // 数据到位/追加都会触发本 Obx 原位重建。
        final loadingMore = _loadingMore.value;
        if (_resolving && _buckets.isEmpty) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (_buckets.isEmpty) {
          // 全部可见平台都未命中该跨平台分类:空态 + 刷新(重跑反查)。
          return Center(
            child: zishu.EmptyView(
              icon: Icons.category_rounded,
              message: i18n('empty_areas_title'),
              action: zishu.RetryButton(
                label: i18n('refresh'),
                onRetry: () {
                  setState(() => _resolving = true);
                  unawaited(_resolveBuckets());
                },
              ),
            ),
          );
        }
        final merged = _mergeInterleaved();
        final anyLoading = _buckets.any((bucket) => bucket.controller.loadding.value);
        if (merged.isEmpty && anyLoading) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (merged.isEmpty) {
          return Center(
            child: zishu.EmptyView(
              icon: Icons.live_tv_rounded,
              message: i18n('empty_live_title'),
              action: zishu.RetryButton(label: i18n('refresh'), onRetry: () => unawaited(_refreshAll())),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refreshAll,
          color: tokens.accent,
          child: ZishuBrowseGrid(
            rooms: merged,
            scrollController: _scrollController,
            loadingMore: loadingMore && anyLoading,
          ),
        );
      }),
    );
  }
}
