class EHException implements Exception {
  EHExceptionType type;
  String msg;

  EHException({
    required this.type,
    required this.msg,
  });

  @override
  String toString() {
    return 'EHException{type: $type, msg: $msg}';
  }
}

enum EHExceptionType {
  blankBody,
  banned,
}
