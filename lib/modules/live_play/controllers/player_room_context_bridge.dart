import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_room_context.dart';

import 'player_controller.dart';

/// Installs the playback controller's current room as the parsers' fallback
/// source. This is the only place where resolution may observe playback UI
/// state; the adapters themselves stay controller-free.
class PlayerRoomContextBridge implements LiveCurrentRoomProvider {
  const PlayerRoomContextBridge();

  @override
  LiveRoom? currentRoomMatching({required String platform, required String roomId}) {
    if (!Get.isRegistered<PlayerController>()) return null;
    final current = Get.find<PlayerController>().currentRoom;
    if (current?.hasIdentity(platform: platform, roomId: roomId) == true) return current;
    return null;
  }
}
