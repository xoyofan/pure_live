import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/compact_switch.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/room_reminder_store.dart';
import 'package:pure_live/zishu_app/features/play/room_stats_provider.dart';
import 'package:pure_live/zishu_app/features/play/super_follow_controller.dart';
import 'package:pure_live/zishu_app/features/play/zishu_chat_tab.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_follow_panel.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_meta_bar.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_recommend_panel.dart';
import 'package:pure_live/zishu_app/features/play/zishu_stage_hint.dart';
import 'package:pure_live/zishu_app/features/settings/zishu_settings_view.dart';
import 'package:url_launcher/url_launcher.dart';

/// 会话级侧栏 tab 记忆(zishu `PlaySidePanelPrefs.tabIndex` 的最小等价物):
/// 文件级可变 int 记录上次停留 tab,切房重建侧栏时作为 initialIndex 恢复,
/// dispose 时由 [_SidePanelTabMemory] 回写。仅进程内记忆,不做持久化。
int _lastSidePanelTab = 0;

/// zishu 播放页侧栏(对齐 zishu play_side_panel):
/// surface 底 + 左缘描边;头部(贴边出血头像 + 三行信息 + 头内纵向双 chip)+
/// 「聊天/关注/推荐/设置」四等分 tab(高 32,默认聊天)。
///
/// 内容接线(对齐 zishu play_side_panel 的 part 拆分,本仓库拆独立文件):
/// - 聊天 → `ZishuChatTab` 纯聊天流(对齐 zishu _ChatTab,替换原
///   DanmakuTabView 四子页签);
/// - 关注 → `ZishuPlayFollowPanel`(真源 _FollowPanel 适配:紧凑列表/
///   封面网格 + 平台筛选,只显在播);
/// - 推荐 → `ZishuPlayRecommendPanel`(真源 _RecommendPanel 适配:2 列
///   封面网格 + 骨架 + 滚动加载,热门页分类房间流);
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
                  // tabAlignment: fill —— 仓库全局 tabBarTheme
                  // (lib/common/style/theme.dart)设了 TabAlignment.center,
                  // 渗入本 TabBar 后四 tab 不等分、挤在左侧;真源 app 无全局
                  // tabBarTheme 走默认 fill,这里显式声回。
                  tabAlignment: TabAlignment.fill,
                  tabs: [
                    // 首 tab 文案「聊天」对齐 zishu play_side_panel.dart:290
                    // (Tab(text:'聊天'),四 tab 序 0=聊天 1=关注 2=推荐 3=设置)。
                    // i18n key `chat` 已升级问询获批:zh「聊天」/en "Chat",
                    // json 由主会话合并阶段补入。
                    KeyedSubtree(
                      key: const Key('play-side-tab-chat'),
                      child: Tab(text: i18n('chat')),
                    ),
                    KeyedSubtree(
                      key: const Key('play-side-tab-follow'),
                      child: Tab(text: i18n('favorites_title')),
                    ),
                    KeyedSubtree(
                      key: const Key('play-side-tab-recommend'),
                      child: Tab(text: i18n('recommended')),
                    ),
                    KeyedSubtree(
                      key: const Key('play-side-tab-settings'),
                      child: Tab(text: i18n('settings_title')),
                    ),
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
                    // 关注/推荐:面板化接线(对齐 zishu _FollowPanel /
                    // _RecommendPanel 的薄壳挂接,实现见各自新文件)。
                    const ZishuPlayFollowPanel(),
                    ZishuPlayRecommendPanel(room: room),
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

/// 关注 tab 与推荐 tab 的面板实现分别见 zishu_play_follow_panel.dart /
/// zishu_play_recommend_panel.dart(对齐真源 side_panel/follow_panel.dart、
/// recommend_panel.dart 的拆文件方式)。

/// 侧栏信息头(对齐 zishu side_panel_header `_SideHeader` 三行结构):
/// Row[贴边出血头像(64 宽 × 头高,仅右下小圆角) | Expanded 三行 Column
/// ①主播名(w600,开播走 liveBadge 强调)+「关注 N」普通次级文字
/// ②分类文字 + 提醒 pill + 网页 pill(_SideTextAction,描边胶囊对齐真源
///   side_panel_header.dart:334-408)
/// ③统计行 FittedBox(观众/VIP/SVIP 三列,FA 字形 + 平台列名;VIP/SVIP 走
///   room_stats_provider 契约,超时/缺数据「—」)]
/// | 右侧纵向关注/超关双 chip(对齐 zishu `_SideActions` 头内排布)。
class _SideHeader extends StatefulWidget {
  const _SideHeader({required this.room, required this.isLive});

  final LiveRoom room;
  final bool isLive;

  @override
  State<_SideHeader> createState() => _SideHeaderState();
}

/// 统计行的 Font Awesome 字形(对齐真源 AppIcons.eye/crown/gem:eye=0xf06e、
/// crown=0xf521、gem=0xf3a5;Material Icons 无 crown/gem 对应字形)。字体
/// assets/fonts/fa-solid-900.ttf 已在 pubspec 注册 family FontAwesome。
const IconData _statIconEye = IconData(0xf06e, fontFamily: 'FontAwesome');
const IconData _statIconCrown = IconData(0xf521, fontFamily: 'FontAwesome');
const IconData _statIconGem = IconData(0xf3a5, fontFamily: 'FontAwesome');

class _SideHeaderState extends State<_SideHeader> {
  /// VIP/SVIP 统计(契约 fetchRoomVipStats;10s 超时/失败给空值 → 「—」)。
  RoomVipStats _vipStats = const RoomVipStats();

  @override
  void initState() {
    super.initState();
    _loadVipStats();
  }

  @override
  void didUpdateWidget(_SideHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换房(platform+roomId 变)才重拉:旧房统计先清空,不闪现错房数值。
    if (oldWidget.room.identityKey != widget.room.identityKey) {
      _vipStats = const RoomVipStats();
      _loadVipStats();
    }
  }

  /// 拉取 VIP/SVIP 统计:10s 内未返回按「—」处理(.timeout 的 onTimeout 给
  /// 空 RoomVipStats);回写前查 mounted,超时后/已卸载不再 setState。
  Future<void> _loadVipStats() async {
    final site = widget.room.platform?.trim() ?? '';
    final roomId = widget.room.normalizedRoomId;
    if (site.isEmpty || roomId.isEmpty) return;
    try {
      final stats = await fetchRoomVipStats(
        site: site,
        roomId: roomId,
      ).timeout(const Duration(seconds: 10), onTimeout: () => const RoomVipStats());
      if (!mounted) return;
      setState(() => _vipStats = stats);
    } catch (_) {
      // 拉取失败等同未取到:保持「—」,不伪造数据。
    }
  }

  /// 人气取值:各平台字段不齐,按 人气/观看/在线/累计 择先非空,缺省「—」;
  /// 展示统一万进制:过 readableCount(空/非数字原样返回,「—」不变)。
  String get _popularityLabel {
    for (final value in [
      widget.room.popularity,
      widget.room.watching,
      widget.room.onlineViewers,
      widget.room.totalViewers,
    ]) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty) return readableCount(v);
    }
    return '—';
  }

  /// 关注数:`room.followers` 非空才渲染该列(null/空白 = 无数据,不伪造)。
  String? get _followersText {
    final v = widget.room.followers?.trim() ?? '';
    if (v.isEmpty) return null;
    return readableCount(v);
  }

  /// 统计行第二/三列列名按平台(对齐真源 live_parser site_display.dart 的
  /// SiteDisplaySpec.roomStats:douyu=贵宾/钻粉、huya=贵宾/超粉、
  /// bilibili=粉丝勋章/大航海、douyin=粉丝团/会员);null = 该平台无 VIP 档
  /// 列,只渲染观众列。列名无既有 i18n key,中文常量(见轨道报告)。
  ({String vip, String svip})? get _vipColumnLabels => switch (widget.room.normalizedPlatformId) {
    'douyu' => (vip: '贵宾', svip: '钻粉'),
    'huya' => (vip: '贵宾', svip: '超粉'),
    'bilibili' => (vip: '粉丝勋章', svip: '大航海'),
    'douyin' => (vip: '粉丝团', svip: '会员'),
    _ => null,
  };

  /// 当前房间 web 页地址(对齐真源 roomExternalUrl,play_side_panel.dart:372-384
  /// 的 pure_live 适配):room.link 非空且 http 开头优先(解析侧实际进入的
  /// 页面);否则按平台拼官方 web 房间页;拼不出 = null(按钮禁用)。
  String? get _externalUrl {
    final link = widget.room.link?.trim() ?? '';
    if (link.isNotEmpty && link.startsWith('http')) return link;
    final id = widget.room.normalizedRoomId;
    if (id.isEmpty) return null;
    return switch (widget.room.normalizedPlatformId) {
      'douyu' => 'https://www.douyu.com/$id',
      'huya' => 'https://www.huya.com/$id',
      'bilibili' => 'https://live.bilibili.com/$id',
      _ => null,
    };
  }

  /// 系统默认浏览器打开 web 房间页(external 模式)。失败静默:打开属低频
  /// 外围动作,不打断播放(真源力度同为「失败仅提示」;本仓库提示通道是
  /// 舞台内浮层,此处不再叠层)。
  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // 无浏览器/平台不支持时吞掉,不打断播放。
    }
  }

  /// 统计值未取到(null/空白)显示「—」,不伪造数据。
  String _orDash(String? raw) {
    final v = raw?.trim() ?? '';
    return v.isEmpty ? '—' : v;
  }

  /// 统计行 VIP/SVIP 两列(列名随平台,值取契约统计,未取到「—」);
  /// 无 VIP 档列的平台返回空,只留观众列。
  List<Widget> get _vipStatColumns {
    final labels = _vipColumnLabels;
    if (labels == null) return const [];
    final tokens = context.tokens;
    final vip = _orDash(_vipStats.vip);
    final svip = _orDash(_vipStats.svip);
    return [
      const SizedBox(width: AppSpacing.xs),
      _SideStatValue(
        key: const Key('play-side-stat-vip'),
        icon: _statIconCrown,
        value: vip,
        color: tokens.statVip,
        tooltip: '${labels.vip} $vip',
      ),
      const SizedBox(width: AppSpacing.xs),
      _SideStatValue(
        key: const Key('play-side-stat-svip'),
        icon: _statIconGem,
        value: svip,
        color: tokens.statSvip,
        tooltip: '${labels.svip} $svip',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final room = widget.room;
    final isLive = widget.isLive;
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
                  // 第二行:分类文字 + 提醒/网页 pill(对齐真源
                  // side_panel_header.dart:138-184:分类 Flexible 挤压,pill
                  // 恒常驻;pill 间隔 4/3 为真源字面值)。
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (category.isNotEmpty)
                        Flexible(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textSecondary.copyWith(fontSize: AppFontSize.bodySecondary, height: 1.2),
                          ),
                        ),
                      if (category.isNotEmpty) const SizedBox(width: 4),
                      // 提醒 pill:未关注禁用(对齐真源 side_panel_header.dart:167-170
                      // 的禁用口径),点击切本地提醒标记(RoomReminderStore,Hive
                      // 持久化);Obx 同时跟踪收藏态与提醒集合的即时值。
                      Obx(() {
                        final followed = SettingsService.to.fav.isFavorite(room);
                        final remindOn = RoomReminderStore.to.isRemind(room);
                        return _SideTextAction(
                          key: const Key('play-side-notify'),
                          icon: remindOn ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                          label: remindOn ? '提醒中' : '提醒',
                          // tooltip 照抄真源 side_panel_header.dart:167-169。
                          tooltip: followed ? (remindOn ? '已开启开播/下播提醒，点击关闭' : '开启开播/下播提醒') : '关注后可开启开播提醒',
                          onPressed: followed ? () => RoomReminderStore.to.toggle(room) : null,
                          active: remindOn,
                        );
                      }),
                      const SizedBox(width: 3),
                      _SideTextAction(
                        key: const Key('play-side-external'),
                        icon: Icons.open_in_browser_rounded,
                        label: '网页',
                        tooltip: '打开直播间页面',
                        onPressed: _externalUrl == null ? null : () => unawaited(_openExternal(_externalUrl!)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 第三行:统计 = 观众 + VIP/SVIP(列名按平台,对齐真源
                  // live_parser site_display.dart;其余平台只渲染观众列;
                  // 「关注 N」列已删 —— 与行1重复,真源无此列)。
                  // FittedBox(scaleDown) 兜底窄栏/大字号溢出(对齐真源统计区
                  // 的等比缩放策略)。
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SideStatValue(
                            key: const Key('play-side-stat-audience'),
                            icon: _statIconEye,
                            value: _popularityLabel,
                            color: tokens.statAudience,
                            tooltip: '观众 $_popularityLabel',
                          ),
                          ..._vipStatColumns,
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
  const _SideStatValue({super.key, required this.icon, required this.value, required this.color, this.tooltip});

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
          // 数字等宽(fontFeatures)对齐真源 _StatValue(side_panel_header.dart:641)。
          style: context.textBody.copyWith(
            fontSize: AppFontSize.body,
            height: 1,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    final message = tooltip;
    if (message == null) return content;
    return Tooltip(message: message, child: content);
  }
}

/// 侧栏头第二排的小文字按钮:提醒/网页显示为图标 + 文字。StadiumBorder
/// 描边胶囊;[active] 时走 accent 强调(几何/交互态逐项对齐真源
/// _SideTextAction,side_panel_header.dart:334-408)。
///
/// 交互态:hover 常态抬 surfaceRaised、激活态 accent 24%;splash/highlight/
/// focus 走 AppStateLayer 低 alpha 档 —— 均只改颜色,不动尺寸;禁用态由
/// InkWell 自行忽略交互,连底色都不给(不加灰罩)。
class _SideTextAction extends StatelessWidget {
  const _SideTextAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;

  /// null = 禁用(未关注无可提醒目标 / 无稳定 web url)。
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onPressed != null;
    // 开启态 = 有 accent 底色/描边;禁用态连底色都不给。
    final on = active && enabled;
    final fg = !enabled
        ? tokens.textSecondary.withValues(alpha: 0.55)
        : active
        ? tokens.accent
        : tokens.textSecondary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? tokens.accent.withValues(alpha: 0.14) : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: on ? tokens.accent.withValues(alpha: 0.55) : tokens.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          // hover:激活态在 accent 底色上再深一档;常态透明底抬 surfaceRaised。
          hoverColor: on ? tokens.accent.withValues(alpha: 0.24) : tokens.surfaceRaised,
          // splash/highlight/focus:accent 低 alpha 档(禁用态由 InkWell 忽略)。
          splashColor: AppStateLayer.splashOf(tokens.accent),
          highlightColor: AppStateLayer.pressedOf(tokens.accent),
          focusColor: AppStateLayer.focusOf(tokens.accent),
          child: Padding(
            // 几何对齐真源:水平 5 / 垂直 1.5,图标 12,图字间距 2。
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: fg),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: AppFontSize.label, height: 1.2, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 头部右侧纵向双 chip(对齐 zishu `_SideActions`:59 宽、上下 Expanded
/// 充满头高、间隔 2):关注(红系,接既有房间收藏)+ 超级关注(紫系,本地
/// 标记)。提醒/网页入口已上移到第二行 pill(_SideTextAction),不在此列。
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
              // 行1:弹幕开关(hideDanmaku,取反 = 显示态)。开关语义对齐
              // zishu settings_panel「聊天」行(value = 开)与播放器控制条
              // 同款绑定(zishu_player_controls.dart:689:value: show,
              // onChanged: hide = !value);控件用全局 CompactSwitch(对齐
              // 真源 _SettingRow 的开关密度)。
              _SettingsRow(
                label: i18n('danmaku'),
                trailing: CompactSwitch(
                  key: const Key('play-side-setting-danmaku'),
                  value: !danmaku.hideDanmaku.v,
                  onChanged: (value) => danmaku.hideDanmaku.v = !value,
                ),
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
