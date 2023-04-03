import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';

Future<bool> extractArchive(String archivePath, String extractPath) {
  return compute(
    (List<String> path) async {
      InputFileStream inputStream = InputFileStream(path[0]);
      try {
        extractArchiveToDisk(ZipDecoder().decodeBuffer(inputStream), path[1]);
      } on Exception catch (_) {
        return false;
      } finally {
        inputStream.close();
      }
      return true;
    },
    [archivePath, extractPath],
  );
}
