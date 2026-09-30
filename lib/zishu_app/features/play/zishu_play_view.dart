import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/widgets/keyboard/video_keyboard.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_content.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/category_colors.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu/domain/category_display.dart';
import 'package:pure_live/zishu_app/features/play/my_category_controller.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_side_panel.dart';
import 'package:pure_live/zishu_app/features/play/zishu_player_controls.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_immersive_sheet.dart';
import 'package:pure_live/zishu_app/features/play/zishu_sleep_timer_badge.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_keyboard_ext.dart';
import 'package:pure_live/zishu_app/features/play/zishu_stage_hint.dart';

/// zishu 播放页布局骨架(对齐 zishu_flutter play_view 的 U5 左右布局):
/// Scaffold(transparent) → Row[Expanded(左列[房间头, Expanded(舞台帧)]), 侧栏]。
/// <768 宽时侧栏堆叠到视频下方(flex 3:2);舞台 ClipRRect 12px(<640 为 0)。
///
/// 控制逻辑不重写:舞台直接嵌入 pure_live 既有播放页部件 [LivePlayVideo],
/// 并在其上挂 zishu 风格 on-video 控制条 [ZishuPlayerControlsBar]
/// (播放/音量/画质/线路/弹幕/画中画/宽屏/全屏,替换视频下方旧 ResolutionsRow);
/// 沉浸态(全屏/网页全屏/竖屏全屏)与画中画整块交给既有 [LivePlayContent],
/// 键盘快捷键沿用既有 [VideoKeyboardShortcuts] 包裹。
///
/// 期望在路由层替换 `LivePlayPage`:binding(LivePlayController)不变,
/// `GetPage(page: () => ZishuPlayView())` 即可,入参经 Get.arguments/parameters。
class ZishuPlayView extends StatefulWidget {
  const ZishuPlayView({super.key, this.controller});

  /// 播放控制器:缺省时按 GetX 惯例 `Get.find<LivePlayController>()`
  /// (LivePlayBinding 已 lazyPut,无 tag)。
  final LivePlayController? controller;

  @override
  State<ZishuPlayView> createState() => _ZishuPlayViewState();
}

class _ZishuPlayViewState extends State<ZishuPlayView> {
  /// 侧栏开合:本地 State,不持久化(对齐本轮骨架口径)。
  bool _sidePanelVisible = true;

  /// 沉浸态右缘抽屉开合(3s 自动收起由 sheet 内部管理)。
  bool _immersiveSheetVisible = false;

  @override
  void initState() {
    super.initState();
    // zishu 播放页用 on-video 控制条接管:常规态关闭 VideoControllerPanel 的
    // 旧顶栏/底栏(手势层/DanmakuViewer/锁定逻辑保留);沉浸态(全屏/PiP)
    // 由面板内部按当前 screenMode 自行恢复完整渲染,不受此开关影响。
    VideoControllerPanel.renderLegacyBars = false;
  }

  @override
  Widget build(BuildContext context) {
    final LivePlayController controller;
    if (widget.controller != null) {
      controller = widget.controller!;
    } else if (Get.isRegistered<LivePlayController>()) {
      controller = Get.find<LivePlayController>();
    } else {
      // binding 未就绪(直接热预览等):占位等待,与 ZishuBrowseView 同口径。
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Obx(() {
      final state = controller.state.value;
      final manager = GlobalPlayerService.instance.player;
      final isInPip = manager.isInPip.value || manager.isPipPreparing.value;
      final mode = state.ui.screenMode;
      final immersive = mode != VideoMode.normal && !isInPip;
      final Widget body;
      if (isInPip) {
        // 画中画:完全复用既有呈现,布局侧不参与。
        body = LivePlayContent(controller: controller, isInPip: true, mode: mode);
      } else if (immersive) {
        // 沉浸态(全屏/网页全屏):既有呈现 + zishu 右缘抽屉侧栏
        // (把手拉出,3s 自动收起;聊天/推荐在沉浸态可达)。
        final room = state.room.detail ?? controller.room;
        body = Stack(
          children: [
            LivePlayContent(controller: controller, isInPip: false, mode: mode),
            ZishuPlayImmersiveSheet(
              visible: _immersiveSheetVisible,
              onToggle: () => setState(() => _immersiveSheetVisible = !_immersiveSheetVisible),
              child: ZishuPlaySidePanel(room: room, isLive: state.room.isLiving),
            ),
            // 舞台提示浮层:沉浸态下操作反馈同样落在舞台内(Stack 顶层,
            // IgnorePointer 不吸收命中)。
            const ZishuStageHintOverlay(),
          ],
        );
      } else {
        body = _buildZishuLayout(controller);
      }
      // 桌面路由快捷键:既有键位(Space/R/↑↓/Esc)+ zishu 扩展(M 静音/F 全屏/W 宽屏)。
      return VideoKeyboardShortcuts(
        controller: state.player.videoController,
        child: ZishuPlayKeyboardShortcutsExt(
          readVolume: () async => controller.state.value.player.videoController?.volume(),
          writeVolume: (volume) async {
            final videoController = controller.state.value.player.videoController;
            if (videoController == null) return;
            await videoController.setVolume(volume);
            videoController.updateVolumn(volume);
          },
          onToggleFullScreen: () {
            final videoController = controller.state.value.player.videoController;
            if (videoController != null) unawaited(videoController.toggleFullScreen());
          },
          onToggleWindowFullScreen: () {
            final videoController = controller.state.value.player.videoController;
            videoController?.toggleWindowFullScreen();
          },
          child: body,
        ),
      );
    });
  }

  /// 常规态 zishu 布局:左列(房间头 + 舞台) + 右侧侧栏。
  Widget _buildZishuLayout(LivePlayController controller) {
    final room = controller.state.value.room.detail ?? controller.room;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // <768:侧栏堆到视频下方(flex 3:2),避免固定宽侧栏挤扁舞台。
          final stacked = width < AppBreakpoints.phone;
          final sidePanelWidth = AppSpacing.playSidePanelWidthFor(width);
          // 舞台圆角(web .play-frame 12px,≤640 为 0)。
          final stageRadius = BorderRadius.circular(width < AppBreakpoints.compact ? 0 : AppRadius.lg);
          Widget stageInFrame(Widget child) => ClipRRect(borderRadius: stageRadius, child: child);
          final sidePanel = ZishuPlaySidePanel(
            room: room,
            isLive: controller.state.value.room.isLiving,
            // 窄屏堆叠:视频正下方紧跟移动信息条(头像 + 昵称 + 统计 +
            // 关注/超关),替代桌面信息头(对齐 zishu compactHeader: true)。
            compactHeader: stacked,
          );
          final title = room.title?.trim() ?? '';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ZishuRoomHeader(
                      room: room,
                      title: title.isNotEmpty ? title : '直播',
                      sidePanelVisible: _sidePanelVisible,
                      onBack: () => Get.back(),
                      onToggleSidePanel: () => setState(() => _sidePanelVisible = !_sidePanelVisible),
                    ),
                    Expanded(
                      child: stacked
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 3, child: stageInFrame(_buildStage(controller))),
                                if (_sidePanelVisible) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Expanded(flex: 2, child: sidePanel),
                                ],
                              ],
                            )
                          : stageInFrame(_buildStage(controller)),
                    ),
                  ],
                ),
              ),
              if (!stacked && _sidePanelVisible) ...[
                // 播放区与侧栏的间隔:对齐 zishu 2px。
                const SizedBox(width: 2),
                SizedBox(width: sidePanelWidth, child: sidePanel),
              ],
            ],
          );
        },
      ),
    );
  }

  /// 舞台 = pure_live 既有视频区 + zishu on-video 控制条 overlay。
  /// 旧 ResolutionsRow(视频下方画质/线路行)已移除:画质/线路改在控制条内切换。
  /// 舞台帧由本视图拥有(Expanded 裁切),故视频按帧铺满
  /// ([LivePlayVideo] 文档:显式帧的调用方才允许 expandToParent)。
  Widget _buildStage(LivePlayController controller) {
    return ColoredBox(
      color: AppOnVideo.bar,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LivePlayVideo(controller: controller, expandToParent: true),
          // 睡眠定时舞台徽章(右上 pill,无定时器自空)。
          const ZishuSleepTimerBadge(),
          // 舞台提示浮层:刷新等操作反馈落在视频区内(替代全局 toast),
          // 必须为舞台 Stack 直接子级(内部 Positioned);不吸收命中。
          const ZishuStageHintOverlay(),
          Obx(() {
            // 播放器就位前不挂控制条(VideoController 随播放器状态创建)。
            final videoController = controller.state.value.player.videoController;
            if (videoController == null) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.bottomCenter,
              child: ZishuPlayerControlsBar(controller: videoController),
            );
          }),
        ],
      ),
    );
  }
}

/// 房间头:对齐 zishu _RoomHeader —— 返回钮(32×32,arrow 18) + 分类徽标
/// (分类色底 92%/平台色回退 + 平台图标 + 跨平台中文分类名 + 收藏星,
/// 点击进分类)+ 左对齐标题 + 侧栏开合钮。
///
/// 收藏星对齐 zishu 原版**收藏分类**语义:点击
/// [MyCategoryController.toggle](room.platform, room.area),已收藏判定
/// isFavorited(Obx 订阅 categories,跨平台口径);分类徽标只在有分类
/// 上下文时渲染,即分类为空时星标随之隐藏(房间收藏走关注 tab,不在此
/// 重复)。
class _ZishuRoomHeader extends StatelessWidget {
  const _ZishuRoomHeader({
    required this.room,
    required this.title,
    required this.sidePanelVisible,
    required this.onBack,
    required this.onToggleSidePanel,
  });

  final LiveRoom room;
  final String title;
  final bool sidePanelVisible;
  final VoidCallback onBack;
  final VoidCallback onToggleSidePanel;

  /// 房间分类在分区表中的对应项:命中则点击徽标进该分类的房间流。
  LiveArea? _matchCategory(String siteId) {
    final areaName = room.area?.trim() ?? '';
    if (siteId.isEmpty || areaName.isEmpty) return null;
    if (!Get.isRegistered<AreasListController>(tag: siteId)) return null;
    final categories = Get.find<AreasListController>(tag: siteId).categories;
    for (final category in categories) {
      for (final child in category.children) {
        if (child.areaName == areaName) return child;
      }
    }
    return null;
  }

  /// 收藏/取消收藏当前分类(zishu 口径:跨平台「我的分类」,不区分平台
  /// 分类号)。已达上限且是新增时 [MyCategoryController.toggle] 返回
  /// false,这里经舞台提示浮层反馈(既有 key `my_category_limit`,上限 12
  /// 与 [MyCategoryController.maxCount] 一致;原全局 ToastUtil 换舞台内浮层)。
  Future<void> _toggleFavoriteCategory() async {
    final siteId = room.platform?.trim() ?? '';
    final category = room.area?.trim() ?? '';
    if (siteId.isEmpty || category.isEmpty) return;
    final ok = await MyCategoryController.to.toggle(siteId, category);
    if (!ok) {
      ZishuStageHint.show(i18n('my_category_limit'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final siteId = room.platform ?? '';
    final category = room.area?.trim() ?? '';
    final brand = PlatformBrandCatalog.byId(siteId);

    // 徽标配色:分类色板优先,无分类色回退平台品牌色;再无则纯文本。
    final categoryStyle = CategoryColors.opaqueFor(category: category, site: siteId);
    final badgeBg = categoryStyle?.background ?? (category.isNotEmpty ? brand?.color : null);
    final badgeFg =
        categoryStyle?.foreground ??
        (badgeBg == null
            ? tokens.textSecondary
            // 回退平台色底为品牌恒定色:前景按底亮度取主题无关恒亮/恒暗,
            // 浅色主题下不再随主题翻转(surfaceSoft 浅字压亮平台色 2.4:1)。
            : ThemeData.estimateBrightnessForColor(badgeBg) == Brightness.dark
            ? AppOnVideo.text
            : AppOnBright.text);
    // 分类名统一走跨平台中文映射(海外平台原名归一为中文)。
    final categoryLabel = category.isNotEmpty ? displayCategoryName(siteId, category) : '';
    final matchedCategory = _matchCategory(siteId);

    // 标题行用当前黑白主题色:surface 底(深主题深底/浅主题浅底),
    // 行上文字/图标随主题自动反转(textPrimary/textSecondary)。
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4.5, 4, 5),
      color: tokens.surface,
      child: Row(
        children: [
          IconButton(
            tooltip: i18n('back'),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            focusColor: AppStateLayer.focusOf(tokens.accent),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (badgeBg != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: badgeBg.withValues(alpha: 0.92), borderRadius: AppRadius.allSm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (matchedCategory != null)
                    Tooltip(
                      message: i18n('view_category', args: {'category': categoryLabel}),
                      child: InkWell(
                        onTap: () => AppNavigator.toCategoryDetail(site: Sites.of(siteId), category: matchedCategory),
                        borderRadius: AppRadius.allSm,
                        focusColor: Theme.of(context).focusColor,
                        child: _BadgeLabel(siteId: siteId, categoryLabel: categoryLabel, color: badgeFg),
                      ),
                    )
                  else
                    _BadgeLabel(siteId: siteId, categoryLabel: categoryLabel, color: badgeFg),
                  const SizedBox(width: 4),
                  // 收藏星:收藏当前分类(zishu 口径,13px,与 zishu 星标同
                  // 规格)。徽标块只在有分类上下文时渲染 ——
                  // CategoryColors.opaqueFor 对空分类返回 null、平台色回退
                  // 也要求分类非空 —— 即分类为空时本星不出现。
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Obx(() {
                      // isFavorited 内部读 RxList(categories),Obx 据此订阅。
                      final favorited = MyCategoryController.to.isFavorited(siteId, category);
                      return IconButton(
                        tooltip: favorited ? i18n('unfavorite_category') : i18n('favorite_category'),
                        onPressed: _toggleFavoriteCategory,
                        padding: EdgeInsets.zero,
                        splashRadius: 12,
                        icon: Icon(
                          favorited ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 13,
                          color: favorited ? tokens.brandBright : badgeFg,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle),
            ),
          ),
          IconButton(
            tooltip: sidePanelVisible ? i18n('collapse_side_panel') : i18n('expand_side_panel'),
            onPressed: onToggleSidePanel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              sidePanelVisible ? Icons.keyboard_double_arrow_right_rounded : Icons.keyboard_double_arrow_left_rounded,
              size: 18,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 徽标文字行:平台图标 + 中文分类名(颜色随徽标底色)。
class _BadgeLabel extends StatelessWidget {
  const _BadgeLabel({required this.siteId, required this.categoryLabel, required this.color});

  final String siteId;
  final String categoryLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlatformIcon(id: siteId, size: 14),
        const SizedBox(width: 4),
        Text(
          categoryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11),
        ),
      ],
    );
  }
}
