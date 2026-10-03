// Opt-in 复现探针:youtube/liveme 首页 feed(用户报告「首页无」)。
// 经 buildRegistryWithPureLive 的注册表链路(与应用同路径)。
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/src/shared/application/purelive_backend.dart';
import 'package:pure_live/src/shared/application/providers.dart';

void main() {
  test('youtube/liveme 首页 feed(注册表链路)', () async {
    final registry = buildRegistryWithPureLive();
    for (final site in ['youtube', 'liveme']) {
      final browse = registry.byId(site)?.browse;
      if (browse == null) {
        // ignore: avoid_print
        print('$site -> NO BROWSE REPOSITORY');
        continue;
      }
      try {
        final rooms = await browse.fetchRooms(RoomListRequest(site: site, page: 1, limit: 12));
        // ignore: avoid_print
        print(
          '$site recommend(${browse.runtimeType}) -> ${rooms.rooms.length} rooms hasMore=${rooms.hasMore} '
          'first=${rooms.rooms.isEmpty ? '-' : '${rooms.rooms.first.roomId}/${rooms.rooms.first.anchorName}'}',
        );
      } catch (error) {
        // ignore: avoid_print
        print('$site recommend -> THROWS $error');
      }
      try {
        final categories = await browse.fetchCategories(site);
        // ignore: avoid_print
        print(
          '$site categories -> ${categories.groups.length} groups '
          '${[for (final g in categories.groups) '${g.name}:${g.items.length}']}',
        );
      } catch (error) {
        // ignore: avoid_print
        print('$site categories -> THROWS $error');
      }
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
