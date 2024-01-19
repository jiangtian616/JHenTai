class EHParseException implements Exception {
  EHParseExceptionType type;
  String message;
  bool shouldPauseAllDownloadTasks;

  EHParseException({required this.type, required this.message, this.shouldPauseAllDownloadTasks = true});

  @override
  String toString() {
    return message;
  }
}

enum EHParseExceptionType { exceedLimit, unsupportedImagePageStyle, tagSetExceedLimit, getMetaDataFailed }
