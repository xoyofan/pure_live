// 本机数据迁移工具:把 zishu_flutter 的用户数据导入本应用(一次性)。
//
// 数据源(只读):zishu 的 shared_preferences.json ——
//   %APPDATA%/com.example/zishu_flutter/shared_preferences.json
// 导入项:
//   1. zishu.follow.list(关注列表)→ Hive 盒 'app_settings' 键 'favoriteRooms'
//      ({'list': [LiveRoom.toJson 兼容映射]}),按 platform+roomId 去重合并;
//   2. zishu.credentials.douyin(登录态抖音 cookie)→ 键 'douyinCookie';
//   3. zishu.myCategories.v3(我的分类)→ 键 'zishu_app.myCategories.v1'
//      (jsonEncode 的 [{site,name}]),按 site+name 去重合并。
//
// 用法(先关闭应用,防止 Hive 锁):
//   dart run tool/import_zishu_data.dart [zishuPrefsJson] [appDataRoot]
// 参数缺省分别取上面两个默认路径(appDataRoot = build/windows/x64/runner/Release/AppData)。
import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';

const _supportedSites = {
  'bilibili', 'douyu', 'huya', 'douyin', 'kuaishou', 'twitch', 'soop', 'yy', 'youtube',
};

Future<void> main(List<String> argv) async {
  final prefsPath = argv.isNotEmpty
      ? argv[0]
      : Platform.environment['APPDATA']! + r'\com.example\zishu_flutter\shared_preferences.json';
  final appDataRoot = argv.length > 1
      ? argv[1]
      : Directory.current.path + r'\build\windows\x64\runner\Release\AppData';

  final prefsFile = File(prefsPath);
  if (!prefsFile.existsSync()) {
    stderr.writeln('找不到 zishu 偏好文件: $prefsPath');
    exitCode = 1;
    return;
  }
  final hiveDir = Directory('$appDataRoot\\HIVE_DB');
  if (!hiveDir.existsSync()) {
    stderr.writeln('找不到应用 Hive 目录: $hiveDir');
    exitCode = 1;
    return;
  }

  final prefs = json.decode(prefsFile.readAsStringSync()) as Map<String, dynamic>;

  // ---- 1. 关注列表 ----
  final followsRaw = prefs['zishu.follow.list'];
  final follows = (followsRaw is String ? json.decode(followsRaw) : followsRaw) as List<dynamic>;
  Hive.init(hiveDir.path);
  final box = await Hive.openBox<dynamic>('app_settings');

  final existingRaw = box.get('favoriteRooms');
  var existing = <Map<String, dynamic>>[];
  if (existingRaw is Map && existingRaw['list'] is List) {
    existing = List<Map<String, dynamic>>.from(
      (existingRaw['list'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }
  final seen = <String>{
    for (final room in existing) '${room['platform']}|${room['roomId']}',
  };
  var imported = 0;
  var skippedSite = 0;
  for (final raw in follows) {
    final z = Map<String, dynamic>.from(raw as Map);
    final site = (z['site'] ?? '').toString();
    final roomId = (z['roomId'] ?? '').toString();
    if (site.isEmpty || roomId.isEmpty) continue;
    if (!_supportedSites.contains(site)) {
      skippedSite++;
      continue;
    }
    if (seen.contains('$site|$roomId')) continue;
    seen.add('$site|$roomId');
    existing.add({
      'roomId': roomId,
      'userId': '',
      'title': (z['title'] ?? '').toString(),
      'nick': (z['uname'] ?? '').toString(),
      'avatar': (z['avatar'] ?? '').toString(),
      'cover': (z['cover'] ?? '').toString(),
      'area': (z['category'] ?? '').toString(),
      'typeName': (z['category'] ?? '').toString(),
      'watching': (z['online'] ?? '0').toString(),
      'followers': (z['followers'] ?? '0').toString(),
      'platform': site,
      'status': z['roomState'] == 'live',
    });
    imported++;
  }
  await box.put('favoriteRooms', {'list': existing});

  // ---- 2. 抖音登录 cookie ----
  var cookieLen = 0;
  final douyinCredRaw = prefs['zishu.credentials.douyin'];
  if (douyinCredRaw != null) {
    final cred = douyinCredRaw is String ? json.decode(douyinCredRaw) : douyinCredRaw;
    final value = ((cred as Map)['value'] ?? '').toString();
    if (value.isNotEmpty) {
      await box.put('douyinCookie', value);
      cookieLen = value.length;
    }
  }

  // ---- 3. 我的分类 ----
  var catImported = 0;
  final catsRaw = prefs['zishu.myCategories.v3'];
  if (catsRaw != null) {
    final cats = (catsRaw is String ? json.decode(catsRaw) : catsRaw) as List<dynamic>;
    final current = <Map<String, dynamic>>[];
    final stored = box.get('zishu_app.myCategories.v1');
    if (stored is String && stored.isNotEmpty) {
      current.addAll(
        (json.decode(stored) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    final catSeen = <String>{
      for (final c in current) '${c['site']}|${c['name']}',
    };
    for (final raw in cats) {
      final z = Map<String, dynamic>.from(raw as Map);
      final site = (z['site'] ?? '').toString();
      final name = (z['name'] ?? '').toString();
      if (site.isEmpty || name.isEmpty || catSeen.contains('$site|$name')) continue;
      catSeen.add('$site|$name');
      current.add({'site': site, 'name': name});
      catImported++;
    }
    await box.put('zishu_app.myCategories.v1', jsonEncode(current));
  }

  await box.close();
  stdout
    ..writeln('关注列表: zishu ${follows.length} 条, 新导入 $imported, 不支持平台跳过 $skippedSite, 合并后共 ${existing.length} 条')
    ..writeln('抖音 cookie: ${cookieLen > 0 ? '已导入($cookieLen 字符)' : '未找到/为空'}')
    ..writeln('我的分类: 新导入 $catImported 条');
}
