class EHConsts {
  static const String EHIndex = 'https://e-hentai.org';
  static const String EHApi = 'https://api.e-hentai.org/api.php';
  static const String EHHome= 'https://e-hentai.org/home.php';
  static const String EHForums = 'https://forums.e-hentai.org/index.php';
  static const String EHPopup = 'https://e-hentai.org/gallerypopups.php';
  static const String EHFavorite = 'https://e-hentai.org/favorites.php';

  static const String EXIndex = 'https://exhentai.org';

  static const Map<String, String> host2Ip = {
    'e-hentai.org': '104.20.135.21',
    'api.e-hentai.org': '178.162.147.246',
    'exhentai.org': '178.175.129.254',
    'api.exhentai.org': '178.175.128.252',
    'forums.e-hentai.org': '94.100.18.243',
    'ehgt.org': '178.162.140.212',
    'raw.githubusercontent.com': '178.175.129.254',
  };

  static const List<String> tagNamespaces = [
    'rows',
    'reclass',
    'language',
    'parody',
    'character',
    'group',
    'artist',
    'cosplayer',
    'male',
    'female',
    'mixed',
    'other',
  ];
}
