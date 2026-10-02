import 'package:pure_live/core/models/live_room.dart';

/// UI-owned "current room" handed to parsers as a metadata fallback only.
///
/// Platform adapters may consult this when a room request fails or omits
/// fields the player already knows. Parsers must reach it through this
/// contract; importing playback controllers from `lib/modules` is forbidden
/// so the whole resolution layer stays replaceable by a native/remote core.
abstract interface class LiveCurrentRoomProvider {
  /// Returns the UI-current room when it matches the requested identity,
  /// otherwise null. Implementations must stay cheap and synchronous.
  LiveRoom? currentRoomMatching({required String platform, required String roomId});
}

/// Holder for the registered [LiveCurrentRoomProvider].
///
/// The UI layer installs a bridge during app initialization; when nothing is
/// installed the adapters degrade to their offline fallback exactly as if no
/// player were open.
abstract final class LiveCurrentRoomContext {
  static LiveCurrentRoomProvider? _provider;

  static LiveCurrentRoomProvider? get provider => _provider;

  static void register(LiveCurrentRoomProvider? value) {
    _provider = value;
  }
}
