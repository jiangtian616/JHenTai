class ArchiveUnlockResult {
  final bool success;
  final String msg;
  final String? url;

  const ArchiveUnlockResult({required this.success, required this.msg, this.url});

  @override
  String toString() {
    return 'ArchiveUnlockResult{success: $success, msg: $msg, url: $url}';
  }
}
