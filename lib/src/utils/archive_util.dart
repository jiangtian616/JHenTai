import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';

Future<bool> extractZipArchive(String archivePath, String extractPath) {
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

Future<List<int>> extractGZipArchive(String archivePath) {
  return compute(
    (String path) async {
      InputFileStream inputStream = InputFileStream(path);
      try {
        return GZipDecoder().decodeBuffer(inputStream);
      } on Exception catch (_) {
        return [];
      } finally {
        inputStream.close();
      }
    },
    archivePath,
  );
}
