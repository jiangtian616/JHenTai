import 'package:jhentai/src/setting/eh_setting.dart';

class EHConsts {
  static const String appName = "JHenTai";

  static String get EIndex => EHSetting.site.value == 'EH' ? EHIndex : EXIndex;

  static const String EHIndex = 'https://e-hentai.org';

  static const String EXIndex = 'https://exhentai.org';

  static String get EPopular => EHSetting.site.value == 'EH' ? EHPopular : EXPopular;

  static const String EHPopular = 'https://e-hentai.org/popular';

  static const String EXPopular = 'https://exhentai.org/popular';

  static String get EApi => EHSetting.site.value == 'EH' ? EHApi : EXApi;

  static const String EHApi = 'https://api.e-hentai.org/api.php';

  static const String EXApi = 'https://exhentai.org/api.php';

  static const String EHome = 'https://e-hentai.org/home.php';

  static const String ERanklist = 'https://e-hentai.org/toplist.php';

  static String get EWatched => EHSetting.site.value == 'EH' ? EHWatched : EXWatched;

  static const String EHWatched = 'https://e-hentai.org/watched';

  static const String EXWatched = 'https://exhentai.org/watched';

  static const String EForums = 'https://forums.e-hentai.org/index.php';

  static String get EPopup => EHSetting.site.value == 'EH' ? 'https://e-hentai.org/gallerypopups.php' : 'https://exhentai.org/gallerypopups.php';

  static String get EFavorite => EHSetting.site.value == 'EH' ? 'https://e-hentai.org/favorites.php' : 'https://exhentai.org/favorites.php';

  static String get ETorrent => EHSetting.site.value == 'EH' ? EHTorrent : EXTorrent;

  static const String EHTorrent = 'https://e-hentai.org/gallerytorrents.php';

  static const String EXTorrent = 'https://exhentai.org/gallerytorrents.php';

  static String get EArchive => EHSetting.site.value == 'EH' ? EHArchive : EXArchive;

  static const String EHArchive = 'https://e-hentai.org/archiver.php';

  static const String EXArchive = 'https://exhentai.org/archiver.php';

  static const String ELogin = 'https://forums.e-hentai.org/index.php?act=Login&CODE=00';

  static String get EUconfig => EHSetting.site.value == 'EH' ? EHUconfig : EXUconfig;

  static const String EHUconfig = 'https://e-hentai.org/uconfig.php';

  static const String EXUconfig = 'https://exhentai.org/uconfig.php';

  static const String EStat = 'https://e-hentai.org/stats.php';

  static String get ELookup => EHSetting.site.value == 'EH' ? EHLookup : EXLookup;

  static const String EHLookup = 'https://upld.e-hentai.org/image_lookup.php';

  static const String EXLookup = 'https://exhentai.org/upld/image_lookup.php';

  static const String EMyTags = 'https://e-hentai.org/mytags';

  static const String EExchange = 'https://e-hentai.org/exchange.php?t=gp';

  static const String EH509ImageUrl = 'https://ehgt.org/g/509.gif';

  static const String EX509ImageUrl = 'https://exhentai.org/img/509.gif';
}
