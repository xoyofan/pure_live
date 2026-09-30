import 'package:pure_live/common/index.dart';
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
                  // 后续接线:此处换 `DanmakuTabView()`(GetView<LivePlayController>,
                  // 无参构造,直接可用),其内含 弹幕列表/超级chat/弹幕设置/屏蔽 四子 tab。
                  _placeholder(context, Icons.forum_outlined, '弹幕聊天待接入'),
                  // 后续接线:FavoriteController 的关注列表(含关注/超关操作)。
                  _placeholder(context, Icons.favorite_border_rounded, '关注列表待接入'),
                  // 后续接线:PopularController 按当前房间分类拉推荐房间,点击进房。
                  _placeholder(context, Icons.recommend_outlined, '推荐内容待接入'),
                  const _SettingsEntries(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: zishu.EmptyView(icon: icon, message: message),
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
