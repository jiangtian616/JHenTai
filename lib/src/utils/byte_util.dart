String byte2String(double bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  }

  bytes /= 1024;
  if (bytes < 1024) {
    return '${bytes.toStringAsFixed(2)}KB';
  }

  bytes /= 1024;
  if (bytes < 1024) {
    return '${bytes.toStringAsFixed(2)}MB';
  }

  bytes /= 1024;
  return '${bytes.toStringAsFixed(2)}GB';
}
