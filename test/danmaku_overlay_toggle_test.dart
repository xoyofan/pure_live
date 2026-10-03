/// 弹幕叠加层总开关语义(2026-10-03 用户口径:关=清屏,不是冻结):
/// * visible true→false:屏上飘动弹幕立即清空;
/// * visible=false 期间到达的消息直接丢弃,不积压;
/// * visible false→true:从零恢复,新消息正常上屏;
/// * enabled(视频暂停)语义不变:已入队弹幕冻结保留。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_parser/live_parser.dart' show DanmakuMessage, DanmakuMessageType;
import 'package:pure_live/src/features/danmaku/widgets/danmaku_overlay.dart';

void main() {
  testWidgets('总开关关闭清屏、丢弃入队、重开从零恢复', (tester) async {
    final controller = StreamController<DanmakuMessage>.broadcast();
    addTearDown(() async => controller.close());

    Widget host({required bool visible, required bool enabled}) => Directionality(
      textDirection: TextDirection.ltr,
      child: DanmakuOverlay(messages: controller.stream, visible: visible, enabled: enabled, durationSeconds: 8),
    );

    DanmakuMessage message(String text) =>
        DanmakuMessage(type: DanmakuMessageType.chat, userName: 'u', userId: '1', text: text);

    int paintedItems() {
      final paint = tester.widget<CustomPaint>(find.byKey(const Key('danmaku-overlay')));
      // painter 为库内私有类型,经 dynamic 读取条目数。
      final items = (paint.painter as dynamic).items as List<dynamic>;
      return items.length;
    }

    await tester.pumpWidget(host(visible: true, enabled: true));
    controller.add(message('第一条'));
    await tester.pump();
    expect(paintedItems(), 1);

    // 总开关关闭:屏上弹幕立即清空。
    await tester.pumpWidget(host(visible: false, enabled: false));
    expect(paintedItems(), 0);

    // 关闭期间到达的消息直接丢弃。
    controller.add(message('关闭期间'));
    await tester.pump();
    expect(paintedItems(), 0);

    // 重开从零恢复:关闭期间的消息不洪泛,新消息正常上屏。
    await tester.pumpWidget(host(visible: true, enabled: true));
    controller.add(message('重开后'));
    await tester.pump();
    expect(paintedItems(), 1);
  });

  testWidgets('enabled=false(视频暂停)语义不变:已入队弹幕冻结保留', (tester) async {
    final controller = StreamController<DanmakuMessage>.broadcast();
    addTearDown(() async => controller.close());

    Widget host({required bool enabled}) => Directionality(
      textDirection: TextDirection.ltr,
      child: DanmakuOverlay(messages: controller.stream, visible: true, enabled: enabled, durationSeconds: 8),
    );

    await tester.pumpWidget(host(enabled: true));
    controller.add(DanmakuMessage(type: DanmakuMessageType.chat, userName: 'u', userId: '1', text: '冻结我'));
    await tester.pump();

    await tester.pumpWidget(host(enabled: false));
    final paint = tester.widget<CustomPaint>(find.byKey(const Key('danmaku-overlay')));
    expect(((paint.painter as dynamic).items as List).isNotEmpty, isTrue);
  });
}
