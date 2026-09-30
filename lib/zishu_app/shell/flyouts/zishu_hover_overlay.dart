import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:pure_live/zishu/presentation/design_tokens.dart';

/// hover 浮层定位(移植 zishu 真源 `lib/src/app/shell/hover_overlay.dart`
/// 的 `_HoverOverlay`):水平以触发点为中心并夹到视口内;顶部留
/// [bridgeHeight] 透明桥接区(真源 `._kBridgeHeight`,SFVideoLive
/// `.nav-*-flyout::before`),鼠标从触发区移入浮层时不经过「非 hover 空白」。
///
/// 必须作为 [Stack] 的直接子级使用(`Positioned`);中间隔 Obx 等
/// 非渲染组件也可以(Widget 树上无中间 RenderObject)。
class ZishuHoverOverlay extends StatelessWidget {
  const ZishuHoverOverlay({super.key, required this.centerX, required this.width, required this.child});

  /// 顶栏下沿与浮层内容之间的透明桥接高度(真源 10px)。
  static const double bridgeHeight = 10;

  /// 浮层宽度夹取下限(真源 `_kFlyoutMinWidth`,12rem)。
  static const double minWidth = 192;

  /// 浮层宽度夹取上限(真源 `_kFlyoutMaxWidth`,56rem)。
  static const double maxWidth = 896;

  final double centerX;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final w = width.clamp(minWidth, math.min(maxWidth, screenWidth - 16)).toDouble();
    final left = (centerX - w / 2).clamp(8.0, math.max(8.0, screenWidth - w - 8)).toDouble();
    return Positioned(
      top: AppSpacing.topNavHeight - bridgeHeight,
      left: left,
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: bridgeHeight),
          child,
        ],
      ),
    );
  }
}
