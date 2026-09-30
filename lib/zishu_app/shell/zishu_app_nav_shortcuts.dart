/// 全局导航快捷键(桌面壳层):对齐 zishu 真源
/// `lib/src/app/app_nav_shortcuts.dart`。
///
/// 真源快捷键清单(逐项照录;真源没有 Alt+数字切平台/主导航,本轨不自创):
/// - 后退:`Alt+←`、鼠标侧键 X1(kBackMouseButton);
/// - 前进:`Alt+→`、鼠标侧键 X2(kForwardMouseButton);
/// - 首页:`Alt+Home`(真源 go '/all',我方对齐为回热门菜单);
/// - 搜索:`Ctrl+F` / `Ctrl+K` —— 我方壳层已实现(zishu_app_shell 的
///   CallbackShortcuts),本挂点不重复绑定,避免双入口;
/// - 刷新:`F5`(真源按注册分发 refreshPlay > refreshHome,我方对齐为
///   刷新当前主导航页,见 [ZishuAppNavShortcuts.onRefreshCurrentPage]);
/// - Windows runner 兜底通道 `zishu/windows/nav_syskey`(back/forward/
///   home,真源 nav_syskey_channel.dart 同款):本文件只挂 Dart 侧
///   handler,runner C++ 识别 `KF_ALTDOWN` 的下发端在本轨白名单外未实现
///   —— 当前 Windows 实际路径是 SingleActivator(即真源保留的兼容兜底),
///   通道先行就位,日后补 runner 端无需再改本类。
///
/// ## 与真源的两处转写差异(语义对齐,非逐字翻译)
///
/// **挂接层**:真源在 `MaterialApp.builder` 挂接(builder 层是路由 Scope
/// 的焦点祖先,绑在壳层内初始态收不到按键 —— 真源注释实测)。本壳无
/// builder 层可改(白名单限壳层),沿用壳层既有 Ctrl+F/K 挂点先例:本
/// 组件是焦点锚点 `Focus(autofocus)` 的祖先,按键自 primaryFocus 沿祖先
/// 链冒泡到这里,Focus 冒泡语义与壳层既有快捷键一致。同一代价:播放页
/// 等 push 路由持有焦点时本层收不到按键(快捷键静默,不与播放页
/// Esc/Space/M/F/W 抢键,同真源「分工不变」口径)。
///
/// **历史栈**:真源后退/前进是 GoRouter location 双栈(其顶层平铺路由
/// `go()` 会清空 Navigator 栈,不能依赖 canPop);我方 GetX 命名路由恰
/// 好相反 —— push 路由是真实 Navigator 栈,而主导航菜单切换是单路由内
/// 的 index 状态,不在 Navigator 栈里。故双栈对齐转写为「菜单双栈」:
/// 用户切菜单 = 走到新分支(当前菜单入后退栈、清空前进栈),back /
/// forward / home 自家动作带 `_selfNavigation` 标记不改写双栈(真源
/// AppNavHistory 同款语义);后退时若根导航器还有上层路由,先 maybePop
/// 退栈(最近的历史边是那次 push,时间序对齐真源;maybePop 尊重播放页
/// 路由级 PopScope 的自有后退语义),栈退空后才回菜单来路。
library;

import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show kBackMouseButton, kForwardMouseButton;
import 'package:flutter/services.dart';

import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/index.dart';

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

/// 桌面壳层全局导航快捷键(Alt+←/→/Home、F5、鼠标侧键 X1/X2)。
///
/// 挂在壳层 build 根部包住既有 Ctrl+F/K 的 CallbackShortcuts 子树;键集
/// 互不相交,内层先收 Ctrl+F/K,Alt/F5 沿祖先链继续冒泡到本层。
class ZishuAppNavShortcuts extends StatefulWidget {
  const ZishuAppNavShortcuts({
    super.key,
    required this.child,
    required this.index,
    required this.onNavigateToMenu,
    this.onRefreshCurrentPage,
  });

  final Widget child;

  /// 当前主导航菜单(壳层 widget.index 原样透传):历史栈以它观察用户导航。
  final int index;

  /// 菜单导航出口(壳层 `_navigateToMenu`):back / forward / home 自家
  /// 动作经它落地,与用户点击导航同一收口(内嵌分类详情态作废等副作用
  /// 因此不旁路)。
  final void Function(int menuIndex) onNavigateToMenu;

  /// F5 刷新当前主导航页(壳层分发到对应控制器;null 时静默 —— 真源
  /// 「不可用的快捷键不报错」同口径)。
  final VoidCallback? onRefreshCurrentPage;

  @override
  State<ZishuAppNavShortcuts> createState() => _ZishuAppNavShortcutsState();
}

class _ZishuAppNavShortcutsState extends State<ZishuAppNavShortcuts> {
  /// runner 层兜底通道的清理函数(见 [installNavSyskeyChannel])。
  VoidCallback? _navSyskeyCleanup;

  /// 后退栈:走过的菜单 index,栈顶是「来路」。
  final List<int> _backStack = [];

  /// 前进栈:被后退放弃的菜单 index,栈顶是最近的那个。
  final List<int> _forwardStack = [];

  /// 最近一次已知菜单(菜单变化在重建**之后**才被本组件看到,只能靠
  /// 自己记住上一站,才能在用户导航时把「来路」压进后退栈)。
  int? _current;

  /// 本次菜单变化由 back / forward / home 发起的标记:[didUpdateWidget]
  /// 据此区分「自家动作」与「用户导航」,只有后者才改写双栈(真源
  /// AppNavHistory._selfNavigation 同款)。
  bool _selfNavigation = false;

  @override
  void initState() {
    super.initState();
    _current = widget.index;
    _navSyskeyCleanup = installNavSyskeyChannel(onBack: _back, onForward: _forward, onHome: _home);
  }

  @override
  void dispose() {
    _navSyskeyCleanup?.call();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ZishuAppNavShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    final previous = _current;
    _current = widget.index;
    if (_selfNavigation) {
      _selfNavigation = false;
      return;
    }
    // 首次记录(启动)与原地重复通知不构成历史边(真源 _onRouteChanged 同款)。
    if (previous == null || previous == widget.index) return;
    // 用户自行导航(点主导航 / 平台 tab):当前菜单成为「来路」入后退栈,
    // 前进语义失效 —— 浏览器同款开新分支。
    _forwardStack.clear();
    if (_backStack.isEmpty || _backStack.last != previous) {
      _backStack.add(previous);
    }
  }

  /// 后退:根导航器还有上层路由时先 maybePop(尊重路由级 PopScope,如
  /// 播放页的后退语义);否则回菜单「来路」。双栈皆空静默,也永不把壳层
  /// 根路由 pop 出去 —— 首页 PopScope(canPop:false) 的最小化到桌面语义
  /// 不被本快捷键触发。
  void _back() {
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
      widget.onNavigateToMenu(target);
      return;
    }
  }

  /// 前进:回到最近一次被后退放弃的菜单;栈空静默不动作(Navigator 无
  /// 前进概念,前进只覆盖菜单双栈 —— 真源「栈空静默」同口径)。
  void _forward() {
    final current = _current;
    if (current == null) return;
    while (_forwardStack.isNotEmpty) {
      final target = _forwardStack.removeLast();
      if (target == current) continue;
      _backStack.add(current);
      _selfNavigation = true;
      widget.onNavigateToMenu(target);
      return;
    }
  }

  /// 首页:回热门菜单(真源 `go('/all')` 同语义)—— 当前菜单入后退栈、
  /// **不清前进栈**(Alt+Home 后仍可 Alt+→ 回到刚才的页);已在首页 no-op。
  void _home() {
    final homeIndex = HomeMenu.popular.index;
    final current = _current;
    if (current == null || current == homeIndex) return;
    if (_backStack.isEmpty || _backStack.last != current) {
      _backStack.add(current);
    }
    _selfNavigation = true;
    widget.onNavigateToMenu(homeIndex);
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
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointer,
        child: widget.child,
      ),
    );
  }

  /// F5 分发:刷新当前主导航页(壳层注入);未注入时静默。
  void _refresh() => widget.onRefreshCurrentPage?.call();
}
