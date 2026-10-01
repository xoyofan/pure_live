import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/douyin/douyin_follow_import.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_empty_state.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_filters.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_room_list.dart';

/// zishu 关注页(pure_live [FavoriteController] 适配版)。
///
/// 布局/密度对齐 zishu_flutter `features/follow/views/follow_view.dart`:
/// 标题行 + 筛选行(状态三段 / 平台 chips / 卡片·列表两档)+ 内容列表。
/// 数据与交互全部走 pure_live 既有控制器,不自建状态持久化:
/// - 状态筛选 → `tabOnlineIndex`(0 开播 / 1 录播 / 2 未开播),
///   经 `animateToStatusIndex` 与 `tabController` 保持同步;
/// - 平台筛选 → `availableFavoriteSites` + `tabSiteIndex`,经 `selectSiteIndex`;
/// - 列表/刷新 → [BasePageView](与收藏页同一套分页/刷新/错误接线)+ `refreshData`。
/// 卡片档网格复用 [ZishuRoomCard];空态为 zishu FollowEmptyState 移植版。
class ZishuFollowView extends StatelessWidget {
  const ZishuFollowView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<FavoriteController>()) {
      // FavoriteController 由 initial_services 懒注册(fenix);启动早期占位。
      return const Center(child: CircularProgressIndicator());
    }
    return _ZishuFollowBody(controller: Get.find<FavoriteController>());
  }
}

/// 页面本体:只有「卡片/列表」两档视图密度是本页私有视图状态
/// (用户口径 2026-09-20:不提供「紧凑」档),其余状态全在控制器。
class _ZishuFollowBody extends StatefulWidget {
  const _ZishuFollowBody({required this.controller});

  final FavoriteController controller;

  @override
  State<_ZishuFollowBody> createState() => _ZishuFollowBodyState();
}

class _ZishuFollowBodyState extends State<_ZishuFollowBody> {
  ZishuFollowDensity _density = ZishuFollowDensity.card;

  /// 组合同步进行中(按钮转圈防重入,真源 _importing 同款)。
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        _buildToolbar(context),
        Expanded(child: _buildContent()),
      ],
    );
  }

  /// 平台筛选是否正选中抖音(真源 `_siteFilter == 'douyin'` 同条件;本仓
  /// 候选表来自 availableFavoriteSites,含 douyin 关注时才有该 chip)。
  bool _isDouyinFilterActive(FavoriteController controller) {
    final sites = controller.availableFavoriteSites;
    final index = controller.tabSiteIndex.value;
    return index >= 0 && index < sites.length && sites[index].id == Sites.douyinSite;
  }

  /// 标题 + 刷新行(对齐 zishu follow_view 头部:标题 headline 档,
  /// 刷新中显示 16px 进度圈替代按钮;真源 2c8d208:抖音筛选下替换为
  /// 「导入抖音关注」组合同步刷新按钮 follow-sync-douyin)。
  Widget _buildHeader(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Text(i18n('favorites_title'), style: context.textTitle.copyWith(fontSize: AppFontSize.headline)),
          const Spacer(),
          Obx(() {
            if (_isDouyinFilterActive(controller)) {
              if (_syncing) {
                return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
              }
              // DouyinFollowImporter 与 LiveSite 无子类型关系,is 提升不生效,
              // 用具体类 DouyinSite 转换(douyinSite 恒为 DouyinSite)。
              final importer = Sites.of(Sites.douyinSite).liveSite as DouyinSite;
              final hasCookie = importer.hasFollowImportCookie;
              return IconButton(
                key: const Key('follow-sync-douyin'),
                tooltip: hasCookie ? i18n('follow_sync_douyin_tooltip') : i18n('follow_sync_need_cookie'),
                onPressed: hasCookie ? _syncFollows : null,
                icon: Icon(Icons.refresh_rounded, size: 20, color: context.tokens.textSecondary),
              );
            }
            if (controller.loadding.value) {
              return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
            }
            return IconButton(
              tooltip: i18n('refresh'),
              onPressed: controller.refreshData,
              icon: Icon(Icons.refresh_rounded, size: 20, color: context.tokens.textSecondary),
            );
          }),
        ],
      ),
    );
  }

  /// 组合同步(真源 2c8d208 关注页入口,04e8a4b「双线并行」语义):
  /// 导入抖音关注(与已有条目合并重复)+ 全量刷新关注状态。保留进度
  /// 弹窗:导入分页耗时可见(真源同款「正在同步关注数据」弹窗)。
  Future<void> _syncFollows() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final progress = ValueNotifier(const DouyinFollowImportProgress(page: 1, imported: 0));
    unawaited(_showSyncDialog(progress));
    try {
      final added = await _runCombinedSync(progress);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ToastUtil.show(i18n(added == 0 ? 'follow_sync_done_none' : 'follow_sync_done_new', args: {'count': '$added'}));
    } catch (_) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) ToastUtil.show(i18n('follow_sync_failed'));
    } finally {
      progress.dispose();
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// 进度弹窗(真源同款:线性进度条 + 分页文案,不可点外关闭)。
  Future<void> _showSyncDialog(ValueNotifier<DouyinFollowImportProgress> progress) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValueListenableBuilder<DouyinFollowImportProgress>(
        valueListenable: progress,
        builder: (context, value, _) => AlertDialog(
          title: Text(i18n('follow_sync_running')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                i18n(
                  'follow_sync_progress',
                  args: {'page': '${value.page}', 'count': '${value.imported}', 'total': '${value.total}'},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 组合同步业务流(返回本次新增条数)。
  ///
  /// 双线并行(真源 04e8a4b):导入(分页拉关注列表)与全量状态刷新同时
  /// 启动,各自完成即落库显示 —— 刷新线走 [FavoriteController.debounceRefresh]
  /// (全量、内部有锁/合并/失败冷却保护,与导入互不覆盖);导入线拉取后
  /// 经 [DouyinFollowImport.mergeImportedRooms] 与收藏合并去重。
  ///
  /// 简化点:真源汇合后用「单次批量快照」(_refreshDouyinBatch)回填新条目
  /// 在播状态;本仓无批量快照端口,改为「导入合并有新增时再补一轮全量
  /// 刷新」—— 竞速期刷新快照不含导入中的新条目,补一轮才能点亮它们的
  /// 在播状态(多花逐房间请求,不新增解析面)。
  Future<int> _runCombinedSync(ValueNotifier<DouyinFollowImportProgress> progress) async {
    final importer = Sites.of(Sites.douyinSite).liveSite as DouyinSite;

    // 刷新线:全量关注状态刷新,与导入并行(先显示语义)。
    widget.controller.debounceRefresh();

    // 导入线:分页拉取 + 合并进收藏(同 key 去重、元信息以导入源为准)。
    final imported = await importer.importFollowing(onProgress: (value) => progress.value = value);
    var added = 0;
    await SettingsService.to.fav.mutateRoomsDurably((current) {
      final (merged, count) = DouyinFollowImport.mergeImportedRooms(current, imported);
      added = count;
      return merged;
    });

    // 汇合补轮:有新增才补,回填新条目在播状态(真源 _refreshDouyinBatch
    // 的全量刷新替代,见方法头简化点)。
    if (added > 0) widget.controller.debounceRefresh();
    return added;
  }

  /// 筛选行:状态三段 + 平台 chips + 视图两档,Wrap 自适应换行。
  Widget _buildToolbar(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Obx(() {
        final sites = controller.availableFavoriteSites;
        final index = controller.tabSiteIndex.value;
        final selectedSiteIndex = index >= 0 && index < sites.length ? index : -1;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ZishuFollowStatusFilter(
              selectedIndex: controller.tabOnlineIndex.value,
              onSelected: controller.animateToStatusIndex,
            ),
            ZishuFollowPlatformFilter(
              sites: sites,
              selectedIndex: selectedSiteIndex,
              onSelected: controller.selectSiteIndex,
            ),
            SegmentedButton<ZishuFollowDensity>(
              segments: [
                for (final density in ZishuFollowDensity.values)
                  ButtonSegment(
                    value: density,
                    label: Text(density.label, key: Key('follow-density-${density.name}')),
                    icon: Icon(density.icon, size: 14),
                  ),
              ],
              selected: {_density},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() => _density = selection.first),
              style: zishuFollowSegmentedStyle(context),
            ),
          ],
        );
      }),
    );
  }

  /// 内容区:沿用 pure_live 收藏页的 [BasePageView] 接线(下拉刷新/桌面
  /// 键盘分页/回顶按钮),只把内容与空态渲染换成 zishu 风格。空列表的
  /// 占位由 [ZishuFollowRoomList] 在内容区内绘制(preserveContentWhenEmpty
  /// 模式下 BasePageView 自身的 emptyBuilder 不再触发)。
  Widget _buildContent() {
    final controller = widget.controller;
    return BasePageView<FavoriteController, LiveRoom>(
      controller: controller,
      enableRefresh: true,
      enableLoadMore: true,
      preserveContentWhenEmpty: true,
      // 用户口径:同 browse,不挂页码 footer 与右侧悬浮上下按钮。
      showScrollToTopBtn: false,
      desktopInfiniteScroll: true,
      showPageSizeSelector: false,
      pageSizeOptions: const [],
      emptyBuilder: (context) => ZishuFollowEmptyState(controller: controller),
      contentBuilder: (context, list, scrollController) {
        return ZishuFollowRoomList(
          rooms: list,
          density: _density,
          scrollController: scrollController,
          emptyView: ZishuFollowEmptyState(controller: controller),
        );
      },
    );
  }
}
