/// zishu 运行时的 ParserConfig 注入(下游补充字段)。
///
/// 旧 UI 经 `bindParserRuntimeToApp` 把 GetX CookieManager 接进解析核心;
/// zishu(riverpod)不初始化 GetX, `ParserConfig.instance` 为 null →
/// pure_live 适配器全部匿名(Cookie 缺失, B 站分类房间 -352 风控即此)。
/// 本实现持有按平台 id 的 Cookie 表, 由 providers 层在凭证变化时更新。
///
/// 用户口径(2026-10-03): 解析相关以 purelive 为准, 本类只做宿主注入,
/// 不含任何站点解析逻辑。
library;

import 'package:pure_live/core/network/parser_config.dart';

class ZishuParserConfig implements ParserConfig {
  ZishuParserConfig(this.cookieBySite);

  /// 平台 id(SiteIds 值, 如 bilibili/douyu) → Cookie 整串。
  final Map<String, String> cookieBySite;

  @override
  String cookieFor(String platform) => cookieBySite[platform] ?? '';

  @override
  String persistentCookieFor(String platform) => cookieFor(platform);

  @override
  Object? auxiliaryFor(String platform, String key) => null;
}
