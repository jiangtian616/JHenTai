int parseGalleryUrl2Gid(String url) {
  return int.parse(RegExp(r'/g/(\d+)/').firstMatch(url)!.group(1)!);
}
