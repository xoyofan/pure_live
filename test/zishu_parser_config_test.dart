// 迭代28:zishu 运行时 ParserConfig 注入单测。
//
// 旧 UI 的 bindParserRuntimeToApp 不在 zishu(riverpod) 运行, 不注入则
// pure_live 适配器匿名 —— B 站分类房间列表 -352 风控即此。注入后适配器
// 经 ParserConfig.instance 拿到用户凭证 Cookie。
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/parser_config.dart';
import 'package:pure_live/core/network/site_ids.dart';
import 'package:pure_live/src/shared/application/zishu_parser_config.dart';

void main() {
  setUp(() {
    ParserConfig.instance = null;
  });

  test('未注入时 instance 为 null(适配器匿名口径)', () {
    expect(ParserConfig.instance, isNull);
  });

  test('注入后按平台 id 取 Cookie', () {
    ParserConfig.instance = ZishuParserConfig({
      SiteIds.bilibiliSite: 'SESSDATA=abc; buvid3=buvid-value;',
      SiteIds.douyinSite: 'ttwid=xyz;',
    });
    final config = ParserConfig.instance!;
    expect(config.cookieFor(SiteIds.bilibiliSite), 'SESSDATA=abc; buvid3=buvid-value;');
    expect(config.cookieFor(SiteIds.douyinSite), 'ttwid=xyz;');
    // 未配置平台回落空串(匿名)。
    expect(config.cookieFor(SiteIds.huyaSite), '');
    // persistentCookieFor 默认同 cookieFor。
    expect(config.persistentCookieFor(SiteIds.bilibiliSite), 'SESSDATA=abc; buvid3=buvid-value;');
    // auxiliaryFor 无存储值返回 null。
    expect(config.auxiliaryFor(SiteIds.bilibiliSite, 'bilibiliUid'), isNull);
  });

  test('凭证更新后重建实例, 适配器下次请求即取新值', () {
    ParserConfig.instance = ZishuParserConfig({SiteIds.bilibiliSite: 'old'});
    expect(ParserConfig.instance!.cookieFor(SiteIds.bilibiliSite), 'old');
    ParserConfig.instance = ZishuParserConfig({SiteIds.bilibiliSite: 'new'});
    expect(ParserConfig.instance!.cookieFor(SiteIds.bilibiliSite), 'new');
  });
}
