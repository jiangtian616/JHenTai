class UploadException implements Exception {
  Exception innerException;

  UploadException(this.innerException);

  @override
  String toString() {
    return 'UploadException{innerException: $innerException}';
  }
}
