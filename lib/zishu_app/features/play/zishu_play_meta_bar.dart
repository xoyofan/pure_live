import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/super_follow_controller.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_side_panel.dart';

/// 移动端播放页「直播信息条」:窄屏(<768)堆叠布局下视频正下方的紧凑
/// 主播/数据条,移植自 zishu_flutter
/// `lib/src/features/play/widgets/play_meta_bar.dart` 的 `PlayMetaBar`
/// (web 参考 `SideHeader.vue` 移动竖屏堆叠形态:52px 圆角头像 + 昵称 +
/// 统计 Wrap + 右贴边竖排「关注/超关」列宽 59,关注红系、超关紫系)。
///
/// 挂接:仅当 [ZishuPlaySidePanel.compactHeader] 为 true(窄屏堆叠分支,
/// zishu_play_view.dart 的 `width < AppBreakpoints.phone`)时由侧栏以本
/// 组件替代桌面信息头 `_SideHeader`;桌面(>=768)不受影响。关注状态与
/// 桌面信息头共用同一数据源(`SettingsService.to.fav` / 超关
/// [SuperFollowController]),同一时刻只渲染一处,不重复挂锚点。
///
/// 数据诚实性(沿用侧栏信息头同口径):关注数 `room.followers` 非空才出
/// 数值、否则「—」;人气按 人气/观看/在线/累计 择先非空、全空「—」;
/// 开播时间 pure_live 无 `startedAt` 字段、整项省略(与侧栏信息头既定
/// 移植口径一致);弹幕总数上游无字段,恒为「—」不伪造。
class ZishuPlayMetaBar extends StatelessWidget {
  const ZishuPlayMetaBar({super.key, required this.room, required this.isLive});

  /// 当前房间快照(与侧栏同一份 `LiveRoom`)。
  final LiveRoom room;

  /// 直播中(驱动头像描边与昵称强调色)。
  final bool isLive;

  /// 头像尺寸(web 竖屏堆叠基准,真源 `_kAvatarSize`)。
  static const double _kAvatarSize = 52;

  /// 「关注 / 超关」按钮列宽(web `3.7rem` ≈ 59px,真源 `_kActionsWidth`)。
  static const double _kActionsWidth = 59;

  /// 统计格图标尺寸(真源 `_kStatIconSize`)。
  static const double _kStatIconSize = 12;

  /// 人气取值:与侧栏信息头 `_SideHeader._popularityLabel` 同链路,
  /// 各平台字段不齐,按 人气/观看/在线/累计 择先非空,缺省「—」。
  String get _popularityLabel {
    for (final value in [room.popularity, room.watching, room.onlineViewers, room.totalViewers]) {
      final v = value?.trim() ?? '';
      if (v.isNotEmpty) return readableCount(v);
    }
    return '—';
  }

  /// 关注数:空则「—」(真源 formatFollowersValue 对 null/空出「—」)。
  String get _followersValue {
    final v = room.followers?.trim() ?? '';
    if (v.isEmpty) return '—';
    return readableCount(v);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final anchor = room.nick?.trim() ?? '';
    return Container(
      key: const Key('play-meta-bar'),
      // 头像左侧贴边出血(web 负 margin),无左 padding。
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MetaAvatar(avatar: room.avatar?.trim() ?? '', label: anchor, live: isLive),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anchor.isNotEmpty ? anchor : '主播信息',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.body,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: isLive ? tokens.liveBadge : tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 2,
                    children: [
                      _MetaStat(
                        key: const Key('play-meta-stat-followers'),
                        icon: Icons.favorite_border_rounded,
                        iconColor: tokens.playFollowText,
                        label: i18n('follow'),
                        value: _followersValue,
                      ),
                      _MetaStat(
                        key: const Key('play-meta-stat-audience'),
                        icon: Icons.people_alt_outlined,
                        iconColor: tokens.statAudience,
                        // 「人气」无既有 i18n key(字典内 audience_popularity
                        // 为「热度」,语义不同),沿用真源中文常量(同「超关」先例)。
                        label: '人气',
                        value: _popularityLabel,
                      ),
                      _MetaStat(
                        key: const Key('play-meta-stat-danmaku'),
                        icon: Icons.chat_bubble_outline_rounded,
                        iconColor: tokens.textSecondary,
                        label: i18n('danmaku'),
                        // 弹幕总数上游无字段,恒「—」(真源同口径,不冒充)。
                        value: '—',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              width: _kActionsWidth,
              child: _MetaActions(room: room),
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆形头像:无图时以昵称首字兜底(与侧栏信息头同语义)。
class _MetaAvatar extends StatelessWidget {
  const _MetaAvatar({required this.avatar, required this.label, required this.live});

  final String avatar;
  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fallback = label.isEmpty ? '?' : label.substring(0, 1);
    final fallbackText = Center(
      child: Text(
        fallback,
        style: TextStyle(
          fontSize: AppFontSize.subtitle,
          fontWeight: FontWeight.w700,
          color: live ? tokens.liveBadge : tokens.textSecondary,
        ),
      ),
    );
    return Container(
      width: ZishuPlayMetaBar._kAvatarSize,
      height: double.infinity,
      // 左贴边出血 + 右下小圆角(真源 2px,几何常量非色值)。
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(2)),
        color: tokens.surfaceRaised,
        border: Border.all(color: live ? tokens.liveBadge : tokens.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatar.isEmpty
          ? fallbackText
          : Image.network(avatar, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallbackText),
    );
  }
}

/// 单个统计格:图标 + 「标签 值」。标签与值用次级色,图标色按项取 token。
class _MetaStat extends StatelessWidget {
  const _MetaStat({super.key, required this.icon, required this.iconColor, required this.label, required this.value});

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: AppSpacing.xl * 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ZishuPlayMetaBar._kStatIconSize, color: iconColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$label $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppFontSize.caption, height: 1.05, color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右贴边竖排「关注 / 超关」:与桌面侧栏 `_SideActionsColumn` 同数据源、
/// 同 token;chip 本体为真源 `_MetaActionButton` 的等价实现(桌面版为
/// play_side_panel.dart 私有 widget,样式不可跨文件复用)。
class _MetaActions extends StatelessWidget {
  const _MetaActions({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final superFollow = SuperFollowController.to;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Obx(() {
            // isFavorite 内部读 favoriteRooms(Rx),Obx 即时态。
            final followed = SettingsService.to.fav.isFavorite(room);
            return _MetaActionButton(
              key: const Key('play-side-follow-btn'),
              icon: followed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: followed ? i18n('followed') : i18n('follow'),
              selected: followed,
              colors: _MetaChipColors(
                background: tokens.playFollowBg,
                hoverBackground: tokens.playFollowBgHover,
                activeBackground: tokens.playFollowBgActive,
                border: tokens.playFollowBorder,
                foreground: tokens.playFollowText,
                activeForeground: tokens.playFollowTextActive,
              ),
              onPressed: () => unawaited(toggleRoomFavorite(room)),
            );
          }),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Obx(() {
            final isSuper = superFollow.isSuper(room);
            return _MetaActionButton(
              key: const Key('play-side-super-follow'),
              icon: isSuper ? Icons.star_rounded : Icons.star_border_rounded,
              // 「超关/已超关」无既有 i18n key,中文常量(与桌面 chip 同注释)。
              label: isSuper ? '已超关' : '超关',
              selected: isSuper,
              colors: _MetaChipColors(
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
    );
  }
}

/// 关注 / 超关 chip 的状态配色族(与桌面 `_SideChipColors` 同口径:
/// 红系 `playFollow*` / 紫系 `playSuper*`,六值全部来自 `context.tokens`)。
class _MetaChipColors {
  const _MetaChipColors({
    required this.background,
    required this.hoverBackground,
    required this.activeBackground,
    required this.border,
    required this.foreground,
    required this.activeForeground,
  });

  /// 常态底(未选中)。
  final Color background;

  /// hover 底(token `playFollowBgHover` / `playSuperBgHover`)。
  final Color hoverBackground;

  /// 已选中底 / 按下底。
  final Color activeBackground;

  final Color border;

  /// 常态文字与图标。
  final Color foreground;

  /// 已选中 / 按下时的文字与图标。
  final Color activeForeground;
}

/// 「关注 / 超关」chip(窄屏信息条版):与真源 `_MetaActionButton` 同构 ——
/// rest / hover / pressed 由 `AnimatedContainer`(AppMotion.fast + curve)
/// 着色,键盘焦点用 `AppFocus.ring` 外扩,hover/pressed 叠
/// `AppElevation.accentGlow`;只改颜色不动尺寸位置。
class _MetaActionButton extends StatefulWidget {
  const _MetaActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.colors,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final _MetaChipColors colors;
  final VoidCallback onPressed;

  @override
  State<_MetaActionButton> createState() => _MetaActionButtonState();
}

class _MetaActionButtonState extends State<_MetaActionButton> {
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
    final glow = _focused
        ? AppFocus.ring(tokens.accent)
        : (_hovered || _pressed ? AppElevation.accentGlow(colors.border) : null);
    return Tooltip(
      message: widget.label,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.allPill,
          border: Border.all(color: colors.border),
          boxShadow: glow,
        ),
        child: Material(
          // 透明壳只为 InkWell 提供墨水宿主;底色/描边由 AnimatedContainer 承担。
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.allPill,
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
            // 覆盖色从 chip 自身文字色推导(状态色由基色推导),不引入外来色相。
            splashColor: AppStateLayer.splashOf(colors.activeForeground),
            highlightColor: AppStateLayer.pressedOf(colors.activeForeground),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, size: 12, color: foreground),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
