// Opt-in 复现探针:c: 前缀频道(twitcasting.tv/c:tbk_1)打不开问题。
// 三个断点:1) 直达识别是否漏掉 c: 链接;2) channelName 对裸 URL 的行为;
// 3) 真实网络下 detail('c:tbk_1') 是否可解析。无 cookie,无媒体分段。
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/platforms/twitcasting/twitcasting_api.dart';
import 'package:pure_live/src/features/search/application/search_provider.dart';

void main() {
  test('直达识别:c: 前缀频道根 URL', () {
    final direct = resolveSearchDirect('twitcasting', 'https://twitcasting.tv/c:tbk_1');
    // ignore: avoid_print
    print('direct=$direct');
  });

  test('channelName:URL 与 c: 裸名', () {
    for (final input in ['https://twitcasting.tv/c:tbk_1', 'c:tbk_1', 'tbk_1']) {
      try {
        // ignore: avoid_print
        print('$input -> ${TwitcastingApi.channelName(input)}');
      } catch (error) {
        // ignore: avoid_print
        print('$input -> THROWS $error');
      }
    }
  });

  test('真实网络:detail(c:tbk_1)', () async {
    final room = await TwitcastingApi().detail('c:tbk_1', includeMedia: false);
    // ignore: avoid_print
    print('room=${room.roomId} title=${room.title} live=${room.status} nick=${room.nick}');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
