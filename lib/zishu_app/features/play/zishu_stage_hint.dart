/// 舞台提示浮层:播放页视频区内的轻量操作反馈 pill,移植自 zishu_flutter
/// 播放页的操作反馈通路。
///
/// 真源形态(读源结论,非自定义浮层组件):zishu 播放域的操作反馈统一走
/// 播放页根级 Scaffold 宿主的 SnackBar ——
/// - `player_controls.dart:633-639` `_toast`:`..hideCurrentSnackBar()
///   ..showSnackBar(SnackBar(duration: 2s))`(睡眠定时设定/取消);
/// - `player_controls.dart:224-229`:「刷新视频」→「已刷新」2s;
/// - `play_view.dart:421-429`:睡眠定时到点 → 3s;
/// 动画为 Material SnackBar 默认淡入 + 自下滑入(约 250ms)。
///
/// 本组件把同语义搬进**舞台内**:显式浮 pill(控制条上方居中),重复
/// `show` 先取消前一次计时再重排(对齐 `hideCurrentSnackBar` 语义);
/// 自动消失默认 2s(真源 `_toast`/「已刷新」同时长),出入场动画用
/// AppMotion 令牌(`normal` 250ms + `curve`,对齐 SnackBar 默认动画档)。
/// 替换播放域原有的全局 `ToastUtil` 反馈,使反馈落在播放页舞台内,
/// 不再是全屏级 toast。
///
/// 挂接:`build` 返回 [Positioned],**必须作为舞台 [Stack] 的直接子级**
/// (与 ZishuSleepTimerBadge 同约束);不吸收命中(IgnorePointer),
/// 不影响视频手势层。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 舞台提示通道:静态入口,与原 `ToastUtil.show` 同样免 context;
/// 播放页舞台内的 [ZishuStageHint] 监听本通道并呈现。
class ZishuStageHint {
  ZishuStageHint._();

  /// 显示纪元:每次 [show] 自增,监听方据此重排计时与文案。
  static final ValueNotifier<int> _epoch = ValueNotifier<int>(0);

  static String _message = '';
  static Duration _duration = const Duration(seconds: 2);

  /// 最近一次提示的文案(监听方在 epoch 变更时读取)。
  static String get message => _message;

  /// 最近一次提示的可见时长。
  static Duration get duration => _duration;

  /// 显示一条舞台提示,默认可见 2s(真源 `_toast`/「已刷新」同时长;
  /// 真源睡眠定时到点用 3s,调用方按需传 [duration])。
  /// 重复调用先撤前一次再重排(对齐 `..hideCurrentSnackBar()..showSnackBar`)。
  static void show(String text, {Duration duration = const Duration(seconds: 2)}) {
    if (text.isEmpty) return;
    _message = text;
    _duration = duration;
    _epoch.value++;
  }
}

/// 舞台提示浮层本体:挂舞台 Stack 的直接子级,监听 [ZishuStageHint.show]。
class ZishuStageHintOverlay extends StatefulWidget {
  const ZishuStageHintOverlay({super.key});

  @override
  State<ZishuStageHintOverlay> createState() => _ZishuStageHintState();
}

class _ZishuStageHintState extends State<ZishuStageHintOverlay> {
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    ZishuStageHint._epoch.addListener(_handleEpoch);
  }

  @override
  void dispose() {
    ZishuStageHint._epoch.removeListener(_handleEpoch);
    _hideTimer?.cancel();
    _hideTimer = null;
    super.dispose();
  }

  /// 新提示到达:撤旧计时 → 立即显示 → 按 [ZishuStageHint.duration] 自动隐藏。
  void _handleEpoch() {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() => _visible = true);
    _hideTimer = Timer(ZishuStageHint.duration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Positioned(
      left: 0,
      right: 0,
      // 控制条(48px)上方 12px:浮在视频区内、不与控制条重叠(真源
      // CaptionOverlay 的舞台内贴底定位带同思路,bottom 68)。
      bottom: 60,
      child: IgnorePointer(
        child: Center(
          child: AnimatedOpacity(
            // 出入场 250ms + fluent 曲线:对齐 Material SnackBar 默认动画档,
            // 数值取 AppMotion 令牌(动画一律走 AppMotion)。
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            opacity: _visible ? 1.0 : 0.0,
            child: AnimatedSlide(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              // 隐藏态下滑一个自身高度,复刻 SnackBar 自下而上的出入方向。
              offset: _visible ? Offset.zero : const Offset(0, 1),
              child: Container(
                key: const Key('play-stage-hint'),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  // 舞台 pill 底:沿用 ZishuSleepTimerBadge 的 token 口径
                  // (surfaceRaised 72% + textPrimary,深浅主题各自解析)。
                  color: tokens.surfaceRaised.withValues(alpha: 0.72),
                  borderRadius: AppRadius.allPill,
                  boxShadow: AppElevation.hairline,
                ),
                child: Text(
                  ZishuStageHint.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textCaption.copyWith(color: tokens.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
