import 'dart:io';

import 'package:path/path.dart';

class FileUtil {
  static final RegExp _galleryPathPattern = RegExp(r'\d+ - .*');
  static final RegExp _archivePathPattern = RegExp(r'Archive - \d+ - .*');

  static bool isImageExtension(String path) {
    return path.endsWith('.jpg') || path.endsWith('.png') || path.endsWith('.gif') || path.endsWith('.jpeg');
  }

  static bool isJHenTaiGalleryDirectory(Directory directory) {
    return _galleryPathPattern.hasMatch(directory.path) || _archivePathPattern.hasMatch(directory.path);
  }

  static bool isJHenTaiFile(File file) {
    return basename(file.path) == '.nomedia' || _galleryPathPattern.hasMatch(file.parent.path) || _archivePathPattern.hasMatch(file.parent.path);
  }
}
