class GalleryUrl {
  final bool isEH;

  final int gid;

  final String token;

  const GalleryUrl({required this.isEH, required this.gid, required this.token}) : assert(token.length == 10);

  static GalleryUrl? tryParse(String url) {
    RegExp regExp = RegExp(r'https://e([-x])hentai\.org/g/(\d+)/([a-z0-9]{10})');
    Match? match = regExp.firstMatch(url);
    if (match == null) {
      return null;
    }

    return GalleryUrl(
      isEH: match.group(1) == '-',
      gid: int.parse(match.group(2)!),
      token: match.group(3)!,
    );
  }

  String get url => isEH ? 'https://e-hentai.org/g/$gid/$token/' : 'https://exhentai.org/g/$gid/$token/';
}
