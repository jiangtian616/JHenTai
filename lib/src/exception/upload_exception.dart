class UploadException implements Exception {
  Object innerError;

  UploadException(this.innerError);

  @override
  String toString() {
    return 'UploadException{innerError: $innerError}';
  }
}
