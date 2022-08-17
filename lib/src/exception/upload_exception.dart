class NotUploadException implements Exception {
  Object innerError;

  NotUploadException(this.innerError);

  @override
  String toString() {
    return 'NotUploadException{innerError: $innerError}';
  }
}
