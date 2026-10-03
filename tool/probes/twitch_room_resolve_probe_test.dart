// Opt-in 复现探针:twitch 房间解析(siaohu_0124 解析失败)。
// 两条链:干净 login 与完整 URL;无 cookie,不取媒体分段。
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart';

void main() {
  Future<void> probe(String label, String roomIdOrUrl) async {
    try {
      final payload = await PureLiveRoomResolver('twitch')
          .resolveRoom(RoomRequest(site: 'twitch', roomIdOrUrl: roomIdOrUrl));
      // ignore: avoid_print
      print(
        '$label -> ok room=${payload.roomId} title=${payload.title} '
        'live=${payload.roomState} qualities=${payload.availableQualities.length} '
        'streams=${payload.streams.length} category=${payload.category}',
      );
    } catch (error) {
      // ignore: avoid_print
      print('$label -> THROWS $error');
    }
  }

  test('twitch 房间解析:login 与 URL 两种形态', () async {
    await probe('login', 'siaohu_0124');
    await probe('url  ', 'https://www.twitch.tv/siaohu_0124');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
