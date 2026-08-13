import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/log.dart';

void main() {
  test('logging recreates its directory after logs are cleared', () async {
    final Directory temp = await Directory.systemTemp.createTemp(
      'jh-log-service',
    );
    final Directory logDirectory = Directory('${temp.path}/nested/logs');
    final LogService service = LogService()..logDirPath = logDirectory.path;

    try {
      await service.info('first');
      expect(await logDirectory.exists(), isTrue);

      await service.clear();
      expect(await logDirectory.exists(), isFalse);

      await service.info('second');
      expect(await logDirectory.exists(), isTrue);
    } finally {
      await service.clear();
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  });
}
