import 'package:flutter/material.dart';

import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// hover 浮层面板容器(移植 zishu 真源
/// `lib/src/app/shell/category_flyout.dart` 的 `_FlyoutPanel`):面板底色
/// surface + 1px 边框 + 8px 圆角(allMd)+ popover 阴影
/// ([AppElevation.popover],黑 24%、blur 16、y+4);内容超高由 [maxHeight]
/// 约束后自行滚动。
///
/// 浮层挂在外壳 Stack 顶层、不在 Scaffold 的 Material 子树内,需自带
/// transparency Material 才能承载内部 InkWell(真源同款处理)。
class ZishuFlyoutPanel extends StatelessWidget {
  const ZishuFlyoutPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(9.6, 8.8, 9.6, 9.6),
    this.maxHeight = 416,
  });

  final Widget child;
  final EdgeInsets padding;

  /// 26rem @16px ≈ 416px(同真源 `.nav-platform-menu` 的 max-height)。
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.tokens.surface,
        border: Border.all(color: context.tokens.border),
        borderRadius: AppRadius.allMd,
        boxShadow: AppElevation.popover,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 浮层内的提示行(加载中/错误/空态),对齐真源 `_FlyoutHint`
/// (`.nav-platform-menu__hint`)。
class ZishuFlyoutHint extends StatelessWidget {
  const ZishuFlyoutHint(this.text, {super.key, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.2, vertical: 5.6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppFontSize.body,
          color: danger ? context.tokens.error : context.tokens.textSecondary,
        ),
      ),
    );
  }
}

/// 浮层内纵向滚动条:常驻 4px 细条(对齐真源 `_FlyoutScrollbar`,
/// web `scrolly` 的 `scrollbar-width: thin` + 4px)。
class ZishuFlyoutScrollbar extends StatelessWidget {
  const ZishuFlyoutScrollbar({super.key, required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(AppRadius.pill),
      child: child,
    );
  }
}
