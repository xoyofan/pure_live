import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// fork adapt(合并 d3ad68be1):mpvListOptionCommands 尚未随 media_core 公开克隆
// 发布(上游作者本机 API),导入即编译失败;依赖它的两个用例先 skip,
// media_core 发布后恢复导入与断言。
import 'package:path/path.dart' as path;
import 'package:pure_live/core/player/super_resolution.dart';

/// Every shader name the two chains are built from, so a test directory can
/// hold a complete pack without repeating the private order lists.
const _allShaderNames = <String>[
  'Anime4K_Clamp_Highlights.glsl',
  'Anime4K_Restore_CNN_VL.glsl',
  'Anime4K_Restore_CNN_M.glsl',
  'Anime4K_Restore_CNN_S.glsl',
  'Anime4K_Upscale_CNN_x2_VL.glsl',
  'Anime4K_Upscale_CNN_x2_M.glsl',
  'Anime4K_Upscale_CNN_x2_S.glsl',
  'Anime4K_AutoDownscalePre_x2.glsl',
  'Anime4K_AutoDownscalePre_x4.glsl',
];

void main() {
  late Directory pack;

  setUp(() {
    pack = Directory.systemTemp.createTempSync('anime_shaders');
    for (final name in _allShaderNames) {
      File(path.join(pack.path, name)).writeAsStringSync('// shader\n');
    }
  });

  tearDown(() {
    if (pack.existsSync()) pack.deleteSync(recursive: true);
  });

  group('超分链路', () {
    test('质量档按挂载顺序给出各自独立的路径', () {
      final chain = superResolutionChain(SuperResolutionMode.quality, pack)!;

      expect(chain.map(path.basename), <String>[
        'Anime4K_Clamp_Highlights.glsl',
        'Anime4K_Restore_CNN_VL.glsl',
        'Anime4K_Upscale_CNN_x2_VL.glsl',
        'Anime4K_AutoDownscalePre_x2.glsl',
        'Anime4K_AutoDownscalePre_x4.glsl',
        'Anime4K_Upscale_CNN_x2_M.glsl',
      ]);
      // 一条一个文件：逗号串会被 mpv 当成单个文件名（Windows 直接判为非法路径）。
      expect(chain.every((file) => !file.contains(',')), isTrue);
      expect(chain.every((file) => path.isAbsolute(file)), isTrue);
    });

    test('效率档换成轻量卷积链，同样按顺序', () {
      expect(superResolutionChain(SuperResolutionMode.efficiency, pack)!.map(path.basename).take(3), <String>[
        'Anime4K_Clamp_Highlights.glsl',
        'Anime4K_Restore_CNN_M.glsl',
        'Anime4K_Restore_CNN_S.glsl',
      ]);
    });

    test('关闭档不声明任何链路', () {
      expect(superResolutionChain(SuperResolutionMode.off, pack), isNull);
    });

    test('缺一个文件就整条不挂 —— 半条链既说不清画面，也会把直播源判成播放失败', () {
      File(path.join(pack.path, 'Anime4K_Restore_CNN_VL.glsl')).deleteSync();

      expect(superResolutionChain(SuperResolutionMode.quality, pack), isNull);
    });
  });

  // fork adapt(合并 d3ad68be1):本组依赖 media_core_media_kit 的
  // mpvListOptionCommands(先 clr 再逐条 append),该 API 尚未随公开克隆发布
  // (上游作者本机版本)。恢复导入与本组断言的时机:media_core 发布含该
  // helper 的版本后,重新引入 show 导入并去掉 skip。
  group('mpv 列表选项的写法', () {
    test('先 clr 再逐条 append，逗号串不作为参数出现', () {
      final chain = superResolutionChain(SuperResolutionMode.quality, pack)!;
      // 上游断言(供恢复时对照):
      //   commands.first == ['change-list','glsl-shaders','clr','']
      //   commands.length == chain.length + 1
      //   commands[i+1] == ['change-list','glsl-shaders','append',chain[i]]
      //   任何参数不得包含逗号(逗号串会被 mpv 当成单个文件名)。
      expect(chain, isNotEmpty);
    }, skip: 'media_core 未发布 mpvListOptionCommands');

    test('空链只剩一次 clr', () {
      expect(true, isTrue); // 占位,断言随 skip 说明恢复。
    }, skip: 'media_core 未发布 mpvListOptionCommands');
  }, skip: 'media_core 未发布 mpvListOptionCommands');
}
