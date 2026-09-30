import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/widgets/retry_button.dart' as zishu;
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card_skeleton.dart';

/// zishu 浏览视图:热门页单站点的网格内容,接 pure_live 既有分页控制器
/// (`BasePageScrollAndStateBone<LiveRoom>`,tag = 站点 id),刷新/加载更多
/// 仍由 BasePageView 承担,网格度量走 zishu tokens。
///
/// 切站 stale-while-revalidate:外壳把本视图按站点 id 在同一槽位原位重建
/// (zishu_app_shell.dart `_contentForMenu`),State 跨切站存活并保存每站点
/// 最近一次非空 list 的一帧快照;切到 list 尚空的新站时立即用快照帧渲染
/// 网格(本站帧优先,缺省回退上一站帧),顶部叠 2px accent「刷新中」细条,
/// 控制器 list 非空后原位替换为真数据,细条随之消失。数据仍以控制器 list
/// 为唯一真源:快照只是过渡帧,失败/空/未登录一律回退 BasePageView 既有
/// 分支,缓存不掩盖错误态。
class ZishuBrowseView extends StatefulWidget {
  final String siteId;

  const ZishuBrowseView({super.key, required this.siteId});

  @override
  State<ZishuBrowseView> createState() => _ZishuBrowseViewState();
}

class _ZishuBrowseViewState extends State<ZishuBrowseView> {
  /// 快照帧上限(LRU 淘汰最久未展示的站点帧)。
  static const int _maxFrames = 10;

  /// siteId → 该站最近一次非空 list 快照。插入序即最近使用序(末尾最新)。
  final Map<String, List<LiveRoom>> _lastNonEmptyFrames = {};

  /// 真数据在屏时记一帧快照;list 是 RxList,必须浅拷贝,防止后续刷新
  /// 的原地变更穿透到过渡帧。
  void _rememberFrame(String siteId, List<LiveRoom> list) {
    _lastNonEmptyFrames.remove(siteId);
    _lastNonEmptyFrames[siteId] = List<LiveRoom>.of(list);
    while (_lastNonEmptyFrames.length > _maxFrames) {
      _lastNonEmptyFrames.remove(_lastNonEmptyFrames.keys.first);
    }
  }

  /// 取某站快照帧;命中即视为最近使用,移到末尾。返回 (来源站 id, 帧)。
  (String, List<LiveRoom>)? _frameFor(String siteId) {
    final frame = _lastNonEmptyFrames.remove(siteId);
    if (frame == null) return null;
    _lastNonEmptyFrames[siteId] = frame;
    return (siteId, frame);
  }

  /// 没有目标站快照时回退「上一站」:最近使用且非当前站的帧(切站时即
  /// 用户刚离开的那一站,保住「不闪 loading」的主路径——首访站点的控制器
  /// 尚无任何数据)。
  (String, List<LiveRoom>)? _latestFrameOtherThan(String siteId) {
    for (final id in _lastNonEmptyFrames.keys.toList().reversed) {
      if (id == siteId) continue;
      return _frameFor(id);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final siteId = widget.siteId;
    if (!Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId)) {
      // 分页控制器由 PopularController.initControllers 懒注册;站点表
      // 到位前先占位。
      return const Center(child: CircularProgressIndicator());
    }
    final controller = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: siteId);
    // 同一 Obx 读 list/loadding/notLogin/pageError/pageEmpty:数据到位、
    // 加载起止、失败与空态都会触发原位重建,过渡帧的进出无需额外状态位。
    return Obx(() {
      final list = controller.list;
      if (list.isNotEmpty) {
        // 数据在屏:先记快照(过渡帧素材),再走 BasePageView 常规内容。
        _rememberFrame(siteId, list);
        return _buildRealContent(controller);
      }
      // list 为空:失败/空/未登录一律不落缓存帧,交还 BasePageView 既有
      // 分支(错误态带 RetryButton、空态带 zishu.EmptyView,骨架不遮挡
      // 任何恢复入口)。
      final recoverable = controller.notLogin.value || controller.pageError.value || controller.pageEmpty.value;
      if (!recoverable) {
        final frame = _frameFor(siteId) ?? _latestFrameOtherThan(siteId);
        if (frame != null) {
          // 切站过渡帧:立即渲染上一份网格,控制器 list 非空后本 Obx
          // 重建,原位替换为真数据,顶部细条随之消失。
          return _ZishuStaleGridFrame(rooms: frame.$2, frameSiteId: frame.$1);
        }
      }
      if (controller.loadding.value) {
        // 无任何快照可用的首屏:骨架屏(列数与下方网格同口径)。
        return LayoutBuilder(
          builder: (context, constraints) =>
              RoomGridSkeleton(count: AppRoomGrid.columnsFor(constraints.maxWidth), site: siteId),
        );
      }
      // 快照与加载标记都没有的短暂窗口(懒注册后 load 尚未起跑):维持
      // 既有行为,交给 BasePageView 的 loading/错误/空态分支。
      return _buildRealContent(controller);
    });
  }

  Widget _buildRealContent(BasePageScrollAndStateBone<LiveRoom> controller) {
    return BasePageView<BasePageScrollAndStateBone<LiveRoom>, LiveRoom>(
      controller: controller,
      showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
      pageSizeOptions: SettingsService.to.page.pageSizeOptions,
      showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
      emptyBuilder: (context) => zishu.EmptyView(
        icon: Icons.live_tv_rounded,
        message: i18n('empty_live_title'),
        action: zishu.RetryButton(label: i18n('refresh'), onRetry: () => controller.refreshData()),
      ),
      // contentBuilder 在 BasePageView 内部的 Obx 里调用
      // (base_page_view.dart:141-173),此处读 loadding.value 即被该 Obx
      // 追踪,加载尾随其出现/消失;刷新与加载更多仍由 BasePageView 的
      // EasyRefresh 驱动,footer 仅是视觉占位。
      contentBuilder: (context, list, scrollController) {
        return ZishuBrowseGrid(
          rooms: list,
          scrollController: scrollController,
          loadingMore: controller.loadding.value && list.isNotEmpty,
        );
      },
    );
  }
}

/// zishu 房间网格:断点定列([AppRoomGrid.columnsFor])、16/13.6 间距、
/// 16:9 封面 + 58px 元信息预算的等高卡片。[loadingMore] 为 true 时在网格
/// 末尾渲染加载中 footer(对齐 zishu 真源 room_grid.dart 的
/// `_LoadingMoreFooter`:16px accent 环 + 「加载中」文案,占一个网格槽位)。
class ZishuBrowseGrid extends StatelessWidget {
  final List<LiveRoom> rooms;
  final ScrollController? scrollController;

  /// 控制器加载中时在网格末尾追加视觉占位 footer;加载触发仍由
  /// BasePageView 的 EasyRefresh/分页控件承担,此处不重复触发。
  final bool loadingMore;

  const ZishuBrowseGrid({super.key, required this.rooms, this.scrollController, this.loadingMore = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AppRoomGrid.columnsFor(constraints.maxWidth);
        const crossSpacing = AppSpacing.gridCrossAxisSpacing;
        const mainSpacing = AppSpacing.gridMainAxisSpacing;
        final gridWidth = constraints.maxWidth - 2 * AppSpacing.lg;
        final cardWidth = (gridWidth - (columns - 1) * crossSpacing) / columns;
        final aspectRatio = cardWidth / (cardWidth * 9 / 16 + metaHeightFor(58, context));
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: crossSpacing,
                  mainAxisSpacing: mainSpacing,
                  childAspectRatio: aspectRatio,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= rooms.length) return const _ZishuLoadingMoreFooter();
                  return ZishuRoomCard(
                    key: ValueKey('${rooms[index].platform}:${rooms[index].roomId}'),
                    room: rooms[index],
                  );
                }, childCount: rooms.length + (loadingMore ? 1 : 0)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 切站过渡帧:上一份网格快照 + 顶部 2px accent「刷新中」细条。
///
/// 细条做法对齐 base_page_view.dart 顶部进度条(透明底 + valueColor),
/// 颜色走 tokens.accent 不新增色值;整段过渡期恒显(过渡帧只在 list 为空
/// 的加载期存在,真数据到位即整帧移除)。
///
/// 滚动用独立一次性 controller:不污染分页控制器的滚动状态(回到顶部
/// 按钮、分页判定都挂在控制器自己的 controller 上),真数据到位后本帧
/// 连同滚动态一并销毁,由 BasePageView 重新接管。
class _ZishuStaleGridFrame extends StatefulWidget {
  final List<LiveRoom> rooms;

  /// 快照来源站 id:连续切站(B、C 都无数据)时同一 State 被复用,以此
  /// 判定「换了来源帧」,回滚滚动位置,避免把上一帧的偏移带到新帧。
  final String frameSiteId;

  const _ZishuStaleGridFrame({required this.rooms, required this.frameSiteId});

  @override
  State<_ZishuStaleGridFrame> createState() => _ZishuStaleGridFrameState();
}

class _ZishuStaleGridFrameState extends State<_ZishuStaleGridFrame> {
  final ScrollController _staleScrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _ZishuStaleGridFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frameSiteId == widget.frameSiteId) return;
    // 换帧回顶:滚动定位要在布局后进行(同 base_page_scroll_bone.dart
    // 的 post-frame 惯例)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_staleScrollController.hasClients) return;
      _staleScrollController.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _staleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Stack(
      children: [
        Positioned.fill(
          child: ZishuBrowseGrid(rooms: widget.rooms, scrollController: _staleScrollController),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// 网格末尾的加载中 footer,视觉上与卡片底色区分(移植 zishu 真源
/// `_LoadingMoreFooter`:16px accent 环 + 「加载中」文案)。
class _ZishuLoadingMoreFooter extends StatelessWidget {
  const _ZishuLoadingMoreFooter();

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
