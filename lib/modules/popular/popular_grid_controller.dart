import 'package:pure_live/common/index.dart';

/// Applies the same audience policy used by favourites, search and room
/// pickers to a platform's popular list. Server recommendation order is still
/// useful as the fetched candidate pool, but every visible page is normalized
/// to descending values so adapters cannot silently drift to a different
/// field or return an unstable order.
List<LiveRoom> rankPopularRoomsByAudience(
  Iterable<LiveRoom> rooms, {
  required bool preferRealOnline,
  required Iterable<String> realOnlinePlatforms,
}) {
  final enabledPlatforms = realOnlinePlatforms.map((platform) => platform.trim().toLowerCase()).toSet();
  final ranked = rooms.toList(growable: false);
  ranked.sort(
    (left, right) => LiveRoom.compareAudienceRanking(
      left,
      right,
      preferRealOnline: preferRealOnline,
      platformEnabled: (platform) => enabledPlatforms.contains(platform?.trim().toLowerCase()),
    ),
  );
  return ranked;
}

List<LiveRoom> _rankForCurrentSettings(List<LiveRoom> rooms) {
  final app = SettingsService.to.app;
  return rankPopularRoomsByAudience(
    rooms,
    preferRealOnline: app.preferRealOnlineCounts.v,
    realOnlinePlatforms: app.realOnlinePlatforms,
  );
}

class PopularLocalReactiveController extends LocalReactivePageController<LiveRoom> {
  final Site site;
  PopularLocalReactiveController(this.site) {
    onExternalRefresh = () async {
      final rooms = await getLocalRawData();
      if (isClosed) return;
      updateLocalReactivePool(rooms);
    };
  }

  @override
  Future<void> loadData({int? limit}) => loadExternalSnapshot();

  Future<List<LiveRoom>> getLocalRawData() async {
    if (isClosed) return [];
    // 首屏容量(真源 88b4512):首页快照拉取取「分页口径与容量较大者」。
    final firstScreenLimit = lastFirstScreenLimit;
    final requestSize = firstScreenLimit != null && firstScreenLimit > pageSize.value
        ? firstScreenLimit
        : pageSize.value;
    final rooms = await site.liveSite.getRecommendRooms(page: 1, pageSize: requestSize);
    if (isClosed) return [];
    return site.id == Sites.iptvSite ? rooms : _rankForCurrentSettings(rooms);
  }

  Future<List<LiveRoom>> refreshNetworkStatus(List<LiveRoom> currentPool, int page, int pageSize) async {
    try {
      final rooms = await site.liveSite.getRecommendRooms(page: page, pageSize: pageSize);
      return site.id == Sites.iptvSite ? rooms : _rankForCurrentSettings(rooms);
    } catch (e) {
      if (e.toString().contains("NoSuchMethodError") && e.toString().contains("'[]'")) {
        throw Exception("loginRequired");
      }
      rethrow;
    }
  }
}

class PopularServerAllController extends ServerAllPageController<LiveRoom> {
  final Site site;
  PopularServerAllController(this.site);

  @override
  Future<List<LiveRoom>> fetchAllServerData() async {
    if (isClosed) return [];
    // 首屏容量(真源 88b4512):仅第 1 页生效,取「分页口径与容量较大者」。
    final firstScreenLimit = lastFirstScreenLimit;
    final requestSize = currentPage == 1 && firstScreenLimit != null && firstScreenLimit > pageSize.value
        ? firstScreenLimit
        : pageSize.value;
    final rooms = await site.liveSite.getRecommendRooms(page: currentPage, pageSize: requestSize);
    if (isClosed) return [];
    return _rankForCurrentSettings(rooms);
  }
}

class PopularServerFixedController extends ServerFixedPageController<LiveRoom> {
  final Site site;

  PopularServerFixedController(this.site, {required int fixedSize}) : super(fixedServerPageSize: fixedSize);

  @override
  Future<List<LiveRoom>> fetchFixedNetworkData(int bigPage, int fixedSize) async {
    if (isClosed) return [];
    // 首屏容量(真源 88b4512):仅客户端第 1 页的首个大页生效(容量大于
    // fixed 窗时按容量请求,首页 refresh 同容量;容量小于 fixed 窗维持原
    // 请求量,防首屏不足一窗把 canLoadMore 判假)。douyin feed 侧再把
    // 该值夹取 1..60 落到 custom_count。
    final firstScreenLimit = lastFirstScreenLimit;
    final requestSize = bigPage == 1 && currentPage == 1 && firstScreenLimit != null && firstScreenLimit > fixedSize
        ? firstScreenLimit
        : fixedSize;
    final rooms = await site.liveSite.getRecommendRooms(page: bigPage, pageSize: requestSize);
    if (isClosed) return [];
    return _rankForCurrentSettings(rooms);
  }
}

class PopularServerRemoteController extends ServerRemotePageController<LiveRoom> {
  final Site site;
  PopularServerRemoteController(this.site);

  @override
  Future<List<LiveRoom>> fetchNetworkData(int page, int pageSize) async {
    if (isClosed) return [];
    final rooms = await site.liveSite.getRecommendRooms(page: page, pageSize: pageSize);
    if (isClosed) return [];
    return _rankForCurrentSettings(rooms);
  }
}
