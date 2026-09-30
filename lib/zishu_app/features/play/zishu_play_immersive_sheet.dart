import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 沉浸态(全屏/宽屏)右缘侧抽屉,移植自 zishu_flutter
/// `lib/src/features/play/widgets/play_immersive_side_sheet.dart`
/// (对齐 SFVideoLive web `PlayImmersiveSideSheet.vue`)。
///
/// web 真源结构(挂在 #play-frame 内的绝对定位层):
/// - 透明遮罩铺满舞台,点击关闭;
/// - 右缘 drawer = 左侧 toggle 把手(18.4px × 40px,左圆角 4px,
///   chevron-right,点击收起)+ 右侧 panel(与播放侧栏同宽,全高,
///   左边框 + 左投影 `-6px 0 28px rgba(0,0,0,.55)`,token
///   [AppElevation.sheet]);
/// - 出入动效:遮罩 opacity + drawer `translateX(100%)`,
///   250ms `--fluent-easing`(token [AppMotion.normal]/[AppMotion.curve]);
/// - 关闭后不拦截命中(Vue v-show → display:none)。
///
/// 与真源的两点差异(移植时收敛进本组件):
/// - 打开/关闭状态由调用方持有:[visible] 为 true 时本组件排程
///   3s 无交互自动收起(真源在 play_view 的 `_scheduleImmersiveSideHide`);
///   面板内指针按下/悬停/移动/滚轮与滚动交互会重置该计时
///   (真源经 `onInteract` 上报,这里组件内部消化)。
/// - 720ms 防抖锁(真源 play_view `_onChromeVisibilityChanged`:进入沉浸态
///   后 720ms 内拒绝打开抽屉)仍属**调用方**:本组件看不到「进入沉浸态」
///   这个事件,调用方应在其沉浸态切换处自行持锁,锁内不把 [visible] 置 true。
///
/// 本组件 build 返回 [Positioned.fill],必须作为舞台 [Stack] 的直接子级放置。
class ZishuPlayImmersiveSheet extends StatefulWidget {
  const ZishuPlayImmersiveSheet({
    super.key = const Key('play-immersive-sheet'),
    required this.child,
    required this.visible,
    required this.onToggle,
    this.panelWidth,
    this.autoCollapseAfter = const Duration(seconds: 3),
  });

  /// 面板内容,由调用方传入(通常为播放侧栏,与常规侧栏同一组件)。
  final Widget child;

  /// 打开/关闭状态(调用方持有)。
  final bool visible;

  /// 点击遮罩 / toggle 把手 / 3s 自动收起超时 → 上报开合切换,
  /// 调用方翻转 [visible]。
  final VoidCallback onToggle;

  /// 面板宽度;缺省按视口分档取 [AppSpacing.playSidePanelWidthFor]
  /// (268/328/392/425,对齐 web `--immersive-panel-width`)。
  final double? panelWidth;

  /// 无交互自动收起延时(web `scheduleHideImmersiveSide` 为 3s)。
  final Duration autoCollapseAfter;

  @override
  State<ZishuPlayImmersiveSheet> createState() => _ZishuPlayImmersiveSheetState();
}

class _ZishuPlayImmersiveSheetState extends State<ZishuPlayImmersiveSheet> {
  /// 3s 无交互自动收起计时(web `scheduleHideImmersiveSide`)。
  Timer? _autoCollapseTimer;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _scheduleAutoCollapse();
  }

  @override
  void didUpdateWidget(ZishuPlayImmersiveSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _scheduleAutoCollapse();
      } else {
        _cancelAutoCollapse();
      }
    }
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = null;
    super.dispose();
  }

  /// 排程 3s 无交互自动收起(web `scheduleHideImmersiveSide`)。
  /// 到时经 [ZishuPlayImmersiveSheet.onToggle] 上报,由调用方收起。
  void _scheduleAutoCollapse() {
    _autoCollapseTimer?.cancel();
    if (!widget.visible) return;
    _autoCollapseTimer = Timer(widget.autoCollapseAfter, () {
      if (mounted && widget.visible) widget.onToggle();
    });
  }

  void _cancelAutoCollapse() {
    _autoCollapseTimer?.cancel();
    _autoCollapseTimer = null;
  }

  /// 面板内任意交互(指针按下/悬停/移动/滚轮/滚动):重置自动收起计时。
  void _handleInteract() {
    if (widget.visible) _scheduleAutoCollapse();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = widget.panelWidth ?? AppSpacing.playSidePanelWidthFor(constraints.maxWidth);
        return Positioned.fill(
          // 关闭后不拦截舞台点击(对齐 v-show display:none);动画期间即阻断。
          child: IgnorePointer(
            ignoring: !widget.visible,
            child: AnimatedOpacity(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              opacity: widget.visible ? 1 : 0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 透明遮罩:抽屉开着时点击舞台空白区 = 关闭(web onBackdropClick)。
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // 遮罩本身可点(点空白关闭抽屉):补指针光标,与舞台一致。
                      onTap: widget.onToggle,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedSlide(
                      duration: AppMotion.normal,
                      curve: AppMotion.curve,
                      // 关闭时整体平移自身宽度,完全滑出右缘(web translateX(100%))。
                      offset: widget.visible ? Offset.zero : const Offset(1, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // toggle 把手(面板左缘中央,web __toggle)。
                          // Material 透明壳只为 InkWell 提供水波纹宿主;
                          // 底色/三边框/左圆角由 Container 承担(web 右边框 none,
                          // 避免与面板左边框贴成双线)。
                          Material(
                            color: Colors.transparent,
                            child: Container(
                              key: const Key('play-immersive-toggle'),
                              width: 18.4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tokens.surface,
                                border: Border(
                                  left: BorderSide(color: tokens.border),
                                  top: BorderSide(color: tokens.border),
                                  bottom: BorderSide(color: tokens.border),
                                ),
                                borderRadius: const BorderRadius.horizontal(
                                  // web `--drawer-toggle-radius` =
                                  // `--el-border-radius-base`(4px,非 8 兜底)。
                                  left: Radius.circular(AppRadius.sm),
                                ),
                              ),
                              child: InkWell(
                                onTap: widget.onToggle,
                                // hover / 按下 / 键盘焦点补全(只改覆盖色,不动尺寸)。
                                hoverColor: tokens.surfaceRaised,
                                splashColor: AppStateLayer.splashOf(tokens.accent),
                                highlightColor: AppStateLayer.pressedOf(tokens.accent),
                                focusColor: AppStateLayer.focusOf(tokens.accent),
                                child: Icon(Icons.chevron_right_rounded, size: 13, color: tokens.textSecondary),
                              ),
                            ),
                          ),
                          // 面板:全高、左边框 + 左投影(web __panel)。
                          Container(
                            key: const Key('play-immersive-panel'),
                            width: panelWidth,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              border: Border(left: BorderSide(color: tokens.border)),
                              // web: -6px 0 28px rgba(0,0,0,.55)。
                              boxShadow: AppElevation.sheet,
                            ),
                            // 指针按下/移动/滚轮 + 滚动:重置自动收起计时
                            // (真源经 onInteract 上报,这里组件内部消化)。
                            child: Listener(
                              onPointerDown: (_) => _handleInteract(),
                              onPointerHover: (_) => _handleInteract(),
                              onPointerMove: (_) => _handleInteract(),
                              onPointerSignal: (_) => _handleInteract(),
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (_) {
                                  _handleInteract();
                                  return false;
                                },
                                child: widget.child,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
