class EHException implements Exception {
  EHExceptionType type;
  String message;
  bool shouldPauseAllDownloadTasks;

  EHException({required this.type, required this.message, this.shouldPauseAllDownloadTasks = true});

  @override
  String toString() {
    return message;
  }
}

enum EHExceptionType { blankBody, banned, exceedLimit, unsupportedImagePageStyle, tagSetExceedLimit, galleryDeleted, intelNelError }
