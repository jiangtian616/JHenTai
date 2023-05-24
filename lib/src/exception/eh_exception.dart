class EHException implements Exception {
  EHExceptionType type;
  String msg;
  bool shouldPauseAllDownloadTasks;

  EHException({required this.type, required this.msg, this.shouldPauseAllDownloadTasks = true});

  @override
  String toString() {
    return msg;
  }
}

enum EHExceptionType { blankBody, banned, exceedLimit, unsupportedImagePageStyle, tagSetExceedLimit, galleryDeleted, intelNelError }
