class EHSiteException implements Exception {
  EHSiteExceptionType type;
  String message;
  String? referLink;
  bool shouldPauseAllDownloadTasks;

  EHSiteException({
    required this.type,
    required this.message,
    this.referLink,
    this.shouldPauseAllDownloadTasks = true,
  });

  @override
  String toString() {
    return message;
  }
}

enum EHSiteExceptionType { blankBody, banned, exceedLimit, galleryDeleted, internalError, ehServerError }
