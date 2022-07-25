class EHException implements Exception {
  EHExceptionType type;
  String msg;

  EHException({
    required this.type,
    required this.msg,
  });

  @override
  String toString() {
    return msg;
  }
}

enum EHExceptionType {
  blankBody,
  banned,
  exceedLimit,
  unsupportedImagePageStyle,
}
