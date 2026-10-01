// zishu 播放页侧栏「关注」tab(真源:zishu_flutter
// `side_panel/follow_panel.dart` 的 pure_live 适配版)。
//
// 对齐口径:
// - 顶部工具行 = 视图切换钮 + 平台筛选 chips 同一行(真源 follow-tab-toolbar
//   布局;无「我的关注」标题 —— 真源用户口径 2026-09-19 顶部不放标题);
// - 默认紧凑列表(真源用户口径 2026-09-19「默认用列表显示」),行 =
//   圆头像 + 主播名 + 在播态圆点 + 人数统计列,行高对齐「我的关注」页
//   列表行节奏(ZishuFollowRoomList.rowHeight = 26);
// - 网格档 = 「我的关注」页同款 ZishuRoomCard,侧栏窄列固定 2 列
//   (真源 compact 口径),元信息区预算 58 与页面网格同源;
// - 可见性只显在播(真源 playSidebarFollowEntries 口径:侧栏不放未开播),
//   超关在播排前(真源 follow_sort 档位;pure_live 侧超关是本地标记
//   SuperFollowController);
// - 头像取图与顶栏关注浮层小卡同源:avatar 优先、封面兜底,斗鱼过期截图
//   CDN(`rpic.douyucdn.cn/asrpic…`)排除(真源 `_followAvatarSrc` 正则);
// - 分页窗口对齐真源 follow_panel.dart:26-34/79-89/134-138/203/225-243:
//   单页 48 条(web PLAY_FOLLOW_PAGE_SIZE),首屏 48,滚动距底 96px 内
//   再放一页,hasMore 时底部提示「向下滚动加载更多…」;换平台回卷首屏
//   (真源 onChanged 口径),视图切换不回卷(真源同款)。
// - 视图/平台筛选是会话级记忆(切房重建侧栏后保持,与
//   zishu_play_side_panel.dart 的 `_lastSidePanelTab` 同款机制):
//   真源收进 PlaySidePanelPrefs(followGrid/followSite),本仓库最小等价物
//   就是文件级可变量,仅进程内,不持久化。

import 'dart:async';
import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/douyin/douyin_follow_import.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/browse/zishu_room_card.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_filters.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_room_list.dart';
import 'package:pure_live/zishu_app/features/follow/zishu_follow_entry_card.dart';
import 'package:pure_live/zishu_app/features/play/super_follow_controller.dart';
import 'package:pure_live/zishu_app/features/play/zishu_stage_hint.dart';

/// 会话级视图档记忆:true = 封面网格,false = 紧凑列表(默认,真源用户口径)。
bool _sideFollowGrid = false;

/// 会话级平台筛选记忆:Sites.allSite('all') = 全平台,否则平台 id。
String _sideFollowSiteId = Sites.allSite;

/// zishu 播放页侧栏「关注」tab:工具行(视图切换 + 平台筛选)+
/// 在播关注列表/网格,点击行/卡换房。
class ZishuPlayFollowPanel extends StatefulWidget {
  const ZishuPlayFollowPanel({super.key});

  @override
  State<ZishuPlayFollowPanel> createState() => _ZishuPlayFollowPanelState();
}

class _ZishuPlayFollowPanelState extends State<ZishuPlayFollowPanel> {
  bool get _grid => _sideFollowGrid;
  set _grid(bool value) => setState(() => _sideFollowGrid = value);

  String get _siteId => _sideFollowSiteId;

  /// 已展示条数(分页窗口)。对齐 web `PLAY_FOLLOW_PAGE_SIZE = 48`
  /// (真源 follow_panel.dart:26-34):首屏只放 48 条,滚动距底 96px 内
  /// 再放一页,底部提示「向下滚动加载更多…」。
  int _visibleCount = _kFollowPageSize;

  /// 距底部多少像素内视为「滚到底」(触发下一页加载)。
  static const double _kLoadMoreTriggerExtent = 96;

  /// 单页条数(web `PLAY_FOLLOW_PAGE_SIZE`)。
  static const int _kFollowPageSize = 48;

  /// 本轮待渲染的可见条目总数(由 build 写回,供滚动回调判定还有没有下一页)。
  int _visibleTotal = 0;

  /// 组合同步进行中(按钮转圈防重入,真源 _syncing 同款)。
  bool _syncing = false;

  /// 滚动到底附近再放一页(真源 follow_panel.dart:79-89:竖轴通知 +
  /// 距底 ≤96px 才触发;返回 false 不消费通知)。
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || _visibleTotal <= _visibleCount) {
      return false;
    }
    if (notification.metrics.maxScrollExtent - notification.metrics.pixels <= _kLoadMoreTriggerExtent) {
      setState(() => _visibleCount += _kFollowPageSize);
    }
    return false;
  }

  /// 平台筛选候选表:全平台 + 有关注条目的平台。与「我的关注」页
  /// (`FavoriteController.availableFavoriteSites`)同源同算:
  /// favorite_controller.dart:69 `favoriteSitesForRooms` 的逐字复刻 ——
  /// 侧栏不触碰页面控制器的 tabSiteIndex 状态,故本地重算同一份结果。
  List<Site> _availableSites(List<LiveRoom> rooms) {
    final available = Sites().availableSites(containsAll: true);
    final favoriteSiteIds = rooms.map((room) => room.normalizedPlatformId).where((siteId) => siteId.isNotEmpty).toSet();
    return available
        .where((site) => site.id == Sites.allSite || favoriteSiteIds.contains(site.id.trim().toLowerCase()))
        .toList(growable: false);
  }

  /// 侧栏可见条目:只显在播(真源 playSidebarFollowEntries 口径),平台
  /// 筛选后按真源 follow_sort 档位排:超关在播 → 普通在播,档内**观看数
  /// 倒序**(缺失/不可解析沉底、合法 0 是有效值),平局保持收藏原序
  /// (本仓收藏条目无关注时间戳,真源的 followedAt 平局回退以此等效)。
  List<LiveRoom> _visibleRooms(List<LiveRoom> favorites) {
    final siteId = _siteId;
    final visible = <(LiveRoom, int)>[
      for (var i = 0; i < favorites.length; i++)
        if (favorites[i].isLiveNow)
          if (siteId == Sites.allSite || favorites[i].normalizedPlatformId == siteId) (favorites[i], i),
    ];
    final superFollow = SuperFollowController.to;
    int? onlineOf(LiveRoom room) =>
        LiveRoom.parseAudienceNumber(room.audienceValue(preferRealOnline: false, platformEnabled: false));
    int rank(LiveRoom room) => superFollow.isSuper(room) ? 0 : 1;
    visible.sort((a, b) {
      final byRank = rank(a.$1).compareTo(rank(b.$1));
      if (byRank != 0) return byRank;
      final onlineA = onlineOf(a.$1);
      final onlineB = onlineOf(b.$1);
      // 缺失(不可解析)沉底;合法 0 参与数值序。
      if (onlineA == null || onlineB == null) {
        if (onlineA == null && onlineB == null) return a.$2.compareTo(b.$2);
        return onlineA == null ? 1 : -1;
      }
      if (onlineA != onlineB) return onlineB.compareTo(onlineA);
      return a.$2.compareTo(b.$2);
    });
    return [for (final entry in visible) entry.$1];
  }

  /// 抖音关注导入能力位(站点注册表探测;未实现时按钮不出现)。
  DouyinFollowImporter? get _followImporter {
    // DouyinFollowImporter 与 LiveSite 无子类型关系,is 提升不生效;
    // 用具体类 DouyinSite 判定(其实现了 DouyinFollowImporter)。
    final site = Sites.of(Sites.douyinSite).liveSite;
    return site is DouyinSite ? site : null;
  }

  /// 组合同步(真源 2c8d208 侧栏入口,04e8a4b「双线并行」语义;与
  /// 「我的关注」页同一业务口径):导入抖音关注(合并重复)+ 全量刷新
  /// 关注状态。侧栏密度不放进度弹窗,按钮自身转圈 + 舞台反馈结果。
  Future<void> _syncDouyin() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final added = await _runCombinedSync();
      ZishuStageHint.show(
        i18n(added == 0 ? 'follow_sync_done_none' : 'follow_sync_done_new', args: {'count': '$added'}),
      );
    } catch (_) {
      ZishuStageHint.show(i18n('follow_sync_failed'));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// 组合同步业务流(返回本次新增条数)。
  ///
  /// 双线并行(真源 04e8a4b):导入(分页拉关注列表)与全量状态刷新同时
  /// 启动,各自完成即落库显示 —— 刷新线走 [FavoriteController.debounceRefresh]
  /// (全量、内部有锁/合并/失败冷却保护;控制器未注册时跳过,导入照常);
  /// 导入线拉取后经 [DouyinFollowImport.mergeImportedRooms] 与收藏合并去重。
  ///
  /// 简化点:真源汇合后用「单次批量快照」(_refreshDouyinBatch)回填新条目
  /// 在播状态;本仓无批量快照端口,改为「导入合并有新增时再补一轮全量
  /// 刷新」—— 竞速期刷新快照不含导入中的新条目,补一轮才能点亮它们的
  /// 在播状态(多花逐房间请求,不新增解析面)。
  Future<int> _runCombinedSync() async {
    final importer = _followImporter;
    if (importer == null) {
      throw StateError('抖音站点不支持关注导入');
    }

    // 刷新线:全量关注状态刷新,与导入并行(先显示语义)。
    if (Get.isRegistered<FavoriteController>()) {
      Get.find<FavoriteController>().debounceRefresh();
    }

    // 导入线:分页拉取 + 合并进收藏(同 key 去重、元信息以导入源为准)。
    final imported = await importer.importFollowing();
    var added = 0;
    await SettingsService.to.fav.mutateRoomsDurably((current) {
      final (merged, count) = DouyinFollowImport.mergeImportedRooms(current, imported);
      added = count;
      return merged;
    });

    // 汇合补轮:有新增才补,回填新条目在播状态(真源 _refreshDouyinBatch
    // 的全量刷新替代,见方法头简化点)。
    if (added > 0 && Get.isRegistered<FavoriteController>()) {
      Get.find<FavoriteController>().debounceRefresh();
    }
    return added;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final favorites = SettingsService.to.fav.favoriteRooms.v;
      final sites = _availableSites(favorites);
      final rooms = _visibleRooms(favorites);
      // 分页窗口(真源 follow_panel.dart:95-97):_visibleTotal 由 build
      // 写回,供滚动回调判定还有没有下一页;hasMore 才把窗口裁到
      // _visibleCount,数据变少时自然回卷为全量。
      _visibleTotal = rooms.length;
      final hasMore = rooms.length > _visibleCount;
      final windowed = hasMore ? rooms.sublist(0, _visibleCount) : rooms;
      return Column(
        key: const Key('play-side-follow-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context, sites),
          Expanded(
            child: rooms.isEmpty
                ? _FollowPanelHint(
                    icon: Icons.star_border_rounded,
                    title: i18n('favorites_title'),
                    text: i18n('empty_favorite_online_title'),
                  )
                : NotificationListener<ScrollNotification>(
                    // 滚动到底附近再放一页(真源 follow_panel.dart:182 同款
                    // NotificationListener<ScrollNotification> 挂法,只包
                    // 列表区,不包空态/工具行)。
                    onNotification: _onScroll,
                    child: _grid ? _buildCardGrid(context, windowed) : _buildCompactList(windowed),
                  ),
          ),
          // 还有更多时底部提示行(真源 follow_panel.dart:203 同款 Column
          // 尾挂法):列表滚到底自动再放一页,这行提示是给用户的可见信号。
          if (hasMore) const _FollowMoreHint(),
        ],
      );
    });
  }

  /// 工具行(对齐真源 follow_panel.dart:105-174):左侧视图切换钮
  /// (列表态显网格入口 / 网格态显列表入口,点击即切),右侧平台筛选
  /// chips 复用「我的关注」页的 [ZishuFollowPlatformFilter](真源两处
  /// 同为 FollowPlatformFilter,放不下自动换行),行尾挂组合同步入口。
  Widget _buildToolbar(BuildContext context, List<Site> sites) {
    final tokens = context.tokens;
    final importer = _followImporter;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: AppSpacing.sm),
        Tooltip(
          message: _grid ? i18n('follow_density_row') : i18n('follow_density_card'),
          child: IconButton(
            key: const Key('play-side-follow-view-toggle'),
            onPressed: () => _grid = !_grid,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            focusColor: AppStateLayer.focusOf(tokens.accent),
            icon: Icon(
              // 卡片态显示「列表」入口、列表态显示「网格」入口(点击即切)。
              _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 18,
              color: _grid ? tokens.textSecondary : tokens.accent,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: ZishuFollowPlatformFilter(
              sites: sites,
              selectedIndex: sites.indexWhere((site) => site.id == _siteId),
              onSelected: (index) {
                if (index < 0 || index >= sites.length) return;
                // 换平台 = 换列表(真源 follow_panel.dart:134-138:平台
                // onChanged 单次 setState 同时换筛选并把 _visibleCount 回卷
                // 首屏,否则一换平台就直接铺满 48×n);视图切换真源不重置
                // 窗口 —— 照真源,只平台筛选重置。这里直接写顶层变量而非
                // 走 _siteId setter,保持与真源同款的单次 setState。
                setState(() {
                  _sideFollowSiteId = sites[index].id;
                  _visibleCount = _kFollowPageSize;
                });
              },
            ),
          ),
        ),
        // 组合同步入口(真源 2c8d208 侧栏口径):平台筛选选中抖音时显示,
        // 点击 = 导入抖音关注(合并重复)+ 刷新全部关注状态;无登录 cookie
        // 置灰(tooltip 提示),同步中转圈防重入。
        if (_siteId == Sites.douyinSite && importer != null)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _syncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    key: const Key('play-side-follow-sync'),
                    tooltip: importer.hasFollowImportCookie
                        ? i18n('follow_sync_douyin_tooltip')
                        : i18n('follow_sync_need_cookie'),
                    onPressed: importer.hasFollowImportCookie ? _syncDouyin : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    focusColor: AppStateLayer.focusOf(tokens.accent),
                    icon: Icon(Icons.refresh_rounded, size: 18, color: tokens.textSecondary),
                  ),
          ),
      ],
    );
  }

  /// 紧凑列表(默认):单列行铺开,横向再收一档 padding(真源侧栏口径)。
  /// 行组件与「我的关注」页**共用** [ZishuFollowRowItem](真源口径:侧栏
  /// 与页面只有一套行视图 —— 分类/主播名/标题/人数四列,hover/按压态
  /// 同源,不再各写一套)。
  Widget _buildCompactList(List<LiveRoom> rooms) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.sm),
      itemCount: rooms.length,
      itemBuilder: (context, index) => ZishuFollowRowItem(room: rooms[index]),
    );
  }

  /// 封面网格:侧栏窄列固定 2 列(真源 compact 口径),卡片复用「我的关注」
  /// 页同款 [ZishuRoomCard],卡高 = 封面 16:9 + 元信息两行(预算 58 与页面
  /// 网格同源),由实际列宽反推纵横比避免窄列下溢出。
  Widget _buildCardGrid(BuildContext context, List<LiveRoom> rooms) {
    const spacing = AppSpacing.sm;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(0.0, constraints.maxWidth - AppSpacing.sm * 2);
        final cardWidth = math.max(1.0, (width - spacing) / 2);
        final metaHeight = metaHeightFor(58, context);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: cardWidth / (cardWidth * 9 / 16 + metaHeight),
          ),
          itemCount: rooms.length,
          // compact 语义对齐真源:侧栏网格走关注卡紧凑形态(隐藏统计/
          // 操作行,元信息只主播名+标题),非浏览卡。
          itemBuilder: (context, index) => ZishuFollowEntryCard(room: rooms[index], compact: true),
        );
      },
    );
  }
}

/// 侧栏关注列表底部提示(真源 follow_panel.dart:225-243 `_FollowMoreHint`
/// 复刻,对齐 web `.follow-recommend__more-hint`):还有更多时引导滚动 ——
/// 列表滚到底部会自动再放一页,这行提示是给用户的可见信号。
class _FollowMoreHint extends StatelessWidget {
  const _FollowMoreHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        // 真源同为字面量、本仓无对应 i18n key(搜索页的 load_more_results
        // 是按钮文案,语义不合),按规约用中文常量并记录。
        '向下滚动加载更多…',
        textAlign: TextAlign.center,
        style: context.textCaption,
      ),
    );
  }
}

/// 空态提示(真源 `_PanelHint` 的样式复刻):图标 + 标题 + 说明居中纵排。
class _FollowPanelHint extends StatelessWidget {
  const _FollowPanelHint({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: tokens.surfaceRaised),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: TextStyle(
                fontSize: AppFontSize.bodySecondary,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center, style: context.textCaption),
          ],
        ),
      ),
    );
  }
}
