import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart';
import 'package:pure_live/src/features/play/application/play_selection.dart';

RoomPayload _payload({required List<StreamQuality> streams, required List<String> options}) {
  return RoomPayload(
    site: 'test',
    roomId: '1',
    sourceUrl: '',
    anchorName: 'anchor',
    title: 'title',
    cover: '',
    avatar: '',
    category: '',
    cid: '',
    roomState: RoomState.live,
    streams: streams,
    availableQualities: [for (final name in options) QualityOption(name: name, rate: 0)],
    source: 'test',
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

StreamQuality _quality(String name, {int lines = 1}) {
  return StreamQuality(
    name: name,
    rate: 0,
    lines: [
      for (var i = 0; i < lines; i++)
        StreamLine(name: '线路${i + 1}', format: 'hls', url: 'https://example.com/$name/$i.m3u8'),
    ],
  );
}

void main() {
  group('pendingPrefetchQualities(预取待补档位)', () {
    test('懒取流下只缺非进房档:进房档跳过,其余按菜单顺序入队', () {
      final payload = _payload(streams: [_quality('原画')], options: ['原画', '蓝光', '高清', '标清']);
      expect([for (final option in pendingPrefetchQualities(payload, {})) option.name], ['蓝光', '高清', '标清']);
    });

    test('qualityByName 回退陷阱回归:未命中档不得借首档线路冒充已解析', () {
      // qualityByName('蓝光') 会回退返回「原画」(有线路);精确同名判定必须
      // 仍然把「蓝光」入队,否则预取队列恒空。
      final payload = _payload(streams: [_quality('原画')], options: ['原画', '蓝光']);
      expect([for (final option in pendingPrefetchQualities(payload, {})) option.name], ['蓝光']);
    });

    test('同名占位档(lines 为空)不算已解析,照常入队', () {
      final payload = _payload(streams: [_quality('原画'), _quality('蓝光', lines: 0)], options: ['原画', '蓝光']);
      expect([for (final option in pendingPrefetchQualities(payload, {})) option.name], ['蓝光']);
    });

    test('预取缓存命中且带线路的档不再入队', () {
      final payload = _payload(streams: [_quality('原画')], options: ['原画', '蓝光', '高清']);
      final prefetched = {'蓝光': _quality('蓝光')};
      expect([for (final option in pendingPrefetchQualities(payload, prefetched)) option.name], ['高清']);
    });

    test('全部档一次带齐的平台(Twitch/YouTube 类)队列为空', () {
      final payload = _payload(streams: [_quality('原画'), _quality('高清')], options: ['原画', '高清']);
      expect(pendingPrefetchQualities(payload, {}), isEmpty);
    });
  });

  group('mergeResolvedStream(预取档并回流集合)', () {
    test('新档名追加到末尾,streams.first(默认档回退锚点)不变', () {
      final merged = mergeResolvedStream([_quality('原画')], _quality('蓝光'));
      expect(merged, hasLength(2));
      expect(merged.first.name, '原画');
      expect(merged.last.name, '蓝光');
    });

    test('同名档替换原位,不产生重复', () {
      final merged = mergeResolvedStream([_quality('原画'), _quality('蓝光', lines: 0)], _quality('蓝光'));
      expect(merged, hasLength(2));
      expect(merged.map((stream) => stream.name), ['原画', '蓝光']);
      expect(merged.last.lines, isNotEmpty);
    });

    test('空流集合(离房刷新窗口)直接落地预取档', () {
      final merged = mergeResolvedStream(const [], _quality('蓝光'));
      expect(merged.single.name, '蓝光');
    });
  });
}
