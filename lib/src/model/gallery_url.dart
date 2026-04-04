import 'package:jhentai/src/exception/internal_exception.dart';
import 'package:jhentai/src/setting/eh_setting.dart';

class GalleryUrl {
  final bool isEH;
  final bool isNH;
  final bool isWN;
  final String? sourceHost;

  final int gid;

  final String token;

  const GalleryUrl({
    required this.isEH,
    required this.gid,
    required this.token,
    this.isNH = false,
    this.isWN = false,
    this.sourceHost,
  }) : assert(isWN || isNH || token.length == 10);

  static GalleryUrl? tryParse(String url) {
    RegExp regExp =
        RegExp(r'https://e([-x])hentai\.org/g/(\d+)/([a-z0-9]{10})');
    Match? match = regExp.firstMatch(url);
    if (match != null) {
      return GalleryUrl(
        isEH: match.group(1) == '-',
        gid: int.parse(match.group(2)!),
        token: match.group(3)!,
      );
    }

    for (String domain in ehSetting.nhentaiDomains) {
      String escapedDomain = domain.replaceAll('.', r'\.');
      RegExp nhRegExp = RegExp('https?://(?:www\\.)?$escapedDomain/g/(\\d+)(?:/|\$)');
      Match? nhMatch = nhRegExp.firstMatch(url);
      if (nhMatch != null) {
        return GalleryUrl(
          isEH: true,
          isNH: true,
          gid: int.parse(nhMatch.group(1)!),
          token: 'nhentai',
          sourceHost: domain,
        );
      }
    }

    Uri? wnUri = Uri.tryParse(url);
    if (wnUri != null) {
      String host = wnUri.host;
      bool isWnHost = host == 'wnacg.com' || host == 'www.wnacg.com' || host == ehSetting.wnacgDomain.value;
      if (isWnHost) {
        RegExp wnAidRegExp = RegExp(r'aid-(\d+)');
        Match? wnMatch = wnAidRegExp.firstMatch(wnUri.path);
        if (wnMatch != null) {
          return GalleryUrl(
            isEH: true,
            isWN: true,
            gid: int.parse(wnMatch.group(1)!),
            token: 'wnacg',
          );
        }
      }
    }

    return null;
  }

  static GalleryUrl parse(String url) {
    GalleryUrl? galleryUrl = tryParse(url);
    if (galleryUrl == null) {
      throw InternalException(message: 'Parse gallery url failed, url:$url');
    }

    return galleryUrl;
  }

  String get url {
    if (isWN) {
      return 'https://${ehSetting.wnacgDomain.value}/photos-index-aid-$gid.html';
    }
    if (isNH) {
      return 'https://${sourceHost ?? 'nhentai.net'}/g/$gid/';
    }
    return isEH
        ? 'https://e-hentai.org/g/$gid/$token/'
        : 'https://exhentai.org/g/$gid/$token/';
  }

  GalleryUrl copyWith({
    bool? isEH,
    bool? isNH,
    bool? isWN,
    String? sourceHost,
    int? gid,
    String? token,
  }) {
    return GalleryUrl(
      isEH: isEH ?? this.isEH,
      isNH: isNH ?? this.isNH,
      isWN: isWN ?? this.isWN,
      sourceHost: sourceHost ?? this.sourceHost,
      gid: gid ?? this.gid,
      token: token ?? this.token,
    );
  }

  @override
  String toString() {
    return 'GalleryUrl{isEH: $isEH, isNH: $isNH, isWN: $isWN, sourceHost: $sourceHost, gid: $gid, token: $token}';
  }
}
