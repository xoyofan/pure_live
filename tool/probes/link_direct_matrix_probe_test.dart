// Opt-in 复现探针:三个失败链接(bigo/chzzk/twitcasting)直达识别 + 解析链。
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/core/network/web_search_room_parser.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart';

void main() {
  test('三链接:解析器识别 + 解析链', () async {
    const urls = <String, String>{
      'bigo': 'https://www.bigo.tv/cn/1081931220',
      'chzzk': 'https://chzzk.naver.com/live/7c142828b058c160e125d370e2c6c80f',
      'twitcasting': 'https://twitcasting.tv/_ll44n',
    };
    for (final entry in urls.entries) {
      final parsed = WebSearchRoomParser.parse(entry.value);
      // ignore: avoid_print
      print('${entry.key} parse -> ${parsed == null ? 'NULL(不识别)' : '${parsed.platform}:${parsed.roomId}'}');
      if (parsed == null) continue;
      try {
        final payload = await PureLiveRoomResolver(parsed.platform).resolveRoom(
          RoomRequest(site: parsed.platform, roomIdOrUrl: parsed.roomId),
        );
        // ignore: avoid_print
        print(
          '${entry.key} resolve -> room=${payload.roomId} live=${payload.roomState} '
          'qualities=${payload.availableQualities.length} streams=${payload.streams.length} title=${payload.title}',
        );
      } catch (error) {
        // ignore: avoid_print
        print('${entry.key} resolve -> THROWS $error');
      }
    }
  }, timeout: const Timeout(Duration(seconds: 180)));
}
