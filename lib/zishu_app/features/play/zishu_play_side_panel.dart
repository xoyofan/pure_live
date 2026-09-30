import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// zishu 播放页侧栏骨架(对齐 zishu play_side_panel):
/// surface 底 + 左缘描边;头部(头像 + 名称 + 人气)+「聊天/关注/推荐/设置」
/// 四等分 tab(高 32,默认聊天)。
///
/// 内容接线点(本轮全部占位,见各 tab 注释):
/// - 聊天 → 既有 `DanmakuTabView()`(含弹幕列表/超级 chat/弹幕设置/屏蔽);
/// - 关注 → `FavoriteController` 数据源;
/// - 推荐 → 热门页 `PopularController` 分类房间流;
/// - 设置 → 跳既有 pure_live 设置路由。
class ZishuPlaySidePanel extends StatelessWidget {
  const ZishuPlaySidePanel({super.key, required this.room, required this.isLive});

  /// 当前房间快照(既有控制器 `controller.state.value.room.detail`,
  /// 缺 detail 时为 `controller.room`):只取展示字段,不做解析。
  final LiveRoom room;

  /// 直播中(驱动名称强调色)。
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(left: BorderSide(color: tokens.border)),
      ),
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SideHeader(room: room, isLive: isLive),
            // 高度对齐 web `--el-tabs-header-height: 2rem`(32px)。
            SizedBox(
              height: 32,
              child: TabBar(
                tabs: const [
                  Tab(text: '聊天'),
                  Tab(text: '关注'),
                  Tab(text: '推荐'),
                  Tab(text: '设置'),
                ],
                labelColor: tokens.accent,
                unselectedLabelColor: tokens.textSecondary,
                indicatorColor: tokens.accent,
                indicatorWeight: 2,
                dividerColor: tokens.border,
                labelStyle: const TextStyle(fontSize: AppFontSize.body, fontWeight: FontWeight.w600, height: 1.15),
                unselectedLabelStyle: const TextStyle(
                  fontSize: AppFontSize.body,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
                labelPadding: EdgeInsets.zero,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) return tokens.accent.withValues(alpha: 0.24);
                  if (states.contains(WidgetState.pressed)) return tokens.accent.withValues(alpha: 0.16);
                  if (states.contains(WidgetState.hovered)) return tokens.surfaceRaised;
                  return null;
                }),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // 聊天:既有弹幕页签整体复用(弹幕列表/超级chat/设置/屏蔽),
                  // GetView<LivePlayController> 与播放路由同实例。
                  const DanmakuTabView(),
                  _FollowTab(room: room),
                  _RecommendTab(platform: room.platform ?? ''),
                  const _SettingsEntries(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 关注 tab:当前房间收藏操作 + 「关注中(开播)」房间行,点击换房。
/// 数据源 `SettingsService.to.fav`(本机持久化),复用 RoomCard 同款
/// addRoomDurably/removeRoomDurably 语义。
class _FollowTab extends StatelessWidget {
  const _FollowTab({required this.room});

  final LiveRoom room;

  Future<void> _toggleFavorite() async {
    final favorites = SettingsService.to.fav;
    try {
      if (favorites.isFavorite(room)) {
        final changed = await favorites.removeRoomDurably(room);
        if (changed) EventBus.instance.emit('changeFavorite', false);
      } else {
        final changed = await favorites.addRoomDurably(room);
        if (changed) EventBus.instance.emit('changeFavorite', true);
      }
    } catch (_) {
      ToastUtil.show(i18n('favorite_changes_save_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Obx(() {
      final isFollowed = SettingsService.to.fav.isFavorite(room);
      final liveRooms = SettingsService.to.fav.favoriteRooms.v.where((r) => r.isLiveNow).toList(growable: false);
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // 当前房间收藏:大操作行(星标 + 文案 + 状态)。
          InkWell(
            onTap: _toggleFavorite,
            borderRadius: AppRadius.allSm,
            hoverColor: tokens.surfaceRaised,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: isFollowed ? tokens.brand.withValues(alpha: 0.12) : tokens.surfaceRaised.withValues(alpha: 0.4),
                borderRadius: AppRadius.allSm,
                border: Border.all(color: isFollowed ? tokens.brand : tokens.border),
              ),
              child: Row(
                children: [
                  Icon(
                    isFollowed ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: isFollowed ? tokens.brand : tokens.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isFollowed ? i18n('followed') : i18n('follow'),
                      style: context.textBody.copyWith(
                        fontSize: AppFontSize.subtitle,
                        fontWeight: FontWeight.w600,
                        color: isFollowed ? tokens.brand : tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (liveRooms.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
              child: Text('${i18n('online_room_title')} · ${liveRooms.length}', style: context.textSecondary),
            ),
            for (final live in liveRooms.take(30)) _RecommendRow(room: live, dense: true),
          ],
        ],
      );
    });
  }
}

/// 推荐 tab:同平台热门流(热门页分页控制器 tag=platform),行项点击换房。
/// 无该站点控制器(iptv 等)或未注册时给空态。
class _RecommendTab extends StatefulWidget {
  const _RecommendTab({required this.platform});

  final String platform;

  @override
  State<_RecommendTab> createState() => _RecommendTabState();
}

class _RecommendTabState extends State<_RecommendTab> {
  bool _kicked = false;

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform;
    if (platform.isEmpty || !Get.isRegistered<BasePageScrollAndStateBone<LiveRoom>>(tag: platform)) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: zishu.EmptyView(icon: Icons.live_tv_rounded, message: i18n('empty_live_title')),
      );
    }
    final controller = Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: platform);
    if (!_kicked && controller.list.isEmpty && !controller.loadding.value) {
      _kicked = true;
      controller.loadData();
    }
    return Obx(() {
      final list = controller.list;
      if (list.isEmpty) {
        return Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: context.tokens.accent),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        itemCount: list.length,
        itemBuilder: (context, index) => _RecommendRow(room: list[index]),
      );
    });
  }
}

/// 推荐行:16:9 小封面 + 标题/主播 + 人气,点击进房。
class _RecommendRow extends StatelessWidget {
  const _RecommendRow({required this.room, this.dense = false});

  final LiveRoom room;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final coverUrl = normalizeNetworkImageUrl(room.cover);
    return InkWell(
      onTap: () => AppNavigator.toLiveRoomDetail(liveRoom: room),
      borderRadius: AppRadius.allSm,
      hoverColor: tokens.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: dense ? 72 : 88,
              height: dense ? 40.5 : 49.5,
              child: ClipRRect(
                borderRadius: AppRadius.allSm,
                child: coverUrl.isEmpty
                    ? ColoredBox(color: tokens.surfaceRaised)
                    : CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        httpHeaders: networkImageHeaders(coverUrl),
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        errorWidget: (_, _, _) => ColoredBox(color: tokens.surfaceRaised),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.title?.trim().isNotEmpty == true ? room.title! : (room.nick ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textBody.copyWith(fontSize: AppFontSize.body, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 11, color: tokens.statAudience),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          room.onlineViewers ?? room.popularity ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textCaption.copyWith(
                            fontSize: AppFontSize.caption,
                            color: tokens.statAudience,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 侧栏信息头:头像贴边出血(64 宽 × 72 高)+ 名称 + 人气行。
/// 对齐 zishu _SideHeader 的排版口径(本轮省略分类/关注/超关操作区)。
class _SideHeader extends StatelessWidget {
  const _SideHeader({required this.room, required this.isLive});

  final LiveRoom room;
  final bool isLive;

  /// 人气取值:各平台字段不齐,按 人气/观看/在线/累计 择先非空,缺省「—」。
  String get _popularityLabel {
    for (final value in [room.popularity, room.watching, room.onlineViewers, room.totalViewers]) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nick = room.nick?.trim() ?? '';
    final avatar = room.avatar?.trim() ?? '';
    final fallbackText = nick.isEmpty ? '?' : nick.substring(0, 1);
    Widget avatarContent = avatar.isEmpty
        ? ColoredBox(
            color: tokens.surfaceRaised,
            child: Center(
              child: Text(
                fallbackText,
                style: TextStyle(
                  fontSize: AppFontSize.display,
                  fontWeight: FontWeight.w700,
                  color: isLive ? tokens.liveBadge : tokens.textSecondary,
                ),
              ),
            ),
          )
        : Image.network(
            avatar,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: tokens.surfaceRaised,
              child: Center(
                child: Text(
                  fallbackText,
                  style: TextStyle(
                    fontSize: AppFontSize.display,
                    fontWeight: FontWeight.w700,
                    color: isLive ? tokens.liveBadge : tokens.textSecondary,
                  ),
                ),
              ),
            ),
          );
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 头像贴边出血:占满头高,仅右下角小圆角(对齐 zishu)。
          SizedBox(
            width: 64,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomRight: Radius.circular(AppRadius.sm)),
              child: avatarContent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nick.isNotEmpty ? nick : '主播信息',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTitle.copyWith(
                      fontSize: AppFontSize.subtitle,
                      fontWeight: FontWeight.w600,
                      color: isLive ? tokens.liveBadge : tokens.textPrimary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 13, color: tokens.statAudience),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _popularityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textBody.copyWith(fontSize: AppFontSize.body, color: tokens.statAudience),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 设置 tab:几行入口,跳既有 pure_live 设置路由(路由均已在 app_pages 注册)。
class _SettingsEntries extends StatelessWidget {
  const _SettingsEntries();

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, IconData icon, String route})>[
      (label: i18n('settings_title'), icon: Icons.settings_outlined, route: RoutePath.kSettings),
      (label: i18n('danmaku_filter'), icon: Icons.filter_alt_outlined, route: RoutePath.kSettingsDanmuShield),
      (label: i18n('history'), icon: Icons.history_rounded, route: RoutePath.kHistory),
      (label: i18n('about'), icon: Icons.info_outline_rounded, route: RoutePath.kAbout),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        for (final entry in entries)
          _EntryRow(label: entry.label, icon: entry.icon, onTap: () => Get.toNamed(entry.route)),
      ],
    );
  }
}

/// 设置入口行:图标 + 文案 + 右缘 chevron,hover 抬到 surfaceRaised。
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      hoverColor: tokens.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tokens.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textBody.copyWith(fontSize: AppFontSize.body),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 14, color: tokens.textSecondary),
          ],
        ),
      ),
    );
  }
}
