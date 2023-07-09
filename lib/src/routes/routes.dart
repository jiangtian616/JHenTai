import 'package:get/get.dart';
import 'package:jhentai/src/pages/details/details_page.dart';
import 'package:jhentai/src/pages/details/thumbnails/thumbnails_page.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page.dart';
import 'package:jhentai/src/pages/history/history_page.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page.dart';
import 'package:jhentai/src/pages/lock_page.dart';
import 'package:jhentai/src/pages/popular/popular_page.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page.dart';
import 'package:jhentai/src/pages/read/read_page.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2.dart';
import 'package:jhentai/src/pages/search/quick_search/quick_search_page.dart';
import 'package:jhentai/src/pages/setting/about/setting_about_page.dart';
import 'package:jhentai/src/pages/setting/account/cookie/cookie_page.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page.dart';
import 'package:jhentai/src/pages/setting/advanced/setting_advanced_page.dart';
import 'package:jhentai/src/pages/setting/download/extra_gallery_scan_path/extra_gallery_scan_path_page.dart';
import 'package:jhentai/src/pages/setting/download/setting_download_page.dart';
import 'package:jhentai/src/pages/setting/eh/setting_eh_page.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page.dart';
import 'package:jhentai/src/pages/setting/mousewheel/setting_mouse_wheel_page.dart';
import 'package:jhentai/src/pages/setting/network/proxy/setting_proxy_page.dart';
import 'package:jhentai/src/pages/setting/network/setting_network_page.dart';
import 'package:jhentai/src/pages/setting/preference/setting_preference_page.dart';
import 'package:jhentai/src/pages/setting/read/setting_read_page.dart';
import 'package:jhentai/src/pages/setting/security/setting_security_page.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';
import 'package:jhentai/src/pages/setting/style/setting_style_page.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/pages/watched/watched_page.dart';
import 'package:jhentai/src/pages/webview/webview_page.dart';
import 'package:jhentai/src/setting/preference_setting.dart';

import '../pages/blank_page.dart';
import '../pages/details/comment/comment_page.dart';
import '../pages/favorite/favorite_page.dart';
import '../pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import '../pages/search/desktop/desktop_search_page.dart';
import '../pages/setting/account/setting_account_page.dart';
import '../pages/setting/advanced/loglist/log/log_page.dart';
import '../pages/setting/advanced/loglist/log_list_page.dart';
import '../pages/setting/advanced/super_resolution/setting_super_resolution_page.dart';
import '../pages/setting/network/host_mapping/host_mapping_page.dart';
import '../pages/setting/preference/local_tag/add_local_tag/add_local_tag_page.dart';
import '../pages/setting/preference/local_tag/local_tag_sets_page.dart';
import '../pages/setting/style/page_list_style/setting_page_list_style_page.dart';
import '../pages/setting/style/theme_color/setting_theme_color_page.dart';
import '../pages/single_image/single_image.dart';
import 'eh_page.dart';

class Routes {
  static const String home = "/";
  static const String lock = "/lock";
  static const String blank = "/blank";

  static const String read = "/read";
  static const String singleImagePage = "/single_image_page";

  /// left
  static const String mobileLayoutV2 = "/mobile_layout_v2";
  static const String gallerys = "/gallerys";
  static const String dashboard = "/dashboard";
  static const String popular = "/popular";
  static const String ranklist = "/ranklist";
  static const String favorite = "/favorite";
  static const String watched = "/watched";
  static const String history = "/history";
  static const String download = "/download";
  static const String setting = "/setting";
  static const String search = "/search";
  static const String desktopSearch = "/desktop_search";
  static const String mobileV2Search = "/mobile_v2_search";

  /// right
  static const String details = "/details";
  static const String comment = "/comment";
  static const String thumbnails = "/thumbnails";
  static const String webview = "/webview";
  static const String quickSearch = "/qucik_search";

  static const String settingPrefix = "/setting_";
  static const String settingAccount = "/setting_account";
  static const String settingEH = "/setting_EH";
  static const String settingStyle = "/setting_style";
  static const String settingRead = "/setting_read";
  static const String settingPreference = "/setting_preference";
  static const String settingNetwork = "/setting_network";
  static const String settingDownload = "/setting_download";
  static const String settingAdvanced = "/setting_advanced";
  static const String settingMouseWheel = "/setting_mouse_wheel";
  static const String settingSecurity = "/setting_security";
  static const String settingAbout = "/setting_about";

  static const String login = "/setting_account/login";
  static const String cookie = "/setting_account/cookie";

  static const String themeColor = "/setting_style/themeColor";
  static const String pageListStyle = "/setting_style/pageListStyle";

  static const String tagSets = "/setting_EH/tagSets";
  static const String localTagSets = "/setting_EH/localTagSets";
  static const String addLocalTag = "/setting_EH/addLocalTag";

  static const String hostMapping = "/setting_network/hostMapping";
  static const String proxy = "/setting_network/proxy";

  static const String extraGalleryScanPath = "/setting_download/extraGalleryScanPath";

  static const String superResolution = "/setting_advanced/superResolution";
  static const String logList = "/setting_advanced/logList";
  static const String log = "/setting_advanced/logList/log";

  static final Transition defaultTransition = PreferenceSetting.enableSwipeBackGesture.isTrue ? Transition.cupertino : Transition.fadeIn;

  static List<EHPage> pages = <EHPage>[
    EHPage(
      name: home,
      page: () => const HomePage(),
      transition: Transition.fade,
      side: Side.fullScreen,
    ),
    EHPage(
      name: lock,
      page: () => const LockPage(),
      transition: Transition.fade,
      side: Side.fullScreen,
      popGesture: false,
    ),
    EHPage(
      name: blank,
      page: () => const BlankPage(),
      transition: defaultTransition,
      side: Side.right,
    ),
    EHPage(
      name: gallerys,
      page: () => const GallerysPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: dashboard,
      page: () => const DashboardPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: mobileLayoutV2,
      page: () => MobileLayoutPageV2(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: details,
      page: () => DetailsPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: popular,
      page: () => PopularPage(showTitle: true, name: 'popular'.tr),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: ranklist,
      page: () => const RanklistPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: favorite,
      page: () => const FavoritePage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: setting,
      page: () => const SettingPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: watched,
      page: () => const WatchedPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: history,
      page: () => HistoryPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: download,
      page: () => const DownloadPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: desktopSearch,
      page: () => const DesktopSearchPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: mobileV2Search,
      page: () => SearchPageMobileV2(),
      transition: defaultTransition,
      side: Side.left,
    ),
    EHPage(
      name: singleImagePage,
      page: () => const SingleImagePage(),
      transition: Transition.noTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: webview,
      page: () => const WebviewPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: quickSearch,
      page: () => QuickSearchPage(automaticallyImplyLeading: true),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: settingAccount,
      page: () => const SettingAccountPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingEH,
      page: () => const SettingEHPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingStyle,
      page: () => const SettingStylePage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingRead,
      page: () => const SettingReadPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingPreference,
      page: () => SettingPreferencePage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingNetwork,
      page: () => SettingNetworkPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingDownload,
      page: () => const SettingDownloadPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingMouseWheel,
      page: () => const SettingMouseWheelPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingAdvanced,
      page: () => const SettingAdvancedPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingSecurity,
      page: () => const SettingSecurityPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: settingAbout,
      page: () => const SettingAboutPage(),
      transition: defaultTransition,
    ),
    EHPage(
      name: login,
      page: () => LoginPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: cookie,
      page: () => const CookiePage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: themeColor,
      page: () => const SettingThemeColorPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: pageListStyle,
      page: () => SettingPageListStylePage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: tagSets,
      page: () => TagSetsPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: localTagSets,
      page: () => LocalTagSetsPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: addLocalTag,
      page: () => AddLocalTagPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: hostMapping,
      page: () => const HostMappingPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: proxy,
      page: () => const SettingProxyPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: extraGalleryScanPath,
      page: () => const ExtraGalleryScanPathPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: superResolution,
      page: () => const SettingSuperResolutionPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: logList,
      page: () => const LogListPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: log,
      page: () => const LogPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: read,
      page: () => ReadPage(),
      transition: defaultTransition,
      side: Side.fullScreen,
    ),
    EHPage(
      name: comment,
      page: () => const CommentPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    EHPage(
      name: thumbnails,
      page: () => ThumbnailsPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
  ];
}
