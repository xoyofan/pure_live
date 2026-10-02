/// purelive 桥接层线路格式判定。
///
/// 独立于 purelive_backend(其 import 全站总表 sites.dart)以便单测
/// 单独编译,不连带未收敛的站点实现。
library;

/// 线路格式判定:按 URI path 后缀与 scheme,而非整个 URL 的字符串后缀。
///
/// 签名直链(猫耳/Twitcasting/虎牙 HLS 均带 `?sign=…` query)以 `.m3u8?…`
/// 结尾,整串 `endsWith('.m3u8')` 恒为 false,导致 HLS 线被误判成 flv、
/// 被包进 FLV 专用本地流代理(m3u8 文本被当 FLV、分片请求拼到本地地址
/// 404,房间必然起播失败,2026-10-02 猫耳全档日志确证)。RTMP 直链同样
/// 不是 FLV 持续流,单独归类使代理护栏(`format != 'flv'` 直连)天然放行。
String pureLiveLineFormat(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && (uri.scheme == 'rtmp' || uri.scheme == 'rtmps')) return 'rtmp';
  final path = uri?.path ?? url;
  return path.toLowerCase().endsWith('.m3u8') ? 'hls' : 'flv';
}
