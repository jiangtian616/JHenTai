class EHImageException implements Exception {
  EHImageExceptionType type;
  String message;
  EHImageExceptionAfterOperation operation;

  EHImageException({
    required this.type,
    required this.message,
    required this.operation,
  });

  @override
  String toString() {
    return message;
  }
}

enum EHImageExceptionType {
  peakHours,
  oldGallery,
  exceedLimit,
  invalidToken,
  serverError,
}

enum EHImageExceptionAfterOperation {
  reParse,
  pause,
  pauseAll,
}
