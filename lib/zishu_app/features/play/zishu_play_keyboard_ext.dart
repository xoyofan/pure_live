import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 键盘 M/F/W 快捷键扩展(可复用 Widget 包装),补齐 zishu 播放页
/// (play_view.dart:475-484)在 pure_live 侧缺的三枚键位。
///
/// 键位分工(与既有 [VideoKeyboardShortcuts] 互不重叠 —— 该文件
/// lib/modules/live_play/widgets/keyboard/video_keyboard.dart:53-80 已绑定
/// Escape/媒体键/Space/R/↑↓,M/F/W 均空闲):
/// - **M** 静音切换:当前音量 > 0 → 记住当前值并置 0;当前音量 == 0 →
///   恢复记住的值(本 State 生命周期内的记忆;从未记住过则取
///   [restoreFallbackVolume],默认 1.0,与房间 savedVolume 缺省一致)。
/// - **F** [onToggleFullScreen](视频全屏)。
/// - **W** [onToggleWindowFullScreen](窗口全屏/宽屏)。
///
/// 回调全部由参数注入,本文件不 Get.find,保持可测试;接线示例:
/// ```dart
/// ZishuPlayKeyboardShortcutsExt(
///   readVolume: videoController.volume,
///   writeVolume: (v) async {
///     await videoController.setVolume(v);
///     videoController.updateVolumn(v); // 控制条音量 UI 同步(方法名即如此拼)。
///   },
///   onToggleFullScreen: () => unawaited(videoController.toggleFullScreen()),
///   onToggleWindowFullScreen: videoController.toggleWindowFullScreen,
///   child: child,
/// )
/// ```
/// (VideoController API 见
/// lib/modules/live_play/widgets/video_player/video_controller.dart:791/801/816/1323/1496。)
///
/// 结构对齐既有 [VideoKeyboardShortcuts]:[CallbackShortcuts] 沿焦点链查找,
/// 外面套 `FocusScope(autofocus: true)` 保证独立使用时也有焦点目标;
/// 嵌在既有包装内时不抢焦点。字母键留在焦点树内(不进全局 handler),
/// 焦点在聊天输入框时由输入框先消费,不会抢打字。
class ZishuPlayKeyboardShortcutsExt extends StatefulWidget {
  const ZishuPlayKeyboardShortcutsExt({
    super.key,
    required this.readVolume,
    required this.writeVolume,
    this.onToggleFullScreen,
    this.onToggleWindowFullScreen,
    required this.child,
    this.restoreFallbackVolume = 1.0,
  });

  /// 读当前音量(0.0–1.0;无法读取返回 null,M 键静默忽略)。
  final Future<double?> Function() readVolume;

  /// 写音量(含 UI 状态同步,由调用方封装)。
  final Future<void> Function(double volume) writeVolume;

  /// F 键:视频全屏切换;null 时不绑定 F。
  final VoidCallback? onToggleFullScreen;

  /// W 键:窗口全屏(宽屏)切换;null 时不绑定 W。
  final VoidCallback? onToggleWindowFullScreen;

  final Widget child;

  /// 音量为 0 且无静音前记忆时的恢复值。
  final double restoreFallbackVolume;

  @override
  State<ZishuPlayKeyboardShortcutsExt> createState() => _ZishuPlayKeyboardShortcutsExtState();
}

class _ZishuPlayKeyboardShortcutsExtState extends State<ZishuPlayKeyboardShortcutsExt> {
  /// 静音前的音量记忆(仅本 State 生命周期内有效)。
  double? _rememberedVolume;

  /// M:volume==0 记忆恢复,否则存当前值置 0。
  Future<void> _toggleMute() async {
    final current = await widget.readVolume();
    if (current == null) return;
    if (current > 0) {
      _rememberedVolume = current.clamp(0.0, 1.0).toDouble();
      await widget.writeVolume(0);
      return;
    }
    final restore = (_rememberedVolume ?? widget.restoreFallbackVolume).clamp(0.0, 1.0).toDouble();
    await widget.writeVolume(restore);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // includeRepeats: false —— 长按不重复触发(对齐既有包装的 Esc 写法)。
        const SingleActivator(LogicalKeyboardKey.keyM, includeRepeats: false): () {
          unawaited(_toggleMute());
        },
        if (widget.onToggleFullScreen != null)
          const SingleActivator(LogicalKeyboardKey.keyF, includeRepeats: false): () {
            widget.onToggleFullScreen!();
          },
        if (widget.onToggleWindowFullScreen != null)
          const SingleActivator(LogicalKeyboardKey.keyW, includeRepeats: false): () {
            widget.onToggleWindowFullScreen!();
          },
      },
      child: FocusScope(autofocus: true, child: widget.child),
    );
  }
}
