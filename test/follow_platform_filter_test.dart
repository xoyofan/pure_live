import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/src/features/follow/widgets/follow_platform_filter.dart';

/// 渲染定宽容器里的 [FollowPlatformFilter],返回触发 onChange 的站点 id 列表。
Widget _host({required ValueChanged<String> onChanged, Widget? leading, int? columns}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 480,
      child: FollowPlatformFilter(
        value: 'all',
        onChanged: onChanged,
        compact: true,
        columns: columns,
        chipKey: (id) => Key('filter-chip-$id'),
        leading: leading,
      ),
    ),
  ),
);

void main() {
  group('FollowPlatformFilter.leading(视图切换进筛选行首格,2026-10-02 用户口径)', () {
    testWidgets('分列网格下 leading 占首格,排在「全平台」chip 前面且同一排', (tester) async {
      await tester.pumpWidget(
        _host(
          onChanged: (_) {},
          columns: 6,
          leading: const Icon(Icons.view_list_rounded, key: Key('lead-icon')),
        ),
      );

      final leadRect = tester.getRect(find.byKey(const Key('lead-icon')));
      final allChipRect = tester.getRect(find.byKey(const Key('filter-chip-all')));
      // 「前面」= 同一排、lead 右缘不越过全平台 chip 左缘。
      expect(leadRect.top, allChipRect.top);
      expect(leadRect.right, lessThanOrEqualTo(allChipRect.left));
    });

    testWidgets('首行仍是 6 格宽:leading 占一格后本行放 5 个平台 chip', (tester) async {
      await tester.pumpWidget(
        _host(
          onChanged: (_) {},
          columns: 6,
          leading: const Icon(Icons.view_list_rounded, key: Key('lead-icon')),
        ),
      );

      final rowTop = tester.getRect(find.byKey(const Key('lead-icon'))).top;
      // navPlatforms 全量目录顺序:all, douyu, huya, bilibili, douyin, yy…
      // leading 占首格后,首行 6 格 = leading + 前 5 个平台,第 6 个换排。
      double topOf(String id) => tester.getRect(find.byKey(Key('filter-chip-$id'))).top;
      for (final id in ['all', 'douyu', 'huya', 'bilibili', 'douyin']) {
        expect((topOf(id) - rowTop).abs(), lessThan(0.5), reason: '$id 应与 leading 同排');
      }
      expect(topOf('yy'), greaterThan(rowTop + 0.5), reason: 'yy 应换到第二排');
    });

    testWidgets('不传 leading 时渲染不变(「我的关注」页既有用法)', (tester) async {
      var changed = '';
      await tester.pumpWidget(_host(onChanged: (id) => changed = id, columns: 6));

      expect(find.byKey(const Key('lead-icon')), findsNothing);
      expect(find.byKey(const Key('filter-chip-all')), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter-chip-all')));
      expect(changed, 'all');
    });
  });
}
