/// zishu UI → pure_live 播放页桥。
///
/// 用户口径(2026-10-01):流的播放用 pure_live 自己的播放链路。
/// 本桥负责:房间解析(LiveRoom)→ Get.put(LivePlayController) →
/// 内嵌 GetMaterialApp 渲染 LivePlayPage。退出时销毁 controller,
/// zishu 侧无残留。
///
/// 解析经 pure_live `Sites.supportSites`(与 Flutter app 同源),
/// 四家已 sidecar 化站点(bilibili/douyin/huya/douyu)开箱即用。
library;

import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/pages/live_play_page.dart';

/// 解析 → 挂载 LivePlayController → 渲染 LivePlayPage。
class PureLivePlayBridge extends StatefulWidget {
  const PureLivePlayBridge({
    super.key,
    required this.site,
    required this.roomId,
    this.onExit,
  });

  final String site;
  final String roomId;

  /// 桥退出(播放页返回)时的回调,zishu 侧用于恢复浏览页状态。
  final VoidCallback? onExit;

  @override
  State<PureLivePlayBridge> createState() => _PureLivePlayBridgeState();
}

class _PureLivePlayBridgeState extends State<PureLivePlayBridge> {
  LiveRoom? room;
  String? error;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    // 内嵌 GetMaterialApp 弹出后路由回到 zishu 侧;此处兜底销毁 GetX 注册,
    // 避免下次进房拿到旧 controller 实例。
    if (Get.isRegistered<LivePlayController>()) {
      Get.delete<LivePlayController>();
    }
    widget.onExit?.call();
    super.dispose();
  }

  Future<void> _resolve() async {
    try {
      final site = Sites.supportSites
          .firstWhere((s) => s.id == widget.site, orElse: () => throw StateError('未支持的站点 ${widget.site}'));
      final detail = await site.liveSite.getRoomDetail(
        platform: widget.site,
        roomId: widget.roomId,
      );
      if (mounted) setState(() => room = detail);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _scaffold(error!);
    }
    final room = this.room;
    if (room == null) {
      return _scaffold('正在获取房间信息…');
    }
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          // controller 挂到 GetX 全局注册表,LivePlayPage(GetView)直接 find;
          // 路由退出时销毁,避免下次进房拿到旧实例。
          if (!Get.isRegistered<LivePlayController>()) {
            Get.put(LivePlayController(room: room, site: widget.site));
          }
          return LivePlayPage();
        },
      ),
    );
  }

  Widget _scaffold(String text) {
    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onExit,
              child: const Text('返回', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
