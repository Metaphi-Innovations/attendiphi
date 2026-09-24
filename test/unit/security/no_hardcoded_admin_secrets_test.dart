import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib and web contain no hardcoded production admin passwords', () {
    final roots = [Directory('lib'), Directory('web')];
    const forbidden = [
      'SuperAdmin@2026',
      'Admin@1234',
      'superadmin@metaphi.com',
      'admin@qrcheckin.com',
    ];
    final hits = <String>[];
    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!(entity.path.endsWith('.dart') ||
            entity.path.endsWith('.html') ||
            entity.path.endsWith('.js'))) {
          continue;
        }
        if (entity.path.contains('ort.min.js') ||
            entity.path.contains('face-api.min.js')) {
          continue;
        }
        final contents = entity.readAsStringSync();
        for (final needle in forbidden) {
          if (contents.contains(needle)) {
            hits.add('${entity.path}: $needle');
          }
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
