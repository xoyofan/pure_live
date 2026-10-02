// One-off catalog diagnostic: run the real site adapters for the currently
// failing sites inside the probe harness and print the full error + stack.
//
//   PURELIVE_CATALOG_DIAG=1 flutter test tool/probes/catalog_diag_probe_test.dart
//   PURELIVE_CATALOG_SITES=showroom,missevan
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/sites.dart';

const _timeout = Duration(seconds: 60);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('catalog diagnostic', () async {
    final wanted = (Platform.environment['PURELIVE_CATALOG_SITES'] ?? 'showroom,missevan')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    await HttpOverrides.runWithHttpOverrides(() async {
      for (final id in wanted) {
        // ignore: avoid_print
        print('=== $id');
        try {
          final categories = await Sites.of(id).liveSite.getCategores(1, 100).timeout(_timeout);
          for (final category in categories) {
            // ignore: avoid_print
            print('  GROUP ${category.name}');
            print('  ${category.name}: ${category.children.length} children '
                '${category.children.take(6).map((a) => a.areaName).toList()}');
          }
        } catch (error, stack) {
          // ignore: avoid_print
          print('  ERROR $error');
          // ignore: avoid_print
          print(stack.toString().split('\n').take(14).join('\n'));
        }
      }
    }, _RealNetwork());
  }, skip: Platform.environment['PURELIVE_CATALOG_DIAG'] != '1', timeout: const Timeout(Duration(minutes: 5)));
}

class _RealNetwork extends HttpOverrides {}
