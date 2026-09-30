import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/widgets/keyboard/video_keyboard.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_content.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolutions_row.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/play/zishu_play_side_panel.dart';

/// zishu 播放页布局骨架(对齐 zishu_flutter play_view 的 U5 左右布局):
/// Scaffold(transparent) → Row[Expanded(左列[房间头, Expanded(舞台帧)]), 侧栏]。
/// <768 宽时侧栏堆叠到视频下方(flex 3:2);舞台 ClipRRect 12px(<640 为 0)。
///
/// 控制逻辑不重写:舞台直接嵌入 pure_live 既有播放页部件 ——
/// [LivePlayVideo](含 VideoControllerPanel 控制条) + [ResolutionsRow](画质/线路);
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
      final body = (mode != VideoMode.normal || isInPip)
          // 沉浸态/画中画:完全复用既有呈现,布局侧不参与。
          ? LivePlayContent(controller: controller, isInPip: isInPip, mode: mode)
          : _buildZishuLayout(controller);
      // 桌面路由快捷键:既有页面在元数据失败态也保持挂载,这里同口径。
      return VideoKeyboardShortcuts(controller: state.player.videoController, child: body);
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
          final sidePanel = ZishuPlaySidePanel(room: room, isLive: controller.state.value.room.isLiving);
          final title = room.title?.trim() ?? '';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ZishuRoomHeader(
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

  /// 舞台 = pure_live 既有视频区(含控制条 overlay) + 画质/线路条。
  /// 舞台帧由本视图拥有(Expanded 裁切),故视频按帧铺满
  /// ([LivePlayVideo] 文档:显式帧的调用方才允许 expandToParent)。
  Widget _buildStage(LivePlayController controller) {
    return ColoredBox(
      color: AppOnVideo.bar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: LivePlayVideo(controller: controller, expandToParent: true)),
          ResolutionsRow(controller: controller),
        ],
      ),
    );
  }
}

/// 房间头:返回按钮(32×32, arrow 18) + 居中标题 + 侧栏开合钮。
/// 对齐 zishu _RoomHeader 的行构成(分类徽标本轮省略,后续按 siteId 补)。
class _ZishuRoomHeader extends StatelessWidget {
  const _ZishuRoomHeader({
    required this.title,
    required this.sidePanelVisible,
    required this.onBack,
    required this.onToggleSidePanel,
  });

  final String title;
  final bool sidePanelVisible;
  final VoidCallback onBack;
  final VoidCallback onToggleSidePanel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      // 自适应高度(web padding .28rem .5rem .32rem 的折算),内容撑开。
      padding: const EdgeInsets.fromLTRB(2, 4.5, 4, 5),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle),
              ),
            ),
          ),
          IconButton(
            tooltip: sidePanelVisible ? '收起侧栏' : '展开侧栏',
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
