/// Runtime configuration injected by the host (Flutter app or sidecar).
///
/// The parsing core must never reach for global UI state (GetX
/// SettingsService): the sidecar build (`dart compile exe`) has no such
/// registry, and the app keeps owning user preferences. Hosts register an
/// implementation at startup; when nothing is registered the parsing core
/// behaves as an anonymous client.
abstract interface class ParserConfig {
  static ParserConfig? instance;

  /// Stored login cookie for [platform] (SiteIds value), '' when none.
  String cookieFor(String platform);

  /// Login cookie cache the site may reuse across requests ('' when none).
  /// Optional: hosts without persistence return what cookieFor returns.
  String persistentCookieFor(String platform) => cookieFor(platform);

  /// Extra stored settings a site needs beyond cookies (e.g. bilibiliUid).
  /// Returns null when the host has nothing stored for [key].
  Object? auxiliaryFor(String platform, String key) => null;
}
