// zishu 播放页侧栏「推荐」tab:跨平台交错推荐网格 + 滚动加载。
//
// 真源基准:zishu_flutter `lib/src/features/play/widgets/play_recommend_panel.dart`
// (+ `play_room_grid.dart::PlayRoomCard` 的卡片形态),数据与规则全在
// recommend_stream_controller.dart(真源 usePlayRecommend 编排的 GetX 移植);
// 本文件只负责呈现:
// - 无标题 + 顶部兜底提示行(命中分类/综合兜底时)+ 2 列封面网格;
// - 首屏加载渲染灰底骨架卡(每站 kRecommendPerSite 个);
// - 滚到底部自动追加下一页(「加载更多…」/「没有更多了」);
// - 卡片为面板内紧凑版 `_RecommendRoomCard`(真源 PlayRoomCard 形态:
//   封面 16:9 四角标 + 元信息两行)。跨平台交错列表里平台角标是识别
//   房间来源的唯一入口(真源左上平台徽章口径),且元信息预算为真源
//   compact 的 36(见 `_cardMetaHeight`)—— 既有 `ZishuRoomCard` 无平台
//   角标、元信息实际高度 ≈ 58,塞进 36 预算必然溢出,故在白名单文件内
//   按真源形态自绘;「我的关注」页网格仍用 ZishuRoomCard 不动。
// - 点击卡片进房沿用 `AppNavigator.toLiveRoomDetail`(pure_live 既有切房
//   通道;真源的 pushReplacement 语义由侧栏会话级 tab 记忆承接)。
//
// 驱动时序(控制器不得在 build 期间触发请求):initState 创建控制器后经
// microtask 调 `loadFirst`;didUpdateWidget 房间/分类上下文变化经 `rebind`
// (内部同样 microtask 派发),对齐真源面板 initState/didUpdateWidget 口径。

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/cover_badges.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/recommend_stream_controller.dart';
import 'package:pure_live/zishu_app/translation/translated_text.dart';

/// zishu 播放页侧栏「推荐」tab:跨平台交错推荐流 2 列封面网格,点击换房。
class ZishuPlayRecommendPanel extends StatefulWidget {
  const ZishuPlayRecommendPanel({super.key, required this.room});

  /// 当前房间快照:提供推荐编排的分类上下文,并把当前房从推荐里剔除。
  final LiveRoom room;

  @override
  State<ZishuPlayRecommendPanel> createState() => _ZishuPlayRecommendPanelState();
}

class _ZishuPlayRecommendPanelState extends State<ZishuPlayRecommendPanel> {
  /// 列数:侧栏宽度下 2 列(真源 `_columns = 2`)。
  static const int _columns = 2;

  /// 卡片元信息区(封面下两行文本)高度预算。
  ///
  /// 真源 play_recommend_panel.dart:61 / play_room_grid.dart:57 的 compact
  /// 预算就是 36(此前本面板用 58 是迁就 ZishuRoomCard 的元信息实高;
  /// 改用面板自绘紧凑卡后回到真源值)。
  static const double _cardMetaHeight = 36;

  /// 触底阈值:距底部不足这个距离就预取下一页(真源同值 160)。
  static const double _loadMoreThreshold = 160;

  RecommendStreamController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = RecommendStreamController(room: widget.room);
    // 用 microtask 而不是直接调用:loadFirst 会同步落一次 loading 状态,
    // 在 initState 里改 Rx 会撞上「widget 树构建中刷新 Obx」。
    Future<void>.microtask(() => _controller?.loadFirst());
  }

  @override
  void didUpdateWidget(ZishuPlayRecommendPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // rebind 内部比对 identityKey + 分类上下文,无变化即 no-op;有变化经
    // microtask 重载(与 initState 同理,不在父层构建期改 Rx)。
    _controller?.rebind(widget.room);
  }

  @override
  void dispose() {
    // onDelete 是 vendored GetX 的卸载入口(get_instance/src/lifecycle.dart:60):
    // 先置 isClosed 再回调 onClose —— 控制器在途请求的收尾据此让位;
    // Get 实例管理器移除控制器时同样走 onDelete(extension_instance.dart:391)。
    _controller?.onDelete();
    _controller = null;
    super.dispose();
  }

  /// 滚到底部附近 → 追加下一页(编排层自带防重入与「没有更多」判定)。
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.extentAfter > _loadMoreThreshold) return false;
    _controller?.loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    // 无「相关推荐」标题(真源用户口径 2026-09-19:顶部不要标题),直接铺内容。
    return Column(
      key: const Key('play-side-recommend-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: Obx(() => _body(context, controller)))],
    );
  }

  Widget _body(BuildContext context, RecommendStreamController controller) {
    final rooms = controller.rooms;
    final loadingFirstPage = controller.loading.value && rooms.isEmpty;
    if (rooms.isEmpty && !loadingFirstPage) {
      return _Hint(
        // 空态文案照抄真源 :126('相同分类的直播间会显示在这里');出错时
        // 用编排层写入的错误文案。无既有 i18n key,中文常量(见轨道报告)。
        text: controller.error.value.isEmpty ? '相同分类的直播间会显示在这里' : controller.error.value,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          key: const Key('play-recommend-scroll'),
          slivers: [
            if (controller.fallbackHint.value.isNotEmpty)
              SliverToBoxAdapter(
                child: _Hint(
                  key: const Key('play-recommend-fallback-hint'),
                  text: controller.fallbackHint.value,
                  compact: true,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
              sliver: SliverGrid.builder(
                gridDelegate: _gridDelegate(context, constraints.maxWidth),
                itemCount: rooms.length + controller.placeholderCount.value,
                itemBuilder: (context, index) {
                  if (index >= rooms.length) {
                    return _RecommendSkeletonCard(key: ValueKey('play-recommend-skeleton-$index'));
                  }
                  final room = rooms[index];
                  return _RecommendRoomCard(
                    // 锚点沿用真源测试契约 play-recommend-room-{site}-{roomId}。
                    key: ValueKey('play-recommend-room-${room.platform}-${room.roomId}'),
                    room: room,
                    onTap: () => AppNavigator.toLiveRoomDetail(liveRoom: room),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _Footer(
                loadingMore: controller.loadingMore.value,
                hasMore: controller.hasMore.value,
                roomCount: rooms.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 与真源同源的纵横比推导(play_recommend_panel.dart:188-205):卡片高 =
  /// 封面(16:9)+ 元信息两行预算,由实际列宽反推 childAspectRatio(固定
  /// 纵横比在窄侧栏下会把元信息区拉空)。
  SliverGridDelegate _gridDelegate(BuildContext context, double maxWidth) {
    const padding = EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm);
    final width = math.max(0.0, maxWidth - padding.horizontal);
    final gaps = AppSpacing.sm * (_columns - 1);
    final columnWidth = math.max(1.0, (width - gaps) / _columns);
    final metaHeight = metaHeightFor(_cardMetaHeight, context);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _columns,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: columnWidth / (columnWidth * 9 / 16 + metaHeight),
    );
  }
}

/// 空态/提示行(单行居中,真源 `_Hint`:209-239 同构)。
class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.text, this.compact = false});

  final String text;

  /// 紧凑模式:作为列表首行提示(不居中占满),用于兜底文案。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = context.textCaption.copyWith(color: tokens.textSecondary);
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 4),
        child: Text(text, style: style),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(text, textAlign: TextAlign.center, style: style),
      ),
    );
  }
}

/// 底部状态行:追加中 / 还有更多 / 没有更多(真源 `_Footer`:242-276 文案)。
class _Footer extends StatelessWidget {
  const _Footer({required this.loadingMore, required this.hasMore, required this.roomCount});

  final bool loadingMore;
  final bool hasMore;
  final int roomCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // 首屏骨架期没有房间也没有「更多」语义,不显示底行。
    if (roomCount == 0) return const SizedBox(height: AppSpacing.sm);
    final text = loadingMore ? '加载更多…' : (hasMore ? '向下滚动加载更多…' : '没有更多了');
    return Padding(
      key: const Key('play-recommend-footer'),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.textCaption.copyWith(color: tokens.textSecondary),
      ),
    );
  }
}

/// 骨架占位卡:封面块 + 两条文字块,灰度色全部取 tokens(沿用既有同款,
/// 对齐真源 `_SkeletonCard`:279-328)。
class _RecommendSkeletonCard extends StatelessWidget {
  const _RecommendSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Widget bar({required double widthFactor, required double height}) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: tokens.surfaceRaised, borderRadius: AppRadius.allSm),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allSm,
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: tokens.surfaceRaised),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar(widthFactor: 0.7, height: 9),
                const SizedBox(height: 5),
                bar(widthFactor: 0.45, height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 紧凑推荐卡(真源 `PlayRoomCard`,play_room_grid.dart:101-255 形态):
/// 16:9 封面四角标(左上平台 / 右上分类 / 右下热度,离线整封面遮罩)+
/// 元信息两行(主播名 / 标题),总高恰为封面 + `_cardMetaHeight`(36)预算
/// —— 元信息区用 Expanded 收紧,大字号下不溢出。
class _RecommendRoomCard extends StatelessWidget {
  const _RecommendRoomCard({super.key, required this.room, required this.onTap});

  final LiveRoom room;
  final VoidCallback onTap;

  /// 是否开播:状态真源 `LiveRoom.isLiveNow`(live_room.dart:528)。
  bool get _live => room.isLiveNow;

  /// soop 分类显示名映射的 cid:解析层把房间流分类号借 [LiveRoom.typeName]
  /// 承载(zishu_room_card.dart:96-101 同款口径);其他平台不传,原名直返。
  String get _categoryCid => room.normalizedPlatformId == Sites.soopSite ? (room.typeName ?? '').trim() : '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final coverUrl = normalizeNetworkImageUrl(room.cover);
    final category = (room.area ?? '').trim();
    final anchor = (room.nick ?? '').trim();
    final title = (room.title ?? '').trim().isNotEmpty
        ? room.title!
        : ((room.nick ?? '').trim().isNotEmpty ? room.nick! : ' ');
    // 热度展示值:走模型 audienceValue 兜底链(ZishuRoomCard 同口径),
    // 空串时角标自隐藏,不伪造 0。
    final onlineText = readableCount(room.audienceValue(preferRealOnline: false, platformEnabled: false));
    return Material(
      color: tokens.surface,
      borderRadius: AppRadius.allSm,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // 卡片 hover 抬一档底(surface → surfaceRaised);按下/键盘焦点走
        // accent 低 alpha。只改颜色,不动尺寸与位置。
        hoverColor: tokens.surfaceRaised,
        splashColor: AppStateLayer.splashOf(tokens.accent),
        highlightColor: AppStateLayer.pressedOf(tokens.accent),
        focusColor: AppStateLayer.focusOf(tokens.accent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: tokens.surfaceSoft,
                    child: coverUrl.isEmpty
                        ? _CoverPlaceholder(room: room)
                        : CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            httpHeaders: networkImageHeaders(coverUrl),
                            cacheManager: CustomImageCacheManager.instance,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            useOldImageOnUrlChange: true,
                            placeholder: (_, _) => ColoredBox(color: tokens.surfaceRaised),
                            errorWidget: (_, _, _) => _CoverPlaceholder(room: room),
                          ),
                  ),
                  // 离线:整封面压暗 + 居中「未开播」(cover_badges 层级约定:
                  // 遮罩在角标之前,角标浮于遮罩之上)。
                  if (!_live)
                    const Positioned.fill(
                      key: Key('cover-offline-overlay'),
                      child: CoverOfflineOverlay(fontSize: 10.5),
                    ),
                  // 左上:平台徽章(真源 `.platform-cover-badge`;跨平台交错
                  // 列表里这是房间来源的唯一识别)。
                  Positioned(
                    left: 0,
                    top: 0,
                    child: CoverPlatformBadge(
                      key: const Key('cover-badge-platform'),
                      corner: CoverCorner.topLeft,
                      site: room.normalizedPlatformId,
                    ),
                  ),
                  // 右上:分类徽章(真源 `.follow-preview-cat`)。
                  Positioned(
                    right: 0,
                    top: 0,
                    child: CoverCategoryBadge(
                      key: const Key('cover-badge-category'),
                      corner: CoverCorner.topRight,
                      category: category,
                      site: room.normalizedPlatformId,
                      cid: _categoryCid,
                    ),
                  ),
                  // 右下:热度(未开播或无数值不渲染)。
                  if (_live)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CoverOnlineBadge(
                        key: const Key('cover-badge-online'),
                        corner: CoverCorner.bottomRight,
                        online: onlineText,
                      ),
                    ),
                ],
              ),
            ),
            // 元信息两行(真源 :222-249):主播名(caption)+ 标题(label、
            // 次级色);Expanded 收紧进 36 预算,大字号不溢出。
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(1, 3, 3, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (anchor.isNotEmpty)
                      Text(
                        anchor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textCaption.copyWith(fontSize: AppFontSize.caption),
                      ),
                    const SizedBox(height: 1),
                    TranslatedText(
                      text: title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textSecondary.copyWith(fontSize: AppFontSize.label, color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 封面占位(无图/加载失败):分类名优先,退平台名(真源 FollowCoverImage
/// 的 fallbackLabel 口径,ZishuRoomCard 同款)。
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final category = (room.area ?? '').trim();
    return ColoredBox(
      color: context.tokens.surfaceRaised,
      child: Center(child: Text(category.isEmpty ? (room.platform ?? '') : category, style: context.textSecondary)),
    );
  }
}
