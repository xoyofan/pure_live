import 'dart:async';
import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card_skeleton.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_top_bar.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

/// 全平台首页(顶栏「全平台」入口 / nav-home):一张交错混排网格。
///
/// 对齐 zishu 真源 738673d「全平台首页回到交错混排网格,首屏骨架与按
/// 首屏容量的每平台请求量」:
/// - **请求量**:按当前视口算「首屏能容纳多少张卡」(列数 × 首屏行数,
///   见 [zishuAllHomeFirstScreenCapacity]),作为**每个平台**的单页请求量
///   (调用侧传 limit,对齐真源聚合查询 limit 参与口径;控制器侧的
///   容量端口以容量估算轨为准,本轨只做 UI 与数据编排);
/// - **交错规则**:各平台结果按桶**按索引轮转**合并(第 i 轮各站取一条,
///   真源 `CrossBrowseRepository._merge` 同款),部分平台失败只空缺该站,
///   全部失败才整页报错;
/// - **骨架**:首屏加载中显示与真实卡等大的骨架卡(数量 = 首屏容量,
///   真源 home_view `_skeletonBody` 同款),不再空白/转圈;
/// - **滚动加载**:滚到底按同一交错规则补各平台下一页,追加在列表尾
///   (真源 loadMore `[...current.rooms, ...next.rooms]` 同语义)。
///
/// 卡片复用 [ZishuRoomCard],点击行为与单站首页一致(默认进播放页);
/// 本页不接 BasePageView(它绑定单控制器),刷新走 F5(壳层分发)与
/// 错误/空态重试按钮。
class ZishuAllHomeView extends StatefulWidget {
  const ZishuAllHomeView({super.key});

  @override
  State<ZishuAllHomeView> createState() => _ZishuAllHomeViewState();
}

class _ZishuAllHomeViewState extends State<ZishuAllHomeView> {
  ZishuAllPlatformController? _controller;

  /// 已请求过的首屏容量(骨架张数与重拉判定共用)。
  int _requestedCapacity = 0;

  ZishuAllPlatformController _resolveController() {
    if (!Get.isRegistered<ZishuAllPlatformController>()) {
      Get.put(ZishuAllPlatformController());
    }
    return Get.find<ZishuAllPlatformController>();
  }

  @override
  void initState() {
    super.initState();
    _controller = _resolveController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFirstScreen();
  }

  /// 首帧与窗口尺寸变化:重算首屏容量,变化即(重)拉首屏 —— 对齐真源
  /// limit 参与 query 相等性、视口变化触发聚合重查的语义。
  void _ensureFirstScreen() {
    final capacity = zishuAllHomeFirstScreenCapacity(context);
    if (capacity == _requestedCapacity) return;
    _requestedCapacity = capacity;
    // 不在 build/didChangeDependencies 期间触发 Rx 写入,一帧后装载。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_controller!.ensureLoaded(capacity));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    return Obx(() {
      final loading = controller.firstLoading.value;
      final allFailed = controller.allFailed.value;
      final rooms = controller.rooms;
      final loadingMore = controller.loadingMore.value;
      if (loading) {
        // 首屏骨架:数量 = 首屏容量,几何与真实网格同源。
        return _ZishuAllHomeSkeletonGrid(count: _requestedCapacity);
      }
      if (allFailed) {
        return zishu.EmptyView(
          icon: Icons.cloud_off_rounded,
          message: i18n('error_network'),
          action: zishu.RetryButton(label: i18n('retry'), onRetry: () => unawaited(controller.refreshAll())),
        );
      }
      if (rooms.isEmpty) {
        return zishu.EmptyView(
          icon: Icons.live_tv_rounded,
          message: i18n('empty_live_title'),
          action: zishu.RetryButton(label: i18n('refresh'), onRetry: () => unawaited(controller.refreshAll())),
        );
      }
      return _ZishuAllHomeGrid(
        rooms: rooms,
        loadingMore: loadingMore,
        onLoadMore: () => unawaited(controller.loadMore()),
      );
    });
  }
}

/// 首屏容量:列数 × 首屏行数(真源 `_HomeViewState._firstScreenCapacity`
/// 同款公式)。列数与卡片格高与房间网格**同源**([AppRoomGrid.columnsFor] +
/// `cardWidth * 9/16 + metaHeightFor(roomGridMetaBudget)`),否则请求量与
/// 实际能放下的卡片数不匹配。宽高取 MediaQuery 视口(真源同口径:列数只
/// 跟视口宽走,桌面常驻侧栏时卡片按容器均分自然收窄)。
int zishuAllHomeFirstScreenCapacity(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final columns = AppRoomGrid.columnsFor(size.width);
  const padding = AppSpacing.lg * 2;
  final cardWidth = (size.width - padding - AppSpacing.gridCrossAxisSpacing * (columns - 1)) / columns;
  final cardHeight = cardWidth * 9 / 16 + metaHeightFor(roomGridMetaBudget, context);
  final rows = math.max(1, (size.height / cardHeight).ceil());
  return columns * rows;
}

/// 首屏骨架网格:列数/间距/格高与混排网格严格同源,数量 = 首屏容量
/// (真源 home_view `_skeletonBody` 同款,锚点 key 同名)。
class _ZishuAllHomeSkeletonGrid extends StatelessWidget {
  const _ZishuAllHomeSkeletonGrid({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final columns = AppRoomGrid.columnsFor(viewportWidth);
        final available = constraints.maxWidth - AppSpacing.lg * 2;
        final cardWidth = (available - AppSpacing.gridCrossAxisSpacing * (columns - 1)) / columns;
        return GridView.builder(
          key: const Key('home-skeleton-grid'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.gridMainAxisSpacing,
            crossAxisSpacing: AppSpacing.gridCrossAxisSpacing,
            childAspectRatio: cardWidth / (cardWidth * 9 / 16 + metaHeightFor(roomGridMetaBudget, context)),
          ),
          itemCount: count,
          itemBuilder: (context, index) => RoomCardSkeleton(key: Key('home-skeleton-$index')),
        );
      },
    );
  }
}

/// 交错混排网格:几何与单站首页的 ZishuBrowseGrid 同口径(视口定列、
/// lg 网格 padding、16/13.6 间距、16:9 + 58px 元信息预算),滚动接近底部
/// 触发 [ZishuAllHomeGrid.onLoadMore](防重入在控制器),加载中在末尾渲染
/// 加载 footer。
class _ZishuAllHomeGrid extends StatefulWidget {
  const _ZishuAllHomeGrid({required this.rooms, required this.loadingMore, required this.onLoadMore});

  final List<LiveRoom> rooms;
  final bool loadingMore;
  final VoidCallback onLoadMore;

  @override
  State<_ZishuAllHomeGrid> createState() => _ZishuAllHomeGridState();
}

class _ZishuAllHomeGridState extends State<_ZishuAllHomeGrid> {
  final ScrollController _scrollController = ScrollController();

  /// 接近底部该距离内即触发加载更多(真源 RoomGrid `_loadMoreThreshold` 同款)。
  static const double _loadMoreThreshold = 400;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.loadingMore &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < _loadMoreThreshold) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppRoomGrid.columnsFor(MediaQuery.sizeOf(context).width);
        const crossSpacing = AppSpacing.gridCrossAxisSpacing;
        const mainSpacing = AppSpacing.gridMainAxisSpacing;
        final gridWidth = constraints.maxWidth - 2 * AppSpacing.lg;
        final cardWidth = (gridWidth - (columns - 1) * crossSpacing) / columns;
        final aspectRatio = cardWidth / (cardWidth * 9 / 16 + metaHeightFor(58, context));
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: widget.rooms.length + (widget.loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= widget.rooms.length) return const _ZishuAllHomeLoadingMoreFooter();
            return ZishuRoomCard(
              key: ValueKey('${widget.rooms[index].platform}:${widget.rooms[index].roomId}'),
              room: widget.rooms[index],
            );
          },
        );
      },
    );
  }
}

/// 网格末尾加载 footer:accent 环 + 「加载中」文案(与单站首页
/// `_ZishuLoadingMoreFooter` 同视觉)。
class _ZishuAllHomeLoadingMoreFooter extends StatelessWidget {
  const _ZishuAllHomeLoadingMoreFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: AppSpacing.lg,
            height: AppSpacing.lg,
            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(i18n('refresh_loading'), style: context.textCaption),
        ],
      ),
    );
  }
}

/// 单平台聚合分桶:游标、是否还有下一页、上一轮是否失败、已见房间去重、
/// 本轮取到的房间(交错前暂存)。
class _SiteBucket {
  int page = 0;
  bool hasMore = true;
  bool failed = false;
  List<LiveRoom> rooms = const <LiveRoom>[];
  final Set<String> seen = <String>{};
}

/// 全平台聚合控制器:UI 之外的数据编排层 —— 各可见平台并行请求 +
/// 交错合并 + 分页追加。不碰单站分页控制器(`BasePageScrollAndStateBone`
/// 家族),直接经 [Site.liveSite] 取数并把每平台单页请求量(首屏容量)
/// 作为 limit 下发(调用侧传 limit 口径)。
class ZishuAllPlatformController extends GetxController {
  /// 首屏请求在途(骨架期)。
  final RxBool firstLoading = false.obs;

  /// 追加页请求在途(尾部 footer)。
  final RxBool loadingMore = false.obs;

  /// 交错混排后的展示列表。
  final RxList<LiveRoom> rooms = <LiveRoom>[].obs;

  /// 本轮所有平台请求全部失败(整页错误态);部分失败只空缺该站,不置位。
  final RxBool allFailed = false.obs;

  /// 单轮跨平台并发分块(真源 cross_browse 同款,避免同时打出全部平台请求)。
  static const int _fetchConcurrency = 4;

  /// 各站分桶(键 = 站点 id,插入序 = 展示轮转序)。
  final Map<String, _SiteBucket> _buckets = {};

  /// 参与聚合的平台快照(savedPlatformIds 顺序,装载时定格)。
  List<Site> _sites = const <Site>[];

  /// 每平台单页请求量(首屏容量,由视图按视口估算后经 [ensureLoaded] 传入)。
  int _capacity = 0;

  /// 代数:刷新使在途旧响应作废。
  int _generation = 0;

  /// 是否已完成过一次首屏装载(成功/空/全失败均算)。
  bool _attempted = false;

  /// 首屏在途期间到达的最新容量:本轮结束后按它裁决是否按新容量重拉
  /// (窗口尺寸变化不因在途而丢失)。
  int? _pendingCapacity;

  /// 参与轮转的平台 id 序(调试/测试锚点)。
  List<String> get siteOrder => _sites.map((site) => site.id).toList(growable: false);

  /// 首屏装载入口:容量变化即重拉(对齐真源 limit 参与 query 相等性、
  /// 视口变化触发重查);同容量且已有结果则幂等复用。
  Future<void> ensureLoaded(int capacity) async {
    if (firstLoading.value) {
      _pendingCapacity = capacity;
      return;
    }
    if (_attempted && _capacity == capacity) return;
    await _loadFirstScreen(capacity);
  }

  /// F5 / 重试:按上次容量整页重拉(壳层刷新分发与错误态按钮共用)。
  Future<void> refreshAll() async {
    if (_capacity < 1 || firstLoading.value) return;
    await _loadFirstScreen(_capacity);
  }

  Future<void> _loadFirstScreen(int capacity) async {
    final generation = ++_generation;
    _capacity = capacity;
    _sites = visibleTopBarSites();
    _buckets.clear();
    for (final site in _sites) {
      _buckets[site.id] = _SiteBucket();
    }
    firstLoading.value = true;
    allFailed.value = false;
    final merged = await _fetchRound(_sites, generation);
    if (generation != _generation || isClosed) return;
    firstLoading.value = false;
    _attempted = true;
    allFailed.value = _sites.isNotEmpty && _buckets.values.every((bucket) => bucket.failed);
    rooms.assignAll(merged);
    // 在途期间到达的新容量:不等价则立刻按新容量重拉一轮。
    final pending = _pendingCapacity;
    _pendingCapacity = null;
    if (pending != null && pending != capacity) {
      await _loadFirstScreen(pending);
    }
  }

  /// 滚动到底:给还有下一页的平台各取一页,交错后**追加在列表尾**
  /// (真源 loadMore `[...current.rooms, ...next.rooms]` 同语义,追加段
  /// 自身是本轮各桶的轮转混排)。防重入;全部平台无更多后为空操作。
  /// 上轮失败的站 hasMore 仍为 true,下一轮自动重试(真源每轮全目标
  /// 重试同口径)。
  Future<void> loadMore() async {
    if (firstLoading.value || loadingMore.value || rooms.isEmpty) return;
    final pending = [
      for (final site in _sites)
        if (_buckets[site.id]!.hasMore) site,
    ];
    if (pending.isEmpty) return;
    final generation = _generation;
    loadingMore.value = true;
    final merged = await _fetchRound(pending, generation);
    // 先落 loadingMore 再判代数:中途被刷新作废时也要复位,否则 footer
    // 常驻、后续 loadMore 永久短路。
    loadingMore.value = false;
    if (generation != _generation || isClosed) return;
    if (merged.isNotEmpty) rooms.addAll(merged);
  }

  /// 取一轮:分块并发拉 [targets] 各自的下一页(每平台条数 = 容量),
  /// 交错合并。失败站本轮空缺(隔离),全部失败返回空表,由调用方依场景
  /// 决定整页错误(首屏)还是静默保留旧列表(追加)。
  Future<List<LiveRoom>> _fetchRound(List<Site> targets, int generation) async {
    for (var offset = 0; offset < targets.length; offset += _fetchConcurrency) {
      final chunk = targets.skip(offset).take(_fetchConcurrency);
      await Future.wait([for (final site in chunk) _fetchSite(site, generation)]);
      if (generation != _generation || isClosed) return const <LiveRoom>[];
    }
    final buckets = [for (final site in targets) _buckets[site.id]!.rooms];
    return _interleave(buckets);
  }

  Future<void> _fetchSite(Site site, int generation) async {
    final bucket = _buckets[site.id]!;
    try {
      final fetched = await site.liveSite.getRecommendRooms(page: bucket.page + 1, pageSize: _capacity);
      if (generation != _generation || isClosed) return;
      // 热门排序与单站首页同一策略(视觉在线人数设置生效;iptv 本地列表
      // 不重排,对齐 PopularLocalReactiveController 口径)。
      final ranked = site.id == Sites.iptvSite
          ? fetched
          : rankPopularRoomsByAudience(
              fetched,
              preferRealOnline: SettingsService.to.app.preferRealOnlineCounts.v,
              realOnlinePlatforms: SettingsService.to.app.realOnlinePlatforms,
            );
      // 平台内跨页去重(本仓分页控制器同口径:分页不稳定的站点不重复出卡)。
      final fresh = <LiveRoom>[];
      for (final room in ranked) {
        if (bucket.seen.add(room.identityKey)) fresh.add(room);
      }
      bucket.page++;
      bucket.failed = false;
      // LiveSite 只返回列表没有 hasMore:沿用本仓分页控制器口径 —— 取满
      // 请求量视为可能还有更多;空列表或去重后无新增视为枯竭。
      bucket.hasMore = fresh.length >= _capacity;
      bucket.rooms = fresh;
    } catch (_) {
      if (generation != _generation || isClosed) return;
      // 单平台失败隔离:该站本轮空缺,其余平台照常(真源 cross_browse 同款);
      // hasMore 保持原值,下一轮 loadMore 自动重试。
      bucket.failed = true;
    }
  }

  /// 交错合并:按桶**按索引轮转**逐条取(第 i 轮各站取一条,真源
  /// `CrossBrowseRepository._merge` 同款;失败/枯竭站本轮空缺)。
  List<LiveRoom> _interleave(List<List<LiveRoom>> buckets) {
    final merged = <LiveRoom>[];
    final cursors = List<int>.filled(buckets.length, 0);
    var remaining = true;
    while (remaining) {
      remaining = false;
      for (var i = 0; i < buckets.length; i++) {
        if (cursors[i] < buckets[i].length) {
          merged.add(buckets[i][cursors[i]++]);
          remaining = true;
        }
      }
    }
    return merged;
  }

  @override
  void onClose() {
    _generation++;
    super.onClose();
  }
}
