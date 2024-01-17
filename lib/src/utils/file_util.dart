import 'dart:io';
import 'dart:math';

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

  static int compareComicImagesOrderSimple(File a, File b) {
    String aName = basenameWithoutExtension(a.path);
    String bName = basenameWithoutExtension(b.path);

    int? aIndex = int.tryParse(aName);
    int? bIndex = int.tryParse(bName);

    if (aIndex != null && bIndex != null) {
      return aIndex - bIndex;
    }

    return aName.compareTo(bName);
  }

  static int compareComicImagesOrder(File a, File b) {
    final RegExp regExp = RegExp(r'(\d+)');

    String aName = basenameWithoutExtension(a.path);
    String bName = basenameWithoutExtension(b.path);

    final Iterable<Match> matchesA = regExp.allMatches(aName);
    final Iterable<Match> matchesB = regExp.allMatches(bName);

    List<int> numbersA = matchesA.map((m) => int.parse(m.group(0)!)).toList();
    List<int> numbersB = matchesB.map((m) => int.parse(m.group(0)!)).toList();

    if (numbersA.isEmpty || numbersB.isEmpty) {
      return aName.compareTo(bName);
    }

    for (int i = 0; i < min(numbersA.length, numbersB.length); i++) {
      if (numbersA[i] != numbersB[i]) {
        return numbersA[i].compareTo(numbersB[i]);
      }
    }

    return aName.compareTo(bName);
  }
}

void main() {
  print(FileUtil.compareComicImagesOrderSimple(File('image10_1.jpg'), File('image1_1.jpg')));
}
