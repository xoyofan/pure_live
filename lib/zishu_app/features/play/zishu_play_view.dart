import 'dart:async';
import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
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
import 'package:pure_live/zishu_app/translation/translated_text.dart';
import 'package:pure_live/zishu_app/features/settings/zishu_settings_view.dart';
import 'package:pure_live/zishu_app/shell/zishu_global_actions.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_flyout_machine.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_top_bar.dart';

/// zishu 播放页布局骨架(对齐 zishu_flutter play_view 的 U5 左右布局):
/// 常规态 = Column[壳层顶栏(ZishuShellTopBar,真源 play 路由套壳:顶栏
/// 常驻), Divider, Expanded(Scaffold(transparent) →
/// Row[Expanded(左列[房间头, Expanded(舞台帧)]), 侧栏])] +
/// hover 浮层 Stack;沉浸态(全屏/网页全屏)与画中画收 chrome(真源
/// chromeHidden 同口径),视频占满窗口。
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

class _ZishuPlayViewState extends State<ZishuPlayView> with ZishuShellFlyoutMachine {
  /// 侧栏开合:本地 State,不持久化(对齐本轮骨架口径)。
  bool _sidePanelVisible = true;

  /// 沉浸态右缘抽屉开合(3s 自动收起由 sheet 内部管理)。
  bool _immersiveSheetVisible = false;

  /// 沉浸态右缘热区防抖锁(真源 play_view `_onChromeVisibilityChanged`:
  /// 进入沉浸态后 720ms 内拒绝打开抽屉,防进入瞬间的点击误开)。bool +
  /// Timer 而非 DateTime 截止(真源同注:测试 FakeAsync 时钟不走真实
  /// DateTime,锁会永远解不开)。
  bool _immersiveSideLocked = false;
  Timer? _immersiveSideLockTimer;

  /// 上一帧沉浸态(抽屉联动只在进/出沉浸态的边沿触发)。
  bool _lastImmersive = false;

  /// 沉浸态联动 Rx 侦听(controller 在 build 才可用,首个可用 build 懒
  /// 绑定;随 dispose 释放)。
  bool _immersiveWatchersBound = false;
  List<Worker>? _immersiveWorkers;

  /// 沉浸态点击分流层(铺满舞台):取其 RenderBox 宽做右缘 2/3 热区判定
  /// (真源以舞台 host key 取宽同口径)。
  final GlobalKey _immersiveTapLayerKey = GlobalKey(debugLabel: 'zishu-immersive-tap-layer');

  /// F5 刷新播放页:与控制条「刷新」同通路(zishu_player_controls.dart 的
  /// 刷新钮:videoController.refresh);播放器未就位(加载失败占位)时回落
  /// onInitPlayerState 重解析(同 RoomLoadFailedWidget 的重试通路)。反馈
  /// 走舞台内浮层,与控制条刷新同文案(key `play_refreshed`)。
  void _refreshStream(LivePlayController controller) {
    final videoController = controller.state.value.player.videoController;
    if (videoController != null) {
      unawaited(videoController.refresh());
    } else {
      unawaited(controller.onInitPlayerState());
    }
    ZishuStageHint.show(i18n('play_refreshed'));
  }

  /// 沉浸态联动 Rx 侦听(懒绑定):screenMode 变化经 state Rx 发布,PiP
  /// 变化经播放器管理器 Rx,任一触发都同步一次抽屉联动。
  void _bindImmersiveWatchers(LivePlayController controller) {
    if (_immersiveWatchersBound) return;
    _immersiveWatchersBound = true;
    final manager = GlobalPlayerService.instance.player;
    _immersiveWorkers = [
      ever(controller.state, (_) => _syncImmersiveSide(controller)),
      ever(manager.isInPip, (_) => _syncImmersiveSide(controller)),
      ever(manager.isPipPreparing, (_) => _syncImmersiveSide(controller)),
    ];
  }

  /// 沉浸态切换联动(真源 play_view `_onChromeVisibilityChanged` 的 GetX
  /// 转写):进入或退出沉浸态都强制关抽屉;控制条随切换唤醒(真源「呈现态
  /// 切换时同步控制条可见性」同口径 —— 开抽屉落下的 showController 若不
  /// 唤醒,退出沉浸态后常规态 zishu 控制条会滞留隐藏);进入时上 720ms
  /// 防抖锁(防进入沉浸态瞬间的点击误开抽屉),退出时清锁。
  void _syncImmersiveSide(LivePlayController controller) {
    final manager = GlobalPlayerService.instance.player;
    final immersive =
        controller.state.value.ui.screenMode != VideoMode.normal &&
        !manager.isInPip.value &&
        !manager.isPipPreparing.value;
    if (immersive == _lastImmersive) return;
    _lastImmersive = immersive;
    if (_immersiveSheetVisible) setState(() => _immersiveSheetVisible = false);
    _wakeImmersiveControls(controller);
    if (immersive) {
      _immersiveSideLocked = true;
      _immersiveSideLockTimer?.cancel();
      _immersiveSideLockTimer = Timer(const Duration(milliseconds: 720), () {
        if (mounted) _immersiveSideLocked = false;
      });
    } else {
      _immersiveSideLocked = false;
      _immersiveSideLockTimer?.cancel();
    }
  }

  /// 打开沉浸抽屉(真源 `_openImmersiveSide`):锁内拒绝;打开即藏控制条,
  /// 3s 无交互自动收起由 sheet 内部排程(可见即启动、面板内交互重置,口径
  /// 与真源 scheduleHideImmersiveSide 一致)。
  void _openImmersiveSide(LivePlayController controller) {
    if (_immersiveSideLocked) return;
    if (!_immersiveSheetVisible) setState(() => _immersiveSheetVisible = true);
    _hideImmersiveControls(controller);
  }

  /// 关闭沉浸抽屉(真源 `_closeImmersiveSide`):任何途径的关闭(遮罩/
  /// toggle 把手/3s 超时)在沉浸态下都同时唤醒控制条。
  void _closeImmersiveSide(LivePlayController controller) {
    if (!_immersiveSheetVisible) return;
    setState(() => _immersiveSheetVisible = false);
    _wakeImmersiveControls(controller);
  }

  /// 唤醒沉浸态控制条(宿主 video_controller.dart 的 showController 口径):
  /// 显示并重挂面板自身的自动隐藏计时(enableController 语义)。
  void _wakeImmersiveControls(LivePlayController controller) {
    controller.state.value.player.videoController?.enableController();
  }

  /// 藏沉浸态控制条:先取消面板自动隐藏计时,再直落 showController Rx
  /// (VideoController 无公开 hide 入口;其内部隐藏路径 video_controller.dart
  /// 同为直写该 Rx)。
  void _hideImmersiveControls(LivePlayController controller) {
    final videoController = controller.state.value.player.videoController;
    if (videoController == null) return;
    videoController.stopHideController();
    videoController.showController.value = false;
  }

  /// 沉浸态舞台点击分流(真源 `_onImmersiveFrameTapUp`):
  /// - 抽屉开着 → 关抽屉 + 唤醒控制条;
  /// - 点击落在右缘热区(x/宽度 ≥ 2/3,真源 PLAY_IMMERSIVE_TAP_ZONE)→ 开抽屉;
  /// - 其余 → 仅唤醒控制条。
  ///
  /// 沉浸态点击不切播放/暂停:底层呈现已被 AbsorbPointer 拦下,其内部全屏
  /// GestureDetector 的「点画面唤醒/续播」不参与本层点击。
  void _onImmersiveFrameTapUp(LivePlayController controller, Offset localPosition) {
    if (_immersiveSheetVisible) {
      _closeImmersiveSide(controller);
      return;
    }
    final box = _immersiveTapLayerKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    final zone = localPosition.dx / (width <= 0 ? 1 : width);
    if (zone >= 2 / 3) {
      _openImmersiveSide(controller);
    } else {
      _wakeImmersiveControls(controller);
    }
  }

  @override
  void initState() {
    super.initState();
    // zishu 播放页用 on-video 控制条接管:常规态关闭 VideoControllerPanel 的
    // 旧顶栏/底栏(手势层/DanmakuViewer/锁定逻辑保留);沉浸态(全屏/PiP)
    // 由面板内部按当前 screenMode 自行恢复完整渲染,不受此开关影响。
    VideoControllerPanel.renderLegacyBars = false;
  }

  @override
  void dispose() {
    disposeFlyoutMachine();
    // F5 动作随本 State 注销(owner 校验防误删,真源同口径)。
    GlobalActions.unregister(GlobalActionNames.refreshPlay, owner: this);
    for (final worker in _immersiveWorkers ?? const <Worker>[]) {
      worker.dispose();
    }
    _immersiveWorkers = null;
    _immersiveSideLockTimer?.cancel();
    _immersiveSideLockTimer = null;
    super.dispose();
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
    // 注册 F5 刷新(真源 play_view 同位:build 内注册,builder 层快捷键经
    // GlobalActions 落地,注销随本 State dispose)。
    GlobalActions.register(GlobalActionNames.refreshPlay, owner: this, action: () => _refreshStream(controller));
    // 沉浸态抽屉联动侦听(懒绑定,幂等)。
    _bindImmersiveWatchers(controller);
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
        // 抽屉宽手机钳制(真源 play_view.dart:607-613):<768 时面板宽
        // 不超过视口 88%(web `min(320px, 88vw)`)。
        final mediaWidth = MediaQuery.sizeOf(context).width;
        final sheetWidth = mediaWidth < AppBreakpoints.phone
            ? math.min(AppSpacing.playSidePanelWidthFor(mediaWidth), mediaWidth * 0.88)
            : AppSpacing.playSidePanelWidthFor(mediaWidth);
        body = Stack(
          fit: StackFit.expand,
          children: [
            // 沉浸态点击分流(真源 onPlayFrameClick 沉浸分支):底层既有
            // 呈现整体收不到指针 —— 其内部全屏 GestureDetector 的「点画面
            // 唤醒/续播、双击切全屏」在沉浸态让位(真源同口径:沉浸态不
            // 注册双击),点击语义改由顶层分流层接管。
            AbsorbPointer(
              absorbing: true,
              child: LivePlayContent(controller: controller, isInPip: false, mode: mode),
            ),
            // 顶层分流层:抽屉开着时被 sheet 遮罩挡住(Stack 命中序在
            // sheet 之下),不会误收点击;关着时右缘 2/3 开抽屉、其余唤醒
            // 控制条;鼠标移动唤醒控制条(真源舞台 onHover → _wakeControls
            // 同款)。GestureDetector 只注册 tap:拖拽不成 tap,不会误分流。
            Positioned.fill(
              child: MouseRegion(
                onHover: (_) => _wakeImmersiveControls(controller),
                child: GestureDetector(
                  key: _immersiveTapLayerKey,
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) => _onImmersiveFrameTapUp(controller, details.localPosition),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            ZishuPlayImmersiveSheet(
              visible: _immersiveSheetVisible,
              panelWidth: sheetWidth,
              // 遮罩/把手/3s 超时统一收口为「关闭」(开抽屉只经右缘热区),
              // 关闭同时唤醒控制条(真源 _closeImmersiveSide 口径)。
              onToggle: () => _closeImmersiveSide(controller),
              child: ZishuPlaySidePanel(room: room, isLive: state.room.isLiving),
            ),
            // 舞台提示浮层:沉浸态下操作反馈同样落在舞台内(Stack 顶层,
            // IgnorePointer 不吸收命中)。
            const ZishuStageHintOverlay(),
          ],
        );
      } else {
        body = _buildShellChrome(controller);
      }
      // hover 浮层(平台分类/关注在播/我的分类)只随常规态顶栏:沉浸态与
      // 画中画无 chrome,不渲染浮层(对齐真源 chromeHidden:视频占满窗口,
      // 鼠标划过不可见顶栏也不飘浮层)。
      final showChrome = !isInPip && !immersive;
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
          child: Stack(
            children: [
              body,
              // hover 浮层:Stack 覆盖在页面最上层(Positioned 顶格按
              // AppSpacing.topNavHeight 定位,与壳层同口径)。
              if (showChrome)
                ...buildFlyoutOverlays(
                  siteById: _siteById,
                  onOpenCategory: _openCategoryFromFlyout,
                  onOpenRoom: _openRoomFromFlyout,
                ),
            ],
          ),
        ),
      );
    });
  }

  /// 常规态壳层 chrome:44px 顶栏([ZishuShellTopBar],与壳层共用一份)+
  /// 分隔线 + 既有 zishu 布局(左列 + 侧栏)。沉浸态/画中画不走本分支
  /// (真源 play 路由套壳:chromeHidden 时顶栏收起,视频占满窗口)。
  ///
  /// 顶栏语义(对齐真源 play 路由):无主导航选中态(index = -1,nav-home/
  /// nav-category 均不激活);平台 tab 选中 = 当前房间平台(platformTabsActive
  /// 恒真 + currentSiteId 取房间平台);主导航点击 / 平台 tab 点击 = pop 到
  /// 根回壳层再切换(见 [_goHomeMenu] / [_goHomeSite])。
  Widget _buildShellChrome(LivePlayController controller) {
    final tokens = context.tokens;
    final room = controller.state.value.room.detail ?? controller.room;
    return Theme(
      // 交互态收口:与壳层根部同口径,顶栏焦点色统一(AppStateLayer focus)。
      data: Theme.of(context).copyWith(focusColor: AppStateLayer.focusOf(tokens.accent)),
      child: Column(
        children: [
          ZishuShellTopBar(
            index: -1,
            // 平台入口渲染表与壳层同源(savedPlatformIds 过滤,Obx 订阅)。
            sites: visibleTopBarSites(),
            currentSiteId: room.platform,
            platformTabsActive: true,
            onSelectMenu: _goHomeMenu,
            onSelectSite: _goHomeSite,
            onPlatformHoverStart: schedulePlatformFlyout,
            onPlatformHoverEnd: cancelPlatformFlyoutOpen,
            onFollowHoverStart: openFollowFlyout,
            onFollowHoverEnd: scheduleFlyoutClose,
            onMyCategoryHoverStart: scheduleMyCategoryFlyout,
            onMyCategoryTap: toggleMyCategoryFlyout,
            onMyCategoryHoverEnd: cancelMyCategoryFlyoutOpen,
            onOpenSettings: () => unawaited(openZishuSettingsDialog(context)),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildZishuLayout(controller)),
        ],
      ),
    );
  }

  // ---- 顶栏导航:播放页 → 回壳层(pop 到根再切,对齐真源 context.go) ----

  /// 主导航点击:回壳层并切到对应菜单。真源 play 路由下点 nav-home 是
  /// `context.go('/all')` 整栈替换;GetX 对应 pop 到根(kInitial,HomePage),
  /// 再经 FavoriteController.tabBottomIndex 通道切菜单(HomePage 监听该 Rx
  /// 同步 _selectedIndex,见 home_page 的 _favoriteTabListener)。
  void _goHomeMenu(int menuIndex) {
    closeAllFlyouts();
    Get.until((route) => route.name == RoutePath.kInitial);
    if (Get.isRegistered<FavoriteController>()) {
      Get.find<FavoriteController>().tabBottomIndex.value = menuIndex;
    }
  }

  /// 平台 tab 点击:回壳层切该平台热门(pop 到根 + 热门页站点 tab 就位,
  /// 同壳层 _selectSiteId 的 animateTo 口径;落地页是热门页,分区页同步从略)。
  void _goHomeSite(String siteId) {
    closeAllFlyouts();
    Get.until((route) => route.name == RoutePath.kInitial);
    if (Get.isRegistered<FavoriteController>()) {
      Get.find<FavoriteController>().tabBottomIndex.value = HomeMenu.popular.index;
    }
    if (Get.isRegistered<PopularController>()) {
      final controller = Get.find<PopularController>();
      final fullIndex = controller.sites.indexWhere((s) => s.id == siteId);
      if (fullIndex >= 0) controller.tabController.animateTo(fullIndex);
    }
  }

  /// 浮层站点解析:热门页站点表按 id 查(与壳层 _siteById 同源同表)。
  Site? _siteById(String siteId) {
    if (!Get.isRegistered<PopularController>()) return null;
    for (final site in Get.find<PopularController>().sites) {
      if (site.id == siteId) return site;
    }
    return null;
  }

  /// 平台浮层点分类:先收浮层,回壳层(pop 到根)再进分类详情 —— 真源
  /// play 路由下 chip 是 context.go 离开播放页,对齐为「回壳层 + 推分类
  /// 房间路由」(kAreaRooms;CC 官方入口由 AppNavigator 回落外链)。
  void _openCategoryFromFlyout(Site site, LiveArea area) {
    closeAllFlyouts();
    Get.until((route) => route.name == RoutePath.kInitial);
    unawaited(AppNavigator.toCategoryDetail(site: site, category: area));
  }

  /// 关注浮层点小卡:先收浮层,再进播放页(压栈,真源同款 push)。
  void _openRoomFromFlyout(LiveRoom room) {
    closeAllFlyouts();
    unawaited(AppNavigator.toLiveRoomDetail(liveRoom: room));
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
          // 标题(真源 play_view.dart:645 口径「标题 ?? 解析失败/加载中」):
          // 详情标题优先;解析失败(loadError 已置)→「房间解析失败」;详情
          // 未到时先回列入参房标题(列表点击即知的现状口径,保留为次级回退),
          // 再退「加载中…」。
          final roomState = controller.state.value.room;
          final detailTitle = roomState.detail?.title?.trim() ?? '';
          final argTitle = controller.room.title?.trim() ?? '';
          final String title;
          if (detailTitle.isNotEmpty) {
            title = detailTitle;
          } else if (roomState.loadError != null) {
            title = '房间解析失败';
          } else if (argTitle.isNotEmpty) {
            title = argTitle;
          } else {
            title = '加载中…';
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ZishuRoomHeader(
                      room: room,
                      title: title,
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
/// 点击进分类)+ 标题(Expanded+Center 居中,TranslatedText 译文到达原位
/// 替换,真源 play_view.dart:922-935)+ 侧栏开合钮。
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
          // 标题 Expanded+Center 居中(真源 play_view.dart:922-935:仅标题,
          // 分类由左侧徽标承载);TranslatedText 自动中文化 —— 原文先显示,
          // 译文到达原位替换。
          Expanded(
            child: Center(
              child: TranslatedText(
                text: title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle),
              ),
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
