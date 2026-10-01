/// 全局导航快捷键(**GetMaterialApp.builder 层**):对齐 zishu 真源
/// `lib/src/app/app_nav_shortcuts.dart` 的真源架构 —— builder 层收键分发,
/// 路由内组件经 [GlobalActions] 注册动作落地(注册表桥接原理见
/// zishu_global_actions.dart 头注:快捷键靠焦点祖先生效,只有 builder 层是
/// 所有路由焦点 Scope 的公共祖先;绑定在壳层/播放页内,焦点被 push 路由
/// 持有时收不到按键)。
///
/// 键集(与真源对齐;真源没有 Alt+数字切平台/主导航,本轨不自创):
/// - 后退:`Alt+←`、鼠标侧键 X1(kBackMouseButton);
/// - 前进:`Alt+→`、鼠标侧键 X2(kForwardMouseButton);
/// - 首页:`Alt+Home`(真源 go '/all',我方对齐为回热门菜单);
/// - 刷新:`F5`(浏览器式 —— [GlobalActions.isActive] 判定注册者:播放页
///   注册了 refreshPlay 时走播放页刷新,否则 refreshHome 首页刷新)。
/// - 搜索:`Ctrl+F` / `Ctrl+K` **不在本层**:现状键集无此键(此前由壳层
///   CallbackShortcuts 挂接),守卫口径「现状没有就不加,只搬现有键集」;
///   壳层既有挂点照旧,经 GlobalActions 的 search 注册落地。
///
/// Windows runner 兜底通道 `zishu/windows/nav_syskey`(back/forward/home,
/// 真源 nav_syskey_channel.dart 同款签名保留):本文件只挂 Dart 侧
/// handler,runner C++ 识别 `KF_ALTDOWN` 的下发端在本轨白名单外未实现
/// —— 当前 Windows 实际路径是 SingleActivator(即真源保留的兼容兜底),
/// 通道先行就位,日后补 runner 端无需再改本类。
///
/// ## 历史栈:主导航菜单双栈(真源 AppNavHistory 的 GetX 转写)
///
/// 真源后退/前进是 GoRouter location 双栈;我方 GetX 命名路由的 push 路由
/// 是真实 Navigator 栈,而主导航菜单切换是单路由内的 index 状态,不在
/// Navigator 栈里。故双栈对齐转写为「菜单双栈」([ZishuAppNavHistory]):
/// - 用户切菜单 = 走到新分支(当前菜单入后退栈、清空前进栈);
/// - back / forward / home 自家动作带 `_selfNavigation` 标记不改写双栈
///   (真源 AppNavHistory 同款语义);
/// - 后退时若根导航器还有上层路由(播放页等 push 路由),先 maybePop 退栈
///   (最近的历史边是那次 push,时间序对齐真源;maybePop 尊重播放页路由级
///   PopScope 的自有后退语义),栈退空后才回菜单来路;双栈皆空静默。
///
/// builder 层组件不持有壳层的 index/导航出口:菜单 index 变化由壳层
/// (路由内唯一感知方)经 [ZishuAppNavHistory.reportMenuChanged] 上报,
/// back/forward/home 的菜单落地也经壳层注册的导航出口执行(与用户点击
/// 导航同一收口,内嵌分类详情态作废等副作用不被旁路)。
library;

import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show kBackMouseButton, kForwardMouseButton;
import 'package:flutter/services.dart';

import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu_app/shell/zishu_global_actions.dart';

/// runner 层 Alt+导航键兜底通道(仅 Windows 下有下发方)。
const MethodChannel _navSyskeyChannel = MethodChannel('zishu/windows/nav_syskey');

/// 挂接 runner 下发的导航键消息;非 Windows/Web 返回 null(无清理动作)。
///
/// 返回的清理函数随调用方 dispose 执行,解除 handler 防泄漏。
VoidCallback? installNavSyskeyChannel({
  required VoidCallback onBack,
  required VoidCallback onForward,
  required VoidCallback onHome,
}) {
  if (kIsWeb || !Platform.isWindows) return null;
  _navSyskeyChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'back':
        onBack();
      case 'forward':
        onForward();
      case 'home':
        onHome();
    }
    return null;
  });
  return () => _navSyskeyChannel.setMethodCallHandler(null);
}

/// 主导航菜单双栈历史(浏览器式后退/前进,真源 AppNavHistory 的 GetX 转写)。
///
/// 单例([instance])由两方共享:
/// - [ZishuAppNavShortcuts](builder 层)负责把 Alt 快捷键/鼠标侧键/runner
///   syskey 通道接到 back/forward/home;
/// - 壳层(路由内,唯一感知主导航 index 的组件)经 [attachMenuExit] 注册
///   菜单导航出口、经 [reportMenuChanged] 上报 index 变化。
class ZishuAppNavHistory {
  ZishuAppNavHistory._();

  static final ZishuAppNavHistory instance = ZishuAppNavHistory._();

  /// 后退栈:走过的菜单 index,栈顶是「来路」。
  final List<int> _backStack = [];

  /// 前进栈:被后退放弃的菜单 index,栈顶是最近的那个。
  final List<int> _forwardStack = [];

  /// 最近一次已知菜单(index 变化在重建**之后**才被壳层看到,只能靠自己
  /// 记住上一站,才能在用户导航时把「来路」压进后退栈)。
  int? _current;

  /// 本次菜单变化由 back / forward / home 发起的标记:[reportMenuChanged]
  /// 据此区分「自家动作」与「用户导航」,只有后者才改写双栈(真源
  /// AppNavHistory._selfNavigation 同款)。
  bool _selfNavigation = false;

  /// 壳层注册的菜单导航出口(owner 口径同 GlobalActions:注销按 owner 对象
  /// 身份判定,不误删新壳层实例的注册)。
  Object? _exitOwner;
  void Function(int menuIndex)? _exit;

  /// 注册菜单导航出口(壳层 `_navigateToMenu`)。
  void attachMenuExit({required Object owner, required void Function(int menuIndex) exit}) {
    _exitOwner = owner;
    _exit = exit;
  }

  /// 注销菜单导航出口;仅当仍归 [owner] 所有时移除。
  void detachMenuExit({required Object owner}) {
    if (identical(_exitOwner, owner)) {
      _exitOwner = null;
      _exit = null;
    }
  }

  /// 壳层在主导航 index 变化后上报(等价真源路由监听 _onRouteChanged):
  /// 首次记录(启动)与原地重复通知不构成历史边;用户自行导航(点主导航/
  /// 平台 tab/播放页回壳层切菜单)时,当前菜单成为「来路」入后退栈,前进
  /// 语义失效 —— 浏览器同款开新分支。
  void reportMenuChanged(int index) {
    final previous = _current;
    _current = index;
    if (_selfNavigation) {
      _selfNavigation = false;
      return;
    }
    if (previous == null || previous == index) return;
    _forwardStack.clear();
    if (_backStack.isEmpty || _backStack.last != previous) {
      _backStack.add(previous);
    }
  }

  /// 后退:根导航器还有上层路由时先 maybePop(尊重路由级 PopScope,如
  /// 播放页的后退语义);否则回菜单「来路」。双栈皆空静默,也永不把壳层
  /// 根路由 pop 出去 —— 首页 PopScope(canPop:false) 的最小化到桌面语义
  /// 不被本快捷键触发。
  void back() {
    final navigator = Get.key.currentState;
    if (navigator != null && navigator.canPop()) {
      unawaited(navigator.maybePop());
      return;
    }
    final current = _current;
    if (current == null) return;
    while (_backStack.isNotEmpty) {
      final target = _backStack.removeLast();
      if (target == current) continue; // 与当前相同的陈旧项:丢弃,不构成边
      _forwardStack.add(current);
      _selfNavigation = true;
      _exit?.call(target);
      return;
    }
  }

  /// 前进:回到最近一次被后退放弃的菜单;栈空静默不动作(Navigator 无
  /// 前进概念,前进只覆盖菜单双栈 —— 真源「栈空静默」同口径)。
  void forward() {
    final current = _current;
    if (current == null) return;
    while (_forwardStack.isNotEmpty) {
      final target = _forwardStack.removeLast();
      if (target == current) continue;
      _backStack.add(current);
      _selfNavigation = true;
      _exit?.call(target);
      return;
    }
  }

  /// 首页:回热门菜单(真源 `go('/all')` 同语义)—— 当前菜单入后退栈、
  /// **不清前进栈**(Alt+Home 后仍可 Alt+→ 回到刚才的页);已在首页 no-op。
  void home() {
    final homeIndex = HomeMenu.popular.index;
    final current = _current;
    if (current == null || current == homeIndex) return;
    if (_backStack.isEmpty || _backStack.last != current) {
      _backStack.add(current);
    }
    _selfNavigation = true;
    _exit?.call(homeIndex);
  }
}

/// 应用级全局导航快捷键(Alt+←/→/Home、F5、鼠标侧键 X1/X2)。
///
/// 挂在 `GetMaterialApp.builder`,包住路由内容,**全页面生效**(真源
/// app_nav_shortcuts 同位 —— 快捷键靠焦点祖先生效,只有 builder 层是所有
/// 路由焦点 Scope 的公共祖先)。[child] 原样透传,不改布局。
class ZishuAppNavShortcuts extends StatefulWidget {
  const ZishuAppNavShortcuts({super.key, required this.child});

  final Widget child;

  @override
  State<ZishuAppNavShortcuts> createState() => _ZishuAppNavShortcutsState();
}

class _ZishuAppNavShortcutsState extends State<ZishuAppNavShortcuts> {
  /// runner 层兜底通道的清理函数(见 [installNavSyskeyChannel])。
  VoidCallback? _navSyskeyCleanup;

  @override
  void initState() {
    super.initState();
    _navSyskeyCleanup = installNavSyskeyChannel(onBack: _back, onForward: _forward, onHome: _home);
  }

  @override
  void dispose() {
    _navSyskeyCleanup?.call();
    super.dispose();
  }

  void _back() => ZishuAppNavHistory.instance.back();

  void _forward() => ZishuAppNavHistory.instance.forward();

  void _home() => ZishuAppNavHistory.instance.home();

  /// 浏览器式 F5:播放页在栈顶时重开当前线路,否则刷新平台首页列表。
  ///
  /// 分发依据是「谁注册了」(真源同款):播放页注册 refreshPlay、壳层注册
  /// refreshHome,注销随 dispose 天然反映当前可见页面 —— 播放页 push 后
  /// 壳层仍在路由下,但 refreshPlay 优先;播放页离开即注销,回落
  /// refreshHome。
  void _refresh() {
    if (GlobalActions.isActive(GlobalActionNames.refreshPlay)) {
      GlobalActions.call(GlobalActionNames.refreshPlay);
      return;
    }
    GlobalActions.call(GlobalActionNames.refreshHome);
  }

  /// 鼠标侧键(X1 后退 / X2 前进):落点无关的全局手势,Listener opaque
  /// 让空白区也参与命中(真源 _handlePointer 同款)。
  void _handlePointer(PointerDownEvent event) {
    final buttons = event.buttons;
    if (buttons & kBackMouseButton != 0) {
      _back();
    } else if (buttons & kForwardMouseButton != 0) {
      _forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Alt+← / Alt+→ = 浏览器后退 / 前进。Windows 下文本编辑默认绑定
        // 是 ctrl+←/→ 移词,不占用 alt+方向键,输入框聚焦时也不会被抢。
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _back,
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): _forward,
        const SingleActivator(LogicalKeyboardKey.home, alt: true): _home,
        // F5 = 浏览器式刷新(裸 F5,无修饰;文本输入不产生该键,无冲突)。
        const SingleActivator(LogicalKeyboardKey.f5): _refresh,
      },
      child: Listener(
        // opaque:空白区也参与命中 —— 鼠标侧键(X1/X2)是落点无关的全局手势。
        // 不根据全局键盘状态阻断子树命中:child(builder 的路由内容)必须
        // 原样透传,页面自身的手势/点击不受影响。
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointer,
        child: widget.child,
      ),
    );
  }
}
