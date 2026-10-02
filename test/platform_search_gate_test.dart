// 迭代18:搜索平台门槛以 purelive 注册表能力为准单测。
//
// 搜索入口不受 brand.browseSupported(栏目浏览位)裁剪:17live 等无目录站
// 有真搜索+链接直达,按浏览位裁剪会把搜索入口整块藏掉(用户报告
// `https://17.live/en/live/29725277` 无法解析的根因)。
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/src/shared/presentation/platform_brands.dart';

class _StubSearchRepository implements SearchRepository {
  const _StubSearchRepository();

  @override
  Future<SearchResult> search(SearchRequest request) async =>
      const SearchResult(site: 'stub', hits: []);
}

class _StubBrowseRepository implements BrowseRepository {
  const _StubBrowseRepository();

  @override
  Future<CategoryResult> fetchCategories(String site) async =>
      const CategoryResult(site: 'stub', groups: []);

  @override
  Future<RoomListResult> fetchRooms(RoomListRequest request) async =>
      const RoomListResult(rooms: [], page: 1, hasMore: false);
}

SiteRegistration _registration({
  required String id,
  bool search = false,
  bool browse = false,
}) {
  return SiteRegistration(
    id: id,
    name: id,
    capabilities: SiteCapabilities(browse: browse, roomSearch: search),
    resolver: _StubResolver(),
    browse: browse ? const _StubBrowseRepository() : null,
    search: search ? const _StubSearchRepository() : null,
  );
}

class _StubResolver implements RoomResolver {
  @override
  Future<RoomPayload> resolveRoom(RoomRequest request) async {
    throw UnimplementedError();
  }
}

void main() {
  final registry = SiteRegistry()
    ..register(_registration(id: '17live', search: true))
    ..register(_registration(id: 'douyu', browse: true, search: true));

  test('搜索入口不要求 browseSupported:无目录但有搜索的站保留', () {
    final platforms = PlatformBrandCatalog.filterPlatforms(
      registry: registry,
      realParser: true,
      requireBrowseSupport: false,
      supported: (registration) =>
          registration.capabilities.roomSearch && registration.search != null,
    );
    final ids = platforms.map((brand) => brand.id).toSet();
    expect(ids, containsAll(['all', '17live', 'douyu']));
  });

  test('浏览入口仍要求 browseSupported:无目录站不进分类入口', () {
    final platforms = PlatformBrandCatalog.filterPlatforms(
      registry: registry,
      realParser: true,
      requireBrowseSupport: true,
      supported: (registration) =>
          registration.capabilities.browse && registration.browse != null,
    );
    final ids = platforms.map((brand) => brand.id).toSet();
    expect(ids, isNot(contains('17live')), reason: '17live 品牌位 browseSupported=false,即使注册表有 browse 也不进分类入口');
    expect(ids, contains('douyu'));
  });

  test('fixture 模式保留全量目录', () {
    final platforms = PlatformBrandCatalog.filterPlatforms(
      registry: SiteRegistry(),
      realParser: false,
      requireBrowseSupport: true,
      supported: (_) => false,
    );
    expect(platforms.length, PlatformBrandCatalog.navPlatforms.length);
  });
}
