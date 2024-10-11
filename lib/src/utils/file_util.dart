import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

class FileUtil {
  static final RegExp _galleryPathPattern = RegExp(r'\d+ - .*');
  static final RegExp _archivePathPattern = RegExp(r'Archive - \d+ - .*');

  static bool isImageExtension(String path) {
    return path.endsWith('.jpg') || path.endsWith('.JPG') || path.endsWith('.png') || path.endsWith('.gif') || path.endsWith('.jpeg');
  }

  static bool isJHenTaiGalleryDirectory(Directory directory) {
    return _galleryPathPattern.hasMatch(directory.path) || _archivePathPattern.hasMatch(directory.path);
  }

  static bool isJHenTaiFile(File file) {
    return basename(file.path) == '.nomedia' || _galleryPathPattern.hasMatch(file.parent.path) || _archivePathPattern.hasMatch(file.parent.path);
  }

  static int naturalCompareFile(File aFile, File bFile) {
    return naturalCompare(basenameWithoutExtension(aFile.path), basenameWithoutExtension(bFile.path));
  }

  static int naturalCompare(String a, String b) {
    List<RegExpMatch> aParts = RegExp(r'(\d+|\D+)').allMatches(a).toList();
    List<RegExpMatch> bParts = RegExp(r'(\d+|\D+)').allMatches(b).toList();

    var minParts = aParts.length < bParts.length ? aParts.length : bParts.length;

    for (var i = 0; i < minParts; i++) {
      String aPart = aParts[i].group(0)!;
      String bPart = bParts[i].group(0)!;

      if (aPart == bPart) {
        continue;
      }

      int? aNum = int.tryParse(aPart);
      int? bNum = int.tryParse(bPart);

      if (aNum != null && bNum != null && aNum - bNum != 0) {
        return aNum - bNum;
      }

      if (aPart.compareTo(bPart) != 0) {
        return aPart.compareTo(bPart);
      }
    }

    return aParts.length - bParts.length;
  }

  static Future<String> computeSha1Hash(File file) {
    return file.readAsBytes().then((bytes) {
      return sha1.convert(bytes).toString();
    });
  }
}
