class FileUtil {
  static bool isImageExtension(String path) {
    return path.endsWith('.jpg') || path.endsWith('.png') || path.endsWith('.gif') || path.endsWith('.jpeg');
  }
}
