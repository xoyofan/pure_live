import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/missevan/missevan_api.dart';

/// 2026-10 灰度改版后的真实 `meta/data` 骨架:`tabs` 沦为纯展示键(无 type/id),
/// 可过滤的分类 id 在 `catalogs[]`;sub_catalogs 的 id 实测过滤 chatroom/open/list
/// 恒空,适配器必须只暴露顶层目录。
Map<String, dynamic> _metaBody() => {
  'code': 0,
  'info': {
    'compatible': true,
    'live_url': '/live/',
    // 旧 schema 残留的展示键:解析器必须忽略而不是拿它当分类。
    'tabs': [
      {'name': '配音', 'color': '#D68DFE', 'icon_url': 'https://static.maoercdn.com/live/catalog/icon/105.png'},
      {'name': '团播', 'icon_url': 'https://static.maoercdn.com/live/catalog/icon/tuanbo.png'},
    ],
    'catalogs': [
      {
        'catalog_id': 105,
        'catalog_name': '配音',
        'color': '#D68DFE',
        'icon_url': 'https://static.maoercdn.com/live/catalog/icon/105.png',
        'sub_catalogs': [
          {'catalog_id': 167, 'catalog_name': 'pia戏', 'catalog_attr': 1},
          {'catalog_id': 149, 'catalog_name': '配音'},
        ],
      },
      {
        'catalog_id': 104,
        'catalog_name': '音乐',
        'icon_url': '//static.maoercdn.com/live/catalog/icon/104.png',
        'sub_catalogs': <Object>[],
      },
      {'catalog_id': 116, 'catalog_name': '情感', 'icon_url': 'https://static.maoercdn.com/live/catalog/icon/116.png'},
    ],
    'custom_tag_groups': [
      {
        'tag_group_id': 1,
        'tag_group_name': '人设',
        'tags': [
          {'tag_id': 10001, 'tag_name': '高冷禁欲'},
        ],
      },
    ],
  },
};

MissevanApi _api(Object? body, {int status = 200}) {
  return MissevanApi(request: (uri, cancel) async => (status: status, body: body is String ? body : jsonEncode(body)));
}

void main() {
  test('categories maps top-level catalogs and ignores display tabs/sub ids', () async {
    final areas = await _api(_metaBody()).categories();
    expect(areas.map((a) => a.areaId).toList(), ['105', '104', '116']);
    expect(areas.map((a) => a.areaName).toList(), ['配音', '音乐', '情感']);
    expect(areas.every((a) => a.areaType == 'catalog'), isTrue, reason: 'directoryPage 只接受 catalog/tag 过滤');
    expect(areas.every((a) => a.platform == 'missevan'), isTrue);
    expect(areas.first.areaPic, 'https://static.maoercdn.com/live/catalog/icon/105.png');
    // 协议相对地址补全。
    expect(areas[1].areaPic, 'https://static.maoercdn.com/live/catalog/icon/104.png');
  });

  test('categories rejects the legacy tabs-only schema and malformed rows', () async {
    expect(
      () => _api({
        'code': 0,
        'info': {
          'tabs': [
            {'type': 'catalog', 'catalog_id': 105, 'name': '配音'},
          ],
        },
      }).categories(),
      throwsA(predicate((e) => e is MissevanException && e.kind == MissevanFailure.schema)),
    );
    expect(
      () => _api({
        'code': 0,
        'info': {
          'catalogs': [
            {'catalog_id': 0, 'catalog_name': '坏行'},
          ],
        },
      }).categories(),
      throwsA(predicate((e) => e is MissevanException && e.kind == MissevanFailure.schema)),
    );
    expect(
      () => _api({
        'code': 0,
        'info': {
          'catalogs': [
            {'catalog_id': 105, 'catalog_name': '配音'},
            {'catalog_id': 105, 'catalog_name': '重复'},
          ],
        },
      }).categories(),
      throwsA(predicate((e) => e is MissevanException && e.kind == MissevanFailure.schema)),
    );
  });

  test('categories propagates service failures instead of inventing a catalog', () async {
    expect(
      () => _api({'code': 1, 'info': <String, Object>{}}, status: 200).categories(),
      throwsA(predicate((e) => e is MissevanException && e.kind == MissevanFailure.service)),
    );
  });
}
