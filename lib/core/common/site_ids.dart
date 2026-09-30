/// Platform identity constants shared by the app registry and the pure-Dart
/// parsing core (sidecar). Kept free of any Flutter/GetX import so
/// `dart compile exe` can build the sidecar from the same sources.
abstract final class SiteIds {
  static const String weiboSite = 'weibo';
  static const String niconicoSite = 'niconico';
  static const String allSite = "all";
  static const String bilibiliSite = "bilibili";
  static const String douyuSite = "douyu";
  static const String huyaSite = "huya";
  static const String douyinSite = "douyin";
  static const String kuaishouSite = "kuaishou";
  static const String ccSite = "cc";
  static const String iptvSite = "iptv";
  static const String twitchSite = "twitch";
  static const String soopSite = 'soop';
  static const String yySite = 'yy';
  static const String acfunSite = 'acfun';
  static const String picartoSite = 'picarto';
  static const String twitcastingSite = 'twitcasting';
  static const String missevanSite = 'missevan';
  static const String inkeSite = 'inke';
  static const String kilakilaSite = 'kilakila';
  static const String xiaohongshuSite = 'xiaohongshu';
  static const String showroomSite = 'showroom';
  static const String chzzkSite = 'chzzk';
  static const String liveMeSite = 'liveme';
  static const String tiktokSite = 'tiktok';
  static const String youtubeSite = 'youtube';
  static const String bigoSite = 'bigo';
  static const String pandaLiveSite = 'pandalive';
  static const String fc2LiveSite = 'fc2live';
  static const String steamBroadcastSite = 'steambroadcast';
  static const String jdLiveSite = 'jdlive';
  static const String kugouLiveSite = 'kugoulive';
  static const String baiduLiveSite = 'baidulive';
  static const String sixRoomSite = 'sixroom';
  static const String lookLiveSite = 'looklive';
  static const String seventeenLiveSite = '17live';

  static const Set<String> supportedSiteIds = {
    weiboSite,
    niconicoSite,
    bilibiliSite,
    douyuSite,
    huyaSite,
    douyinSite,
    kuaishouSite,
    ccSite,
    twitchSite,
    soopSite,
    yySite,
    acfunSite,
    picartoSite,
    twitcastingSite,
    missevanSite,
    inkeSite,
    kilakilaSite,
    xiaohongshuSite,
    showroomSite,
    chzzkSite,
    liveMeSite,
    tiktokSite,
    youtubeSite,
    bigoSite,
    pandaLiveSite,
    fc2LiveSite,
    steamBroadcastSite,
    jdLiveSite,
    kugouLiveSite,
    baiduLiveSite,
    sixRoomSite,
    lookLiveSite,
    seventeenLiveSite,
    iptvSite,
  };
}
