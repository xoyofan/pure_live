import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_category_flyout.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_follow_flyout.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_hover_overlay.dart';
import 'package:pure_live/zishu_app/shell/flyouts/zishu_my_category_flyout.dart';
import 'package:pure_live/zishu_app/shell/zishu_shell_top_bar.dart';

/// 顶栏 hover 浮层态机(平台分类 / 关注在播 / 我的分类),壳层
/// ([ZishuAppShell])与播放页([ZishuPlayView])共用:Timer 管开/关延迟,
/// 浮层互斥,开关调度口径与延迟常量同源([kZishuShellHoverCloseDelay] /
/// [kZishuShellHoverOpenDelay],对齐 zishu 真源 `_AppShellState`)。
///
/// 浮层本体由宿主在自己的 Stack 顶层渲染:调 [buildFlyoutOverlays] 取当前
/// 应展示的浮层列表(Positioned,须作 Stack 直接子级);宿主注入站点查找与
/// 「点分类 / 点小卡」动作(壳层=内嵌分类详情,播放页=回壳层路由跳转)。
/// 宿主 dispose 时调 [disposeFlyoutMachine] 清定时器。
mixin ZishuShellFlyoutMachine<T extends StatefulWidget> on State<T> {
  // ---- hover 浮层态机(自持于宿主 State;Timer 管开/关延迟,浮层互斥) ----

  /// 300ms 悬停开门定时器(平台 tab / 我的分类用;关注钮即时开)。
  Timer? _openTimer;

  /// 800ms 延迟关门定时器(离开触发区/浮层后统一走它)。
  Timer? _closeTimer;

  /// 当前打开分类浮层的站点 id(null = 关闭)。
  String? _flyoutPlatformId;
  double _platformFlyoutX = 0;

  /// 关注在播浮层开关与触发点中心 x。
  bool _followFlyoutOpen = false;
  double _followFlyoutX = 0;

  /// 我的分类浮层开关与触发点中心 x(hover 300ms 开 / 点击 toggle)。
  bool _myCategoryFlyoutOpen = false;
  double _myCategoryFlyoutX = 0;

  void cancelFlyoutClose() => _closeTimer?.cancel();

  /// 离开触发区/浮层:取消未成的开门,再排 800ms 延迟关门。
  void scheduleFlyoutClose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _closeTimer = Timer(kZishuShellHoverCloseDelay, () {
      if (!mounted) return;
      setState(() {
        _flyoutPlatformId = null;
        _followFlyoutOpen = false;
        _myCategoryFlyoutOpen = false;
      });
    });
  }

  /// 立即收起所有浮层(点分类跳转 / 点小卡进播放页 / 顶栏点击导航前调用)。
  void closeAllFlyouts() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _flyoutPlatformId = null;
      _followFlyoutOpen = false;
      _myCategoryFlyoutOpen = false;
    });
  }

  /// 平台 tab 悬停:先取消既有的开/关,300ms 后弹该平台分类浮层。
  void schedulePlatformFlyout(String siteId, double centerX) {
    _closeTimer?.cancel();
    _openTimer?.cancel();
    _openTimer = Timer(kZishuShellHoverOpenDelay, () => openPlatformFlyout(siteId, centerX));
  }

  /// 移出平台 tab:取消未成的开门,交给延迟关门。
  void cancelPlatformFlyoutOpen() {
    _openTimer?.cancel();
    scheduleFlyoutClose();
  }

  void openPlatformFlyout(String siteId, double centerX) {
    if (!mounted) return;
    _closeTimer?.cancel();
    // 浮层一开就补跑一轮目录加载:用户看到的应是此刻目录,而不是等分区页
    // 先被打开过。loadData 幂等(进行中复用同一 Future,已有数据不重拉)。
    if (Get.isRegistered<AreasListController>(tag: siteId)) {
      final controller = Get.find<AreasListController>(tag: siteId);
      if (controller.categories.isEmpty) {
        unawaited(controller.loadData());
      }
    }
    if (_flyoutPlatformId == siteId) {
      // 同一平台重复触发:浮层已开,不重建(触发点 x 不变,无需 setState)。
      return;
    }
    setState(() {
      _flyoutPlatformId = siteId;
      _platformFlyoutX = centerX;
      _followFlyoutOpen = false;
      _myCategoryFlyoutOpen = false;
    });
  }

  void openFollowFlyout(double centerX) {
    _closeTimer?.cancel();
    if (_followFlyoutOpen) {
      _followFlyoutX = centerX;
      return;
    }
    setState(() {
      _followFlyoutOpen = true;
      _followFlyoutX = centerX;
      _flyoutPlatformId = null;
      _myCategoryFlyoutOpen = false;
    });
  }

  /// 我的分类悬停:先取消既有的开/关,300ms 后弹浮层(平台 tab 同款开门延迟)。
  void scheduleMyCategoryFlyout(double centerX) {
    _closeTimer?.cancel();
    _openTimer?.cancel();
    _openTimer = Timer(kZishuShellHoverOpenDelay, () => openMyCategoryFlyout(centerX));
  }

  /// 移出我的分类:取消未成的开门,交给延迟关门。
  void cancelMyCategoryFlyoutOpen() {
    _openTimer?.cancel();
    scheduleFlyoutClose();
  }

  void openMyCategoryFlyout(double centerX) {
    if (!mounted) return;
    _closeTimer?.cancel();
    if (_myCategoryFlyoutOpen) {
      // 同一浮层重复触发:hover 已开,不重建(触发点 x 不变,无需 setState)。
      return;
    }
    setState(() {
      _myCategoryFlyoutOpen = true;
      _myCategoryFlyoutX = centerX;
      _flyoutPlatformId = null;
      _followFlyoutOpen = false;
    });
  }

  /// 我的分类点击 toggle(对齐 zishu 真源 `_toggleMyCategory`:已开即收,
  /// 未开立即弹,不等 300ms)。
  void toggleMyCategoryFlyout(double centerX) {
    if (_myCategoryFlyoutOpen) {
      closeAllFlyouts();
      return;
    }
    _closeTimer?.cancel();
    _openTimer?.cancel();
    setState(() {
      _myCategoryFlyoutOpen = true;
      _myCategoryFlyoutX = centerX;
      _flyoutPlatformId = null;
      _followFlyoutOpen = false;
    });
  }

  /// 当前应展示的浮层(平台分类 / 关注在播 / 我的分类)。宽度与内容同源:
  /// 分类宽度随 `categories` 分组数收缩(Obx 订阅),关注宽度随在播数收缩,
  /// 我的分类为固定 296px([kZishuMyCategoryFlyoutWidth])。
  ///
  /// 宿主注入:[siteById] 解析浮层站点(给分类跳转/分区归一用);
  /// [onOpenCategory] 平台浮层点分类(站点解析失败时不传,chip 不可点);
  /// [onOpenRoom] 关注浮层点小卡(宿主自负责先收浮层再跳转)。
  List<Widget> buildFlyoutOverlays({
    required Site? Function(String siteId) siteById,
    required void Function(Site site, LiveArea area)? onOpenCategory,
    required void Function(LiveRoom room) onOpenRoom,
  }) {
    final flyouts = <Widget>[];
    final platformId = _flyoutPlatformId;
    if (platformId != null) {
      final site = siteById(platformId);
      if (Get.isRegistered<AreasListController>(tag: platformId)) {
        flyouts.add(
          Obx(() {
            // 每次 Obx 重建都重新 find:lazyPut(fenix) 的实例可能被 smart
            // management 换新,闭包不能持有旧引用。
            final controller = Get.find<AreasListController>(tag: platformId);
            final groups = controller.categories;
            // 空目录区分「加载中 / 失败」:pageError 是 RxBool,失败时本 Obx
            // 也会随之重建(加载中文案见 openPlatformFlyout 触发的 loadData)。
            final emptyHint = controller.pageError.value ? '分类加载失败' : i18n('zishu_category_flyout_loading');
            return ZishuHoverOverlay(
              centerX: _platformFlyoutX,
              // siteId 与浮层同传:hover 平台 tab 的站点 id,浮层/宽度都按
              // 它做分区归一(与侧栏同源,见 category_sections.dart)。
              width: ZishuPlatformCategoryFlyout.widthFor(groups, siteId: platformId),
              child: ZishuPlatformCategoryFlyout(
                siteId: platformId,
                groups: groups,
                onEnter: cancelFlyoutClose,
                onExit: scheduleFlyoutClose,
                onOpenCategory: site == null ? null : (area) => onOpenCategory?.call(site, area),
                emptyHint: groups.isEmpty ? emptyHint : i18n('zishu_category_flyout_empty'),
              ),
            );
          }),
        );
      } else {
        // 站点目录控制器未注册(分区页尚未打开过):兜底空面板。
        flyouts.add(
          ZishuHoverOverlay(
            centerX: _platformFlyoutX,
            width: ZishuPlatformCategoryFlyout.minFlyoutWidth,
            child: ZishuPlatformCategoryFlyout(
              siteId: platformId,
              groups: const <AppLiveCategory>[],
              onEnter: cancelFlyoutClose,
              onExit: scheduleFlyoutClose,
            ),
          ),
        );
      }
    }
    if (_followFlyoutOpen) {
      flyouts.add(
        Obx(() {
          final rooms = SettingsService.to.fav.favoriteRooms.v.where((room) => room.isLiveNow).toList();
          final layout = ZishuFollowFlyout.layoutFor(rooms.length);
          return ZishuHoverOverlay(
            centerX: _followFlyoutX,
            width: layout.width,
            child: ZishuFollowFlyout(
              columns: layout.columns,
              rooms: rooms,
              onEnter: cancelFlyoutClose,
              onExit: scheduleFlyoutClose,
              onOpenRoom: onOpenRoom,
            ),
          );
        }),
      );
    }
    if (_myCategoryFlyoutOpen) {
      flyouts.add(
        ZishuHoverOverlay(
          centerX: _myCategoryFlyoutX,
          width: kZishuMyCategoryFlyoutWidth,
          child: ZishuMyCategoryFlyout(
            onEnter: cancelFlyoutClose,
            onExit: scheduleFlyoutClose,
            onClose: closeAllFlyouts,
          ),
        ),
      );
    }
    return flyouts;
  }

  /// 宿主 dispose 时清理开/关定时器。
  void disposeFlyoutMachine() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
  }
}
