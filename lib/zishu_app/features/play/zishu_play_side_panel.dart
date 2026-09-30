import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/empty_view.dart' as zishu;
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/super_follow_controller.dart';
import 'package:pure_live/zishu_app/features/play/zishu_chat_tab.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_meta_bar.dart';
import 'package:pure_live/zishu_app/features/play/zishu_stage_hint.dart';
import 'package:pure_live/zishu_app/features/settings/zishu_settings_view.dart';

/// 会话级侧栏 tab 记忆(zishu `PlaySidePanelPrefs.tabIndex` 的最小等价物):
/// 文件级可变 int 记录上次停留 tab,切房重建侧栏时作为 initialIndex 恢复,
/// dispose 时由 [_SidePanelTabMemory] 回写。仅进程内记忆,不做持久化。
int _lastSidePanelTab = 0;

/// zishu 播放页侧栏(对齐 zishu play_side_panel):
/// surface 底 + 左缘描边;头部(贴边出血头像 + 三行信息 + 头内纵向双 chip)+
/// 「聊天/关注/推荐/设置」四等分 tab(高 32,默认聊天)。
///
/// 内容接线:
/// - 聊天 → `ZishuChatTab` 纯聊天流(对齐 zishu _ChatTab,替换原
///   DanmakuTabView 四子页签);
/// - 关注 → `FavoriteController` 数据源;
/// - 推荐 → 热门页 `PopularController` 分类房间流;
/// - 设置 → 就地渲染弹幕设置(对齐 zishu settings_panel,非跳转列表)。
class ZishuPlaySidePanel extends StatelessWidget {
  const ZishuPlaySidePanel({super.key, required this.room, required this.isLive, this.compactHeader = false});

  /// 当前房间快照(既有控制器 `controller.state.value.room.detail`,
  /// 缺 detail 时为 `controller.room`):只取展示字段,不做解析。
  final LiveRoom room;

  /// 直播中(驱动名称强调色)。
  final bool isLive;

  /// 窄屏(移动竖屏堆叠)用移动「直播信息条」[ZishuPlayMetaBar] 代替
  /// 桌面信息头 `_SideHeader`(对齐 zishu `compactHeader` 口径:两者同源
  /// 数据与回调,仅排布不同;桌面(>=768)保持 false)。
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(left: BorderSide(color: tokens.border)),
      ),
      child: DefaultTabController(
        // 会话记忆:切房(pushReplacement)重建侧栏后,右侧仍停在上次的
        // tab(如「关注」),不再退回聊天(对齐 zishu initialIndex 口径)。
        initialIndex: _lastSidePanelTab.clamp(0, 3),
        length: 4,
        child: _SidePanelTabMemory(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 窄屏堆叠(compactHeader):信息条替代桌面信息头(对齐
              // zishu play_side_panel.dart:257-264 的挂接方式)。
              compactHeader ? ZishuPlayMetaBar(room: room, isLive: isLive) : _SideHeader(room: room, isLive: isLive),
              // 高度对齐 web `--el-tabs-header-height: 2rem`(32px)。
              SizedBox(
                height: 32,
                child: TabBar(
                  tabs: [
                    Tab(text: i18n('danmaku')),
                    Tab(text: i18n('favorites_title')),
                    Tab(text: i18n('recommended')),
                    Tab(text: i18n('settings_title')),
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
                    // 聊天:纯聊天流(对齐 zishu _ChatTab:正向列表最新在底 +
                    // 贴底跟随 + 「N 条新消息」跳底,无输入框/子页签)。
                    ZishuChatTab(room: room),
                    _FollowTab(room: room),
                    _RecommendTab(platform: room.platform ?? ''),
                    const _SettingsPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 监听 DefaultTabController 的落定索引,把最后停留 tab 写回文件级
/// `_lastSidePanelTab`(dispose 时兜底回写);仅会话记忆,不持久化。
class _SidePanelTabMemory extends StatefulWidget {
  const _SidePanelTabMemory({required this.child});

  final Widget child;

  @override
  State<_SidePanelTabMemory> createState() => _SidePanelTabMemoryState();
}

class _SidePanelTabMemoryState extends State<_SidePanelTabMemory> {
  TabController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.maybeOf(context);
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_handleTick);
      _controller = controller;
      _controller?.addListener(_handleTick);
    }
  }

  void _handleTick() {
    final controller = _controller;
    // indexIsChanging = true 是动画中途;落定(=false)才记,避免中途值。
    if (controller == null || controller.indexIsChanging) return;
    _lastSidePanelTab = controller.index.clamp(0, 3);
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      // dispose 时回写(子 widget 先于 DefaultTabController 销毁,索引仍有效)。
      if (!controller.indexIsChanging) {
        _lastSidePanelTab = controller.index.clamp(0, 3);
      }
      controller.removeListener(_handleTick);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 切换当前房间收藏:头部关注 chip、关注 tab 与窄屏信息条共用同一数据源
/// 与语义(`SettingsService.to.fav` 本机持久化,复用 RoomCard 同款
/// addRoomDurably/removeRoomDurably)。失败反馈走舞台内提示浮层
/// (对齐真源播放页 SnackBar 通道,替代原全局 ToastUtil)。
Future<void> toggleRoomFavorite(LiveRoom room) async {
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
    ZishuStageHint.show(i18n('favorite_changes_save_failed'));
  }
}

/// 关注 tab:当前房间收藏操作 + 「关注中(开播)」房间行,点击换房。
/// 数据源 `SettingsService.to.fav`(本机持久化)。
class _FollowTab extends StatelessWidget {
  const _FollowTab({required this.room});

  final LiveRoom room;

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
            onTap: () => toggleRoomFavorite(room),
            borderRadius: AppRadius.allSm,
            hoverColor: tokens.surfaceRaised,
            focusColor: Theme.of(context).focusColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: isFollowed ? tokens.brand.withValues(alpha: 0.12) : tokens.surfaceRaised.withValues(alpha: 0.4),
                borderRadius: AppRadius.allSm,
                border: Border.all(color: isFollowed ? tokens.brandBright : tokens.border),
              ),
              child: Row(
                children: [
                  Icon(
                    isFollowed ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: isFollowed ? tokens.brandBright : tokens.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isFollowed ? i18n('followed') : i18n('follow'),
                      style: context.textBody.copyWith(
                        fontSize: AppFontSize.subtitle,
                        fontWeight: FontWeight.w600,
                        color: isFollowed ? tokens.brandBright : tokens.textPrimary,
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
      focusColor: Theme.of(context).focusColor,
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
                          readableCount(room.onlineViewers ?? room.popularity ?? '—'),
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

/// 侧栏信息头(对齐 zishu side_panel_header `_SideHeader` 三行结构):
/// Row[贴边出血头像(64 宽 × 头高,仅右下小圆角) | Expanded 三行 Column
/// ①主播名(w600,开播走 liveBadge 强调)+「关注 N」普通次级文字
/// ②分类文字行(room.area,空则整行省;zishu 的提醒/网页按钮无对应能力,不渲染)
/// ③统计行 FittedBox(人气 + 关注数两列;VIP/SVIP pure_live 无数据源)]
/// | 右侧纵向关注/超关双 chip(对齐 zishu `_SideActions` 头内排布)。
class _SideHeader extends StatelessWidget {
  const _SideHeader({required this.room, required this.isLive});

  final LiveRoom room;
  final bool isLive;

  /// 人气取值:各平台字段不齐,按 人气/观看/在线/累计 择先非空,缺省「—」;
  /// 展示统一万进制:过 readableCount(空/非数字原样返回,「—」不变)。
  String get _popularityLabel {
    for (final value in [room.popularity, room.watching, room.onlineViewers, room.totalViewers]) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty) return readableCount(v);
    }
    return '—';
  }

  /// 关注数:`room.followers` 非空才渲染该列(null/空白 = 无数据,不伪造)。
  String? get _followersText {
    final v = room.followers?.trim() ?? '';
    if (v.isEmpty) return null;
    return readableCount(v);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final nick = room.nick?.trim() ?? '';
    final avatar = room.avatar?.trim() ?? '';
    final category = room.area?.trim() ?? '';
    final followersText = _followersText;
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
    // 信息头留出稳定的三行排版空间(对齐 zishu:昵称/分类/统计各占一行,
    // 高度随系统字号缩放,避免窄侧栏下互相挤压)。
    final headerHeight = MediaQuery.textScalerOf(context).scale(72.0);
    return Container(
      height: headerHeight,
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
                // 三行内容在剩余高度内均分(对齐 zishu spaceBetween)。
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行:主播名 + 「关注 N」普通次级文字(对齐 zishu:关注数
                  // 与昵称同行,纯文字无胶囊底/描边)。
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nick.isNotEmpty ? nick : '主播信息',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTitle.copyWith(
                            fontSize: AppFontSize.subtitle,
                            height: 1.18,
                            fontWeight: FontWeight.w600,
                            color: isLive ? tokens.liveBadge : tokens.textPrimary,
                          ),
                        ),
                      ),
                      if (followersText != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${i18n('follow')} $followersText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textSecondary.copyWith(fontSize: AppFontSize.bodySecondary, height: 1.2),
                        ),
                      ],
                    ],
                  ),
                  // 第二行:分类文字(pure_live 取 room.area;空则省行)。
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textSecondary.copyWith(fontSize: AppFontSize.bodySecondary, height: 1.2),
                    ),
                  ],
                  const SizedBox(height: 4),
                  // 第三行:统计行 FittedBox(scaleDown) 兜底窄栏/大字号溢出
                  // (对齐 zishu 统计区的等比缩放策略)。
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SideStatValue(
                            icon: Icons.visibility_outlined,
                            value: _popularityLabel,
                            color: tokens.statAudience,
                            tooltip: i18n('audience_popularity'),
                          ),
                          if (followersText != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            _SideStatValue(
                              icon: Icons.favorite_rounded,
                              value: followersText,
                              color: tokens.textSecondary,
                              tooltip: i18n('audience_followers'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 右侧纵向关注/超关双 chip(对齐 zishu:头内右侧 59 宽上下充满)。
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2, right: 2),
            child: _SideActionsColumn(room: room),
          ),
        ],
      ),
    );
  }
}

/// 统计列:图标 + 数值(对齐 zishu _StatValue 的紧凑排版)。
class _SideStatValue extends StatelessWidget {
  const _SideStatValue({required this.icon, required this.value, required this.color, this.tooltip});

  final IconData icon;
  final String value;
  final Color color;

  /// 悬浮说明(列名);null = 不加 Tooltip。
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.88)),
        const SizedBox(width: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textBody.copyWith(fontSize: AppFontSize.body, height: 1, color: color),
        ),
      ],
    );
    final message = tooltip;
    if (message == null) return content;
    return Tooltip(message: message, child: content);
  }
}

/// 头部右侧纵向双 chip(对齐 zishu `_SideActions`:59 宽、上下 Expanded
/// 充满头高、间隔 2):关注(红系,接既有房间收藏)+ 超级关注(紫系,本地
/// 标记)。zishu 的提醒/网页按钮 pure_live 无对应能力,不渲染。
class _SideActionsColumn extends StatelessWidget {
  const _SideActionsColumn({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final superFollow = SuperFollowController.to;
    return SizedBox(
      width: 59,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Obx(() {
              // isFavorite 内部读 favoriteRooms(Rx),Obx 即时态。
              final followed = SettingsService.to.fav.isFavorite(room);
              return _SideActionChip(
                selected: followed,
                icon: followed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: followed ? i18n('followed') : i18n('follow'),
                colors: _SideChipColors(
                  background: tokens.playFollowBg,
                  hoverBackground: tokens.playFollowBgHover,
                  activeBackground: tokens.playFollowBgActive,
                  border: tokens.playFollowBorder,
                  foreground: tokens.playFollowText,
                  activeForeground: tokens.playFollowTextActive,
                ),
                onPressed: () => toggleRoomFavorite(room),
              );
            }),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Obx(() {
              final isSuper = superFollow.isSuper(room);
              return _SideActionChip(
                selected: isSuper,
                icon: isSuper ? Icons.star_rounded : Icons.star_border_rounded,
                // 「超关/已超关」无既有 i18n key,中文常量(见报告)。
                label: isSuper ? '已超关' : '超关',
                colors: _SideChipColors(
                  background: tokens.playSuperBg,
                  hoverBackground: tokens.playSuperBgHover,
                  activeBackground: tokens.playSuperBgActive,
                  border: tokens.playSuperBorder,
                  foreground: tokens.playSuperText,
                  activeForeground: tokens.playSuperTextActive,
                ),
                onPressed: () => superFollow.toggle(room),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 关注 / 超关 chip 的状态配色族(红系 `playFollow*` / 紫系 `playSuper*`)。
/// 六值全部来自 `context.tokens`(深浅主题各自解析),widget 内不出现裸色值。
class _SideChipColors {
  const _SideChipColors({
    required this.background,
    required this.hoverBackground,
    required this.activeBackground,
    required this.border,
    required this.foreground,
    required this.activeForeground,
  });

  /// 常态底(未选中)。
  final Color background;

  /// hover 底。
  final Color hoverBackground;

  /// 已选中底 / 按下底(按下预告选中配色,对齐 zishu)。
  final Color activeBackground;

  /// 描边(常态与各态共用,不在状态间跳色)。
  final Color border;

  /// 常态文字与图标。
  final Color foreground;

  /// 已选中时的文字与图标。
  final Color activeForeground;
}

/// 「关注 / 超关」chip:4px 圆角(对齐 zishu _SideActionButton 的 AppRadius.sm),
/// 底色/描边随 rest / hover / pressed / selected 过渡(只改颜色,不动尺寸)。
class _SideActionChip extends StatefulWidget {
  const _SideActionChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final _SideChipColors colors;
  final VoidCallback onPressed;

  @override
  State<_SideActionChip> createState() => _SideActionChipState();
}

class _SideActionChipState extends State<_SideActionChip> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = widget.colors;
    // 已选中与按下共用 active 档:按下即「预告」选中配色,视觉不断层。
    final active = widget.selected || _pressed;
    final background = active ? colors.activeBackground : (_hovered ? colors.hoverBackground : colors.background);
    final foreground = active ? colors.activeForeground : colors.foreground;
    // 键盘焦点用 AppFocus.ring 外扩(对齐真源 _SideActionButton:
    // side_panel_header.dart:556-558「键盘焦点仍保留统一 focus ring」),
    // 只叠阴影不动尺寸位置。
    final glow = _focused ? AppFocus.ring(tokens.accent) : null;
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allSm,
        border: Border.all(color: colors.border),
        boxShadow: glow,
      ),
      child: Material(
        // 透明壳只为 InkWell 提供墨水宿主;底色/描边由 AnimatedContainer 承担。
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.allSm,
          onTap: widget.onPressed,
          onHover: (value) {
            if (_hovered != value) setState(() => _hovered = value);
          },
          onFocusChange: (value) {
            if (_focused != value) setState(() => _focused = value);
          },
          onTapDown: (_) {
            if (!_pressed) setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (_pressed) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (_pressed) setState(() => _pressed = false);
          },
          // 涟漪/按压覆盖色从 chip 自身文字色推导,不引入外来色相。
          splashColor: foreground.withValues(alpha: 0.12),
          highlightColor: foreground.withValues(alpha: 0.06),
          focusColor: Theme.of(context).focusColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 14, color: foreground),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.bodySecondary,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置 tab:就地渲染弹幕设置(对齐 zishu settings_panel 的就地面板,非
/// 跳转列表)。数据源 `SettingsService.to.danmaku`(Rx 即时态,值经 HiveRx
/// 自动持久化);末行保留「更多设置」跳既有设置路由。
class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context) {
    final danmaku = SettingsService.to.danmaku;
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          _SettingsGroup(
            title: i18n('danmaku_settings'),
            children: [
              // 行1:弹幕开关(hideDanmaku)。
              _SettingsRow(
                label: i18n('danmaku'),
                trailing: Switch(value: danmaku.hideDanmaku.v, onChanged: (value) => danmaku.hideDanmaku.v = value),
              ),
              // 行2:透明度(0-1,百分比显示,对齐既有弹幕设置页口径)。
              _SettingsSliderRow(
                label: i18n('opacity'),
                value: danmaku.danmakuOpacity.v,
                min: 0,
                max: 1,
                valueText: '${(danmaku.danmakuOpacity.v * 100).toInt()}%',
                onChanged: (value) => danmaku.danmakuOpacity.v = value,
              ),
              // 行3:字号(10-30,步进 1)。
              _SettingsSliderRow(
                label: i18n('font_size'),
                value: danmaku.danmakuFontSize.v,
                min: 10,
                max: 30,
                divisions: 20,
                valueText: '${danmaku.danmakuFontSize.v.toStringAsFixed(1)} px',
                onChanged: (value) => danmaku.danmakuFontSize.v = value,
              ),
              // 行4:速度(20-400 px/s)。
              _SettingsSliderRow(
                label: i18n('settings_danmaku_speed'),
                value: danmaku.danmakuSpeed.v,
                min: 20,
                max: 400,
                valueText: '${danmaku.danmakuSpeed.v.toInt()} px/s',
                onChanged: (value) => danmaku.danmakuSpeed.v = value,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsGroup(
            children: [
              // 更多设置:弹设置对话框(与顶栏/用户菜单/底栏同源,
              // openZishuSettingsDialog;不再 Get.toNamed 推页)。
              _SettingsEntryRow(
                label: i18n('settings_title'),
                onTap: () => unawaited(openZishuSettingsDialog(context)),
              ),
            ],
          ),
        ],
      );
    });
  }
}

/// 设置分组卡(对齐 zishu _SettingsGroup:surfaceSoft 卡 + accent 标题)。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.surfaceSoft,
        // 对齐 zishu .settings-group 圆角(--fluent-radius-sm ≈ 8)。
        borderRadius: AppRadius.allMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: AppFontSize.body,
                height: 1.2,
                color: tokens.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// 设置行(label + trailing 控件,对齐 zishu _SettingRow)。
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textBody.copyWith(fontSize: AppFontSize.body),
          ),
        ),
        trailing,
      ],
    );
  }
}

/// 设置滑杆行(对齐 zishu _SettingSliderRow:label 列约 52、滑杆弹性、
/// 数值右对齐)。
class _SettingsSliderRow extends StatelessWidget {
  const _SettingsSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueText,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String valueText;
  final ValueChanged<double> onChanged;

  /// null = 连续滑杆(透明度/速度与既有弹幕设置页一致)。
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textCaption.copyWith(fontSize: AppFontSize.body),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: tokens.accent,
              inactiveColor: tokens.border,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(valueText, textAlign: TextAlign.right, style: context.textCaption),
        ),
      ],
    );
  }
}

/// 设置入口行:图标 + 文案 + 右缘 chevron,hover 抬到 surfaceRaised。
class _SettingsEntryRow extends StatelessWidget {
  const _SettingsEntryRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      hoverColor: tokens.surfaceRaised,
      focusColor: Theme.of(context).focusColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.settings_outlined, size: 16, color: tokens.textSecondary),
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
