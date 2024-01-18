class EHSiteException implements Exception {
  EHSiteExceptionType type;
  String message;
  bool shouldPauseAllDownloadTasks;

  EHSiteException({required this.type, required this.message, this.shouldPauseAllDownloadTasks = true});

  @override
  String toString() {
    return message;
  }
}

enum EHSiteExceptionType { blankBody, banned, exceedLimit, galleryDeleted, internalError }
