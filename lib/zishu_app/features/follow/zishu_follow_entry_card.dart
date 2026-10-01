/// 关注卡片密度条目(zishu_flutter
/// `features/follow/widgets/follow_entry_card.dart` 的 pure_live 适配版,
/// 页面态:封面 + 三行元信息)。
///
/// 结构(自上而下,对齐真源组件头注释):
/// - 16:9 封面:左下分类角标、左上超关 ★(本仓语义,SuperFollowController)、
///   右下在线角标;离线时整幅置灰压暗(灰度矩阵 + 60% 透明),底部压一条
///   「未开播」暗条(真源 `.follow-preview-offline`);右上平台角标本仓已
///   裁决不渲染(平台信息由页签上下文承载,ZishuRoomCard 同口径);
/// - 元信息区:主播名(平台品牌色)→ 标题 → 统计/操作行(平台圆点 +
///   在线数 + 三枚操作钮)。侧栏 compact 态只留主播名 + 标题两行
///   (真源 compact 口径,面板接线由播放页侧栏轨完成)。
///
/// 与真源的数据差异(妥协,均已记录):
/// - 本仓无主播页语义,主播名不可点(保留品牌色,不挂手势);
/// - [LiveRoom] 无 lastLiveAt 数据位,离线文案只显「未开播」,不显示
///   「上次开播 MM-DD HH:mm」;
/// - 超关/提醒状态取自本仓本地标记控制器(SuperFollowController /
///   RoomReminderStore),经局部 Obx 即时刷新。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/widgets/cover_badges.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/room_reminder_store.dart';
import 'package:pure_live/zishu_app/features/play/super_follow_controller.dart';
import 'package:pure_live/zishu_app/translation/translated_text.dart';

/// 离线置灰滤镜(真源 follow_common.dart `kGrayscaleFilter` 原矩阵,
/// 数值非颜色;行档 ZishuFollowRowItem 同款,卡片自持一份避免跨文件私用)。
final ColorFilter kZishuFollowGrayscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// 表单控件(Checkbox)状态层:本仓无真源 `controlStateLayer`,按
/// AppStateLayer 等价映射(focus/hover/pressed 全取 accent 低 alpha,
/// 与全库 hover/焦点口径一致;未列状态返回 null = 不叠状态层)。
WidgetStateProperty<Color?> zishuFollowControlStateLayer(ZishuTokens tokens) =>
    WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return AppStateLayer.focusOf(tokens.accent);
      if (states.contains(WidgetState.hovered)) return AppStateLayer.hoverOf(tokens.accent);
      if (states.contains(WidgetState.pressed)) return AppStateLayer.pressedOf(tokens.accent);
      return null;
    });

/// 关注卡片条目:「我的关注」页卡片档(非侧栏 compact)与侧栏 compact 档
/// 共用,仅配置不同(真源两处一套组件的口径)。
class ZishuFollowEntryCard extends StatelessWidget {
  const ZishuFollowEntryCard({
    super.key,
    required this.room,
    this.compact = false,
    this.selectMode = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onToggleSelect,
    this.onToggleSuper,
    this.onToggleRemind,
    this.onRemove,
  });

  final LiveRoom room;

  /// 批量选择模式:封面左上角标改复选框,点击(调用方接线)改为切换选择。
  final bool selectMode;
  final bool selected;

  /// 侧栏紧凑态:元信息区只留「主播名 + 标题」,隐藏统计/操作行
  /// (真源 compact 口径)。本轨只保证参数可用不溢出,侧栏面板接线
  /// 由播放页侧栏轨完成。
  final bool compact;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;

  /// 超关切换(本仓「特别关注」语义由本地超关标记承载)。
  final VoidCallback? onToggleSuper;
  final VoidCallback? onToggleRemind;
  final VoidCallback? onRemove;

  bool get _live => room.isLiveNow && room.isRecord != true;

  bool get _replay => room.effectiveLiveStatus == LiveStatus.replay;

  /// 在播人数展示值(与列表行同链:onlineViewers → watching → 「已开播」)。
  String _onlineLabel() {
    final online = (room.onlineViewers ?? '').trim();
    final watching = (room.watching ?? '').trim();
    return online.isNotEmpty
        ? readableCount(online)
        : (watching.isNotEmpty ? readableCount(watching) : i18n('online_room_title'));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      // 测试锚点:条目根节点(真源 follow-entry-{site}-{roomId} 同名)。
      key: Key('follow-entry-${room.platform}-${room.roomId}'),
      // 批量模式下选中项用品牌紫描边提示(真源同款)。
      foregroundDecoration: BoxDecoration(
        borderRadius: AppRadius.allMd,
        border: Border.all(color: selected ? tokens.accent : tokens.border, width: selected ? 1.5 : 1),
      ),
      child: Material(
        color: tokens.surface,
        borderRadius: AppRadius.allMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          // 状态反馈(全部走 token):hover 抬亮;焦点/按压用 accent 低 alpha。
          hoverColor: tokens.surfaceRaised,
          splashColor: AppStateLayer.splashOf(tokens.accent),
          highlightColor: AppStateLayer.pressedOf(tokens.accent),
          focusColor: AppStateLayer.focusOf(tokens.accent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCover(context),
              Expanded(
                child: Padding(
                  // 6/4 为真源同值(非 4pt 栅格,不取 spacing 档)。
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, AppSpacing.sm, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnchorRow(context),
                      const SizedBox(height: 2),
                      TranslatedText(
                        text: (room.title ?? '').trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textSecondary.copyWith(
                          fontSize: AppFontSize.caption,
                          color: tokens.textSecondary,
                        ),
                      ),
                      if (!compact) ...[const Spacer(), _buildStatsRow(context)],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 主播名行:超关 ★ 前缀(本仓超关语义)+ 平台品牌色主播名(离线压暗
  /// 60%,真源 FollowAnchorName 口径)。本仓无主播页语义,名字不可点,
  /// 不挂手势与指针光标(妥协记录)。
  Widget _buildAnchorRow(BuildContext context) {
    final tokens = context.tokens;
    final brand = PlatformBrandCatalog.byId(room.normalizedPlatformId);
    final color = brand != null
        ? (_live ? brand.color : brand.color.withValues(alpha: 0.6))
        : (_live ? tokens.textPrimary : tokens.textSecondary);
    return Obx(() {
      final isSuper = SuperFollowController.to.isSuper(room);
      return Row(
        children: [
          if (isSuper) ...[Icon(Icons.star_rounded, size: 12, color: tokens.brand), const SizedBox(width: 2)],
          Expanded(
            child: TranslatedText(
              text: (room.nick ?? '').trim(),
              maxLines: 1,
              style: context.textBody.copyWith(fontSize: AppFontSize.body, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      );
    });
  }

  /// 统计/操作行:平台圆点 + 状态图标 + 状态文案,右侧三枚操作钮
  /// (批量选择态隐藏操作钮,统计保留 —— 真源 selectMode 分支同款)。
  Widget _buildStatsRow(BuildContext context) {
    final tokens = context.tokens;
    final replay = _replay;
    final statusIcon = _live ? Icons.people_alt_rounded : (replay ? Icons.repeat_rounded : Icons.schedule_rounded);
    final statusIconColor = _live ? tokens.liveBadge : (replay ? tokens.brandBright : tokens.textSecondary);
    final statusText = _live ? _onlineLabel() : (replay ? i18n('replay') : i18n('offline_room_title'));
    final statusTextColor = _live ? tokens.textPrimary : (replay ? tokens.brandBright : tokens.textSecondary);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PlatformBrandCatalog.byId(room.normalizedPlatformId)?.color ?? tokens.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Icon(statusIcon, size: 10, color: statusIconColor),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textCaption.copyWith(fontSize: AppFontSize.label, color: statusTextColor),
          ),
        ),
        if (!selectMode) ...[
          const Spacer(),
          Obx(() {
            final isSuper = SuperFollowController.to.isSuper(room);
            return ZishuFollowIconAction(
              icon: isSuper ? Icons.star_rounded : Icons.star_border_rounded,
              // 本仓语义=超关(播放页 meta bar「超关/已超关」同词),无既有
              // i18n key,中文常量。
              tooltip: isSuper ? '取消超关' : '设为超关',
              active: isSuper,
              onPressed: onToggleSuper,
            );
          }),
          Obx(() {
            final remindOn = RoomReminderStore.to.isRemind(room);
            return ZishuFollowIconAction(
              icon: remindOn ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              // 无既有 i18n key,中文常量(真源同文案)。
              tooltip: remindOn ? '关闭开播提醒' : '开启开播提醒',
              active: remindOn,
              onPressed: onToggleRemind,
            );
          }),
          ZishuFollowIconAction(icon: Icons.delete_outline_rounded, tooltip: '移除关注', danger: true, onPressed: onRemove),
        ],
      ],
    );
  }

  /// 16:9 封面:分类(左下)/ ★·复选框(左上)/ 在线·录播(右下),
  /// 离线整幅置灰 + 底部未开播暗条(轮播不置灰,金黄角标区分)。
  Widget _buildCover(BuildContext context) {
    final tokens = context.tokens;
    final brand = PlatformBrandCatalog.byId(room.normalizedPlatformId);
    final live = _live;
    final replay = _replay;
    final category = (room.area ?? '').trim();
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCoverImage(context, offline: !live && !replay),
          // 左下:分类角标(品牌色底 + 浅字,真源 FollowCoverTag(accent)
          // 同款;角标本仓取 CoverBadge 的 8px 内圆角口径,与浏览卡一致)。
          if (category.isNotEmpty)
            Positioned(
              left: 0,
              bottom: 0,
              child: CoverBadge(
                corner: CoverCorner.bottomLeft,
                background: brand?.color,
                foreground: brand?.chipForeground ?? tokens.surfaceSoft,
                child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          // 左上:超关 ★ / 批量模式复选框。
          Positioned(
            left: 0,
            top: 0,
            child: selectMode
                ? _SelectBox(selected: selected, onChanged: (_) => onToggleSelect?.call())
                : Obx(() {
                    if (!SuperFollowController.to.isSuper(room)) return const SizedBox.shrink();
                    return CoverBadge(
                      corner: CoverCorner.topLeft,
                      child: Icon(Icons.star_rounded, size: 12, color: tokens.brand),
                    );
                  }),
          ),
          // 右下:在播人数;录播改显金黄「录播」角标;离线不重复显示
          // (底部已有未开播条)。右上平台角标本仓裁决不渲染(妥协)。
          if (live)
            Positioned(
              right: 0,
              bottom: 0,
              child: CoverBadge(
                corner: CoverCorner.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_alt_rounded, size: 10, color: tokens.liveBadge),
                    const SizedBox(width: 3),
                    Text(_onlineLabel(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            )
          else if (replay)
            Positioned(
              right: 0,
              bottom: 0,
              child: CoverBadge(
                corner: CoverCorner.bottomRight,
                // 金黄底 + 浅字:与 ZishuRoomCard 录播角标同配色(真源此处
                // 金字压金底不可读,本仓浏览卡已裁决过同款修正)。
                background: tokens.brandBright,
                foreground: tokens.surfaceSoft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.repeat_rounded, size: 10, color: tokens.surfaceSoft),
                    const SizedBox(width: 3),
                    Text(i18n('replay'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          // 离线遮罩条:整幅底部压一条暗带,显示「未开播」(LiveRoom 无
          // lastLiveAt,不显「上次开播」,妥协记录)。放在角标之后:与真源
          // 一样盖过底缘的分类角标(web 层级 z-index 同序)。
          if (!live && !replay)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                color: tokens.textPrimary.withValues(alpha: 0.62),
                alignment: Alignment.center,
                child: Text(
                  i18n('offline_room_title'),
                  style: context.textCaption.copyWith(
                    fontSize: AppFontSize.label,
                    color: tokens.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 封面图:取图/请求头/缓存与 ZishuRoomCard 同管线;离线置灰压暗
  /// (真源 FollowCoverImage:灰度矩阵 + 60% 透明,轮播不置灰)。
  Widget _buildCoverImage(BuildContext context, {required bool offline}) {
    final coverUrl = normalizeNetworkImageUrl(room.cover);
    Widget image = coverUrl.isEmpty
        ? _placeholder(context)
        : CachedNetworkImage(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            httpHeaders: networkImageHeaders(coverUrl),
            cacheManager: CustomImageCacheManager.instance,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            useOldImageOnUrlChange: true,
            placeholder: (_, _) => ColoredBox(color: context.tokens.surfaceRaised),
            errorWidget: (_, _, _) => _placeholder(context),
          );
    if (offline) {
      image = Opacity(
        opacity: 0.6,
        child: ColorFiltered(colorFilter: kZishuFollowGrayscaleFilter, child: image),
      );
    }
    return image;
  }

  Widget _placeholder(BuildContext context) {
    final category = (room.area ?? '').trim();
    return ColoredBox(
      color: context.tokens.surfaceRaised,
      child: Center(
        child: Text(
          category.isEmpty ? (room.platform ?? '') : category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textSecondary,
        ),
      ),
    );
  }
}

/// 批量模式复选框(封面左上角,加浅色底保证在封面上可见;真源
/// `_SelectBox` 同款:compact 密度 + accent 勾选 + surfaceSoft 勾色)。
class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(color: tokens.surfaceSoft.withValues(alpha: 0.85), borderRadius: AppRadius.allSm),
      child: Checkbox(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        visualDensity: VisualDensity.compact,
        activeColor: tokens.accent,
        checkColor: tokens.surfaceSoft,
        side: BorderSide(color: tokens.border),
        // hover/焦点/按压状态层走 token(AppStateLayer 等价,见
        // [zishuFollowControlStateLayer] 注释)。
        overlayColor: zishuFollowControlStateLayer(tokens),
      ),
    );
  }
}

/// 条目级小操作按钮(超关/提醒/删除):26×26 圆角 IconButton,规格逐字
/// 对齐真源 follow_common.dart:261-305 `FollowIconAction`(visualDensity
/// compact、padding xs、图标 16;hover 抬亮 surfaceRaised,焦点/按压
/// accent 低 alpha;danger 红、active accent 紫底金字档、常态次级)。
class ZishuFollowIconAction extends StatelessWidget {
  const ZishuFollowIconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// 激活态,如已超关/提醒开启。
  final bool active;

  /// 危险操作(删除)用 error 色。
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Color color = danger ? tokens.error : (active ? tokens.accent : tokens.textSecondary);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      // 状态反馈(全部走 token):hover 抬亮到 surfaceRaised;
      // 键盘焦点/按压用 accent 低 alpha(26×26 小目标也能看出焦点)。
      style: IconButton.styleFrom(
        hoverColor: tokens.surfaceRaised,
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      icon: Icon(icon, size: 16, color: color),
    );
  }
}
