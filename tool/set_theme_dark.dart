// 本机维护工具:把便携数据目录里已持久化的主题模式一次性切到 Dark。
//
// 背景:R11 起默认主题改为深色(对齐 zishu 深色优先),但 Hive 里已写入
// 'System' 的存量数据不会跟着默认值变。深色渲染对照、或用户希望直接
// 获得深色时,关掉应用后运行本工具翻转存量值:
//
//   dart run tool/set_theme_dark.dart [appDataRoot]
//
// appDataRoot 缺省取构建输出目录 build/windows/x64/runner/Release/AppData;
// 也可传任意便携数据根(含 HIVE_DB 子目录)。只改 themeMode 一个键,
// 其余设置原样保留;已为 Dark 时是幂等空操作。
import 'dart:io';

import 'package:hive_ce/hive.dart';

Future<void> main(List<String> argv) async {
  final root = argv.isNotEmpty
      ? argv[0]
      : Uri.file(Directory.current.path + r'\build\windows\x64\runner\Release\AppData').toFilePath();
  final hiveDir = Directory('$root\\HIVE_DB');
  if (!hiveDir.existsSync()) {
    stderr.writeln('未找到 $hiveDir,确认应用数据根路径。');
    exitCode = 1;
    return;
  }
  Hive.init(hiveDir.path);
  final box = await Hive.openBox<dynamic>('app_settings');
  final current = box.get('themeMode');
  if (current == 'Dark') {
    stdout.writeln('themeMode 已是 Dark,无需修改。');
    await box.close();
    return;
  }
  await box.put('themeMode', 'Dark');
  await box.close();
  stdout.writeln('themeMode: $current -> Dark (box=app_settings)');
}
