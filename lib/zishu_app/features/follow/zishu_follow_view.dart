import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/douyin/douyin_follow_import.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_empty_state.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_filters.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_room_list.dart';
import 'package:pure_live/zishu_app/features/play/room_reminder_store.dart';
import 'package:pure_live/zishu_app/features/play/super_follow_controller.dart';
import 'package:pure_live/zishu_app/features/play/zishu_stage_hint.dart';

/// zishu 关注页(pure_live [FavoriteController] 适配版)。
///
/// 布局/密度对齐 zishu_flutter `features/follow/views/follow_view.dart`:
/// 标题行 + 筛选行(状态三段 / 平台 chips / 卡片·列表两档)+ 内容列表。
/// 数据与交互全部走 pure_live 既有控制器,不自建状态持久化:
/// - 状态筛选 → `tabOnlineIndex`(0 开播 / 1 录播 / 2 未开播),
///   经 `animateToStatusIndex` 与 `tabController` 保持同步;
/// - 平台筛选 → `availableFavoriteSites` + `tabSiteIndex`,经 `selectSiteIndex`;
/// - 列表/刷新 → [BasePageView](与收藏页同一套分页/刷新/错误接线)+ `refreshData`;
/// - 批量管理 → 头部工具行 + 长按进批量(真源 _batchMode/_selectedKeys
///   语义;删除所选 = [FavoriteController.removeMany],开关提醒 =
///   [RoomReminderStore] 批量接口);
/// - 抖音筛选下另有「导入直播中」入口(真源 _importLive 语义,反馈走
///   [ZishuStageHint])。
/// 卡片档为关注条目卡 [ZishuFollowEntryCard](真源 follow_entry_card
/// 页面态移植);空态为 zishu FollowEmptyState 移植版。
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

  /// 「导入直播中」进行中(按钮转圈防重入,真源 _importingLive 同款)。
  bool _importingLive = false;

  /// 批量管理进行中(真源 _batchMode 同名语义)。
  bool _batchMode = false;

  /// 批量选中集(key = `platform:roomId`,真源 _selectedKeys 同语义)。
  final Set<String> _selectedKeys = {};

  // —— 批量管理文案:无既有 i18n key,中文常量(文案照真源 _buildHeader
  // / _deleteSelected / _setRemindSelected,翻译 key 由主会话统一裁决)。
  static const String _kBatchEntry = '批量管理';
  static const String _kBatchCancel = '取消';
  static const String _kBatchSelectAll = '全选';
  static const String _kBatchSelectNone = '全不选';
  static const String _kBatchRemindOff = '关提醒';

  static String _deletedToast(int count) => '已删除 $count 个关注';

  static String _remindOnToast(int count) => '已为 $count 个关注开启提醒';

  static String _remindOffToast(int count) => '已为 $count 个关注关闭提醒';

  // —— 导入直播中文案:无既有 i18n key,中文常量(照真源 _importLive)。
  static const String _kImportLiveEntry = '导入直播中';
  static const String _kImportLiveTooltip = '导入关注中正在直播的房间';
  static const String _kImportLiveDoneNone = '没有发现新的直播关注';
  static const String _kImportLiveFailed = '直播关注导入失败,请稍后重试';

  static String _importLiveDoneToast(int count) => '已导入 $count 个直播关注';

  static String _removedToast(LiveRoom room) => '已移除「${(room.nick ?? '').trim()}」的关注';

  @override
  Widget build(BuildContext context) {
    // 舞台提示浮层挂页面 Stack 顶层:「导入直播中」的完成/失败反馈走
    // ZishuStageHint 通道(任务口径;该通道需要页面内挂 Overlay 才可见)。
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildToolbar(context),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
        const ZishuStageHintOverlay(),
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

  /// 标题 + 刷新/批量操作行(真源 _buildHeader 口径:平台操作与批量操作
  /// 同一个 Wrap;批量模式展开 取消/全选/删除所选/开关提醒,否则显示
  /// 「批量管理」入口)。
  Widget _buildHeader(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Text(i18n('favorites_title'), style: context.textTitle.copyWith(fontSize: AppFontSize.headline)),
          const Spacer(),
          Flexible(
            child: Obx(() {
              return Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [..._buildPlatformActions(context, controller), ..._buildBatchActions(context, controller)],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 平台相关操作:抖音筛选下 = 「导入直播中」+ 组合同步刷新钮
  /// (真源 2c8d208/195-209 同序),否则通用刷新钮。
  List<Widget> _buildPlatformActions(BuildContext context, FavoriteController controller) {
    if (_isDouyinFilterActive(controller)) {
      // DouyinFollowImporter 与 LiveSite 无子类型关系,is 提升不生效,
      // 用具体类 DouyinSite 转换(douyinSite 恒为 DouyinSite)。
      final importer = Sites.of(Sites.douyinSite).liveSite as DouyinSite;
      final hasCookie = importer.hasFollowImportCookie;
      return [
        // 「导入直播中」(真源 _importLive 口径):只拉关注中在播的房间,
        // 无 cookie 置灰(tooltip 提示,与组合同步钮同一护栏)。
        if (_importingLive)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Tooltip(
            message: hasCookie ? _kImportLiveTooltip : i18n('follow_sync_need_cookie'),
            child: TextButton.icon(
              key: const Key('follow-import-live'),
              onPressed: hasCookie ? _importLive : null,
              icon: Icon(Icons.podcasts_rounded, size: 16, color: context.tokens.liveBadge),
              label: Text(_kImportLiveEntry, style: context.textBody.copyWith(color: context.tokens.liveBadge)),
            ),
          ),
        if (_syncing)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        else
          IconButton(
            key: const Key('follow-sync-douyin'),
            tooltip: hasCookie ? i18n('follow_sync_douyin_tooltip') : i18n('follow_sync_need_cookie'),
            onPressed: hasCookie ? _syncFollows : null,
            icon: Icon(Icons.refresh_rounded, size: 20, color: context.tokens.textSecondary),
          ),
      ];
    }
    if (controller.loadding.value) {
      return const [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))];
    }
    return [
      IconButton(
        tooltip: i18n('refresh'),
        onPressed: controller.refreshData,
        icon: Icon(Icons.refresh_rounded, size: 20, color: context.tokens.textSecondary),
      ),
    ];
  }

  /// 批量操作组(真源 _buildHeader _batchMode 分支逐字:取消/全选·全不选/
  /// 删除所选 (N) 红/开提醒 (N) accent/关提醒 textSecondary;非批量态
  /// 显「批量管理」入口 checklist_rounded 16 textSecondary)。
  List<Widget> _buildBatchActions(BuildContext context, FavoriteController controller) {
    final tokens = context.tokens;
    if (!_batchMode) {
      return [
        TextButton.icon(
          onPressed: () => _enterBatch(),
          icon: Icon(Icons.checklist_rounded, size: 16, color: tokens.textSecondary),
          label: Text(_kBatchEntry, style: context.textBody.copyWith(color: tokens.textSecondary)),
        ),
      ];
    }
    // 全选范围 = 当前可见条目(控制器已过滤 + 分页后的展示列表;真源
    // 同样只对当页可见条目做全选)。
    final visible = controller.list.toList(growable: false);
    return [
      TextButton(
        onPressed: _exitBatch,
        child: Text(_kBatchCancel, style: context.textBody.copyWith(color: tokens.textSecondary)),
      ),
      TextButton(
        onPressed: () => _toggleSelectAll(visible),
        child: Text(_allSelected(visible) ? _kBatchSelectNone : _kBatchSelectAll, style: context.textBody),
      ),
      TextButton.icon(
        onPressed: _selectedKeys.isEmpty ? null : _deleteSelected,
        icon: Icon(Icons.delete_outline_rounded, size: 16, color: tokens.error),
        label: Text('删除所选 (${_selectedKeys.length})', style: context.textBody.copyWith(color: tokens.error)),
      ),
      TextButton.icon(
        onPressed: _selectedKeys.isEmpty ? null : () => _setRemindSelected(true),
        icon: Icon(Icons.notifications_active_rounded, size: 16, color: tokens.accent),
        label: Text('开提醒 (${_selectedKeys.length})', style: context.textBody.copyWith(color: tokens.accent)),
      ),
      TextButton(
        onPressed: _selectedKeys.isEmpty ? null : () => _setRemindSelected(false),
        child: Text(_kBatchRemindOff, style: context.textBody.copyWith(color: tokens.textSecondary)),
      ),
    ];
  }

  // —— 批量管理(真源 _enterBatch/_exitBatch/_toggleSelect/_toggleSelectAll
  // /_deleteSelected/_setRemindSelected 同语义,选中键 = identityKey)。

  void _enterBatch([String? selectKey]) {
    setState(() {
      _batchMode = true;
      if (selectKey != null) _selectedKeys.add(selectKey);
    });
  }

  void _exitBatch() {
    setState(() {
      _batchMode = false;
      _selectedKeys.clear();
    });
  }

  void _toggleSelect(LiveRoom room) {
    setState(() {
      // add 返回 false 表示已存在 → 移除(切换语义)。
      if (!_selectedKeys.add(room.identityKey)) _selectedKeys.remove(room.identityKey);
    });
  }

  bool _allSelected(List<LiveRoom> items) =>
      items.isNotEmpty && items.every((room) => _selectedKeys.contains(room.identityKey));

  void _toggleSelectAll(List<LiveRoom> items) {
    setState(() {
      if (_allSelected(items)) {
        _selectedKeys.clear();
      } else {
        _selectedKeys
          ..clear()
          ..addAll([for (final room in items) room.identityKey]);
      }
    });
  }

  /// 选中键 → 完整房间记录(取消收藏/批量提醒都以房间为准;从全量收藏
  /// 解析,选中后切换筛选也不丢条目)。
  List<LiveRoom> _selectedRooms() {
    final keys = Set<String>.from(_selectedKeys);
    return [
      for (final room in widget.controller.getAllRooms())
        if (keys.contains(room.identityKey)) room,
    ];
  }

  Future<void> _deleteSelected() async {
    if (_selectedKeys.isEmpty) return;
    final count = _selectedKeys.length;
    await widget.controller.removeMany(_selectedRooms());
    if (!mounted) return;
    _exitBatch();
    ToastUtil.show(_deletedToast(count));
  }

  void _setRemindSelected(bool enabled) {
    if (_selectedKeys.isEmpty) return;
    final count = _selectedKeys.length;
    final targets = _selectedRooms();
    if (enabled) {
      RoomReminderStore.to.addMany(targets);
    } else {
      RoomReminderStore.to.removeMany(targets);
    }
    ToastUtil.show(enabled ? _remindOnToast(count) : _remindOffToast(count));
  }

  /// 条目级移除(卡片操作钮的垃圾桶;真源无确认就不加确认)。
  Future<void> _removeEntry(LiveRoom room) async {
    await widget.controller.removeMany([room]);
    if (!mounted) return;
    ToastUtil.show(_removedToast(room));
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

  /// 「导入直播中」(真源 _importLive 语义):拉取关注中在播的房间并合并
  /// 进收藏,反馈走 ZishuStageHint(转圈防重入,失败提示不抛细节)。
  Future<void> _importLive() async {
    if (_importingLive) return;
    setState(() => _importingLive = true);
    try {
      final added = await _runImportLive();
      if (!mounted) return;
      ZishuStageHint.show(added == 0 ? _kImportLiveDoneNone : _importLiveDoneToast(added));
    } catch (_) {
      if (mounted) ZishuStageHint.show(_kImportLiveFailed);
    } finally {
      if (mounted) setState(() => _importingLive = false);
    }
  }

  /// 导入直播中业务流(返回本次新增条数):follow_top 只回在播房间,
  /// 导入条目自带在播状态,无需补刷新(真源 importDouyinLiveFollows 只
  /// 追加同语义);合并走既有 [DouyinFollowImport.mergeImportedRooms]。
  Future<int> _runImportLive() async {
    // DouyinFollowImporterLive 扩展成员:接口默认实现(follow_top 协议)。
    final DouyinFollowImporter importer = Sites.of(Sites.douyinSite).liveSite as DouyinSite;
    final imported = await importer.importFollowingLive();
    var added = 0;
    await SettingsService.to.fav.mutateRoomsDurably((current) {
      final (merged, count) = DouyinFollowImport.mergeImportedRooms(current, imported);
      added = count;
      return merged;
    });
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
          // 批量管理:条目行首/封面左上出复选框,长按进批量(卡片与行都
          // 支持);批量态点击改为切换选中,退出恢复进播放页。
          selectMode: _batchMode,
          selectedKeys: _selectedKeys,
          onTap: (room) {
            if (_batchMode) {
              _toggleSelect(room);
            } else {
              AppNavigator.toLiveRoomDetail(liveRoom: room);
            }
          },
          onLongPress: (room) {
            if (!_batchMode) _enterBatch(room.identityKey);
          },
          onToggleSelect: _toggleSelect,
          // 超关=本仓「特别关注」语义(真源 onToggleSpecial);提醒/移除
          // 分别走本地提醒标记与批量移除管线。
          onToggleSuper: (room) => SuperFollowController.to.toggle(room),
          onToggleRemind: (room) => RoomReminderStore.to.toggle(room),
          onRemove: _removeEntry,
        );
      },
    );
  }
}
