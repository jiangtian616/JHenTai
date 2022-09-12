import 'dart:io' as io;

import 'package:path/path.dart';

import '../utils/log.dart';

extension DirectoryExtension on io.Directory {
  Future<void> copy(String toPath) async {
    if (path == toPath) {
      return;
    }

    List<io.FileSystemEntity> entities;
    try {
      entities = listSync(recursive: true);
    } on Exception catch (e) {
      Log.error(e);
      Log.upload(e, extraInfos: {'path': path});
      return;
    }

    List<Future> futures = [];
    for (io.FileSystemEntity file in entities) {
      if (file is! io.File) {
        Log.error('Not a file: ${file.path}');
        Log.upload(Exception('Not a file'), extraInfos: {'file': file.path});
        continue;
      }

      io.File newFile = io.File(join(toPath, relative(file.path, from: path)));
      if (newFile.existsSync()) {
        continue;
      }

      try {
        futures.add(file.copy(join(toPath, relative(file.path, from: path))));
      } on Exception catch (e) {
        Log.error(e);
        Log.upload(e, extraInfos: {
          'oldPath': file.path,
          'newPath': join(toPath, relative(file.path, from: path)),
        });
        return;
      }
    }

    await Future.wait(futures);
  }
}
