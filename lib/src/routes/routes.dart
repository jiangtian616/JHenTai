import 'package:get/get.dart';
import 'package:jhentai/src/pages/details/details_page.dart';
import 'package:jhentai/src/pages/home/home_page.dart';
import 'package:jhentai/src/pages/lock_page.dart';
import 'package:jhentai/src/pages/read/read_page.dart';
import 'package:jhentai/src/pages/search/search_page.dart';
import 'package:jhentai/src/pages/setting/about/setting_about_page.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page.dart';
import 'package:jhentai/src/pages/setting/advanced/setting_advanced_page.dart';
import 'package:jhentai/src/pages/setting/download/setting_download_page.dart';
import 'package:jhentai/src/pages/setting/eh/setting_eh_page.dart';
import 'package:jhentai/src/pages/setting/eh/tagsets/tag_sets_page.dart';
import 'package:jhentai/src/pages/setting/network/hostmapping/host_mapping_page.dart';
import 'package:jhentai/src/pages/setting/network/setting_network_page.dart';
import 'package:jhentai/src/pages/setting/read/setting_read_page.dart';
import 'package:jhentai/src/pages/setting/security/setting_security_page.dart';
import 'package:jhentai/src/pages/setting/style/setting_style_page.dart';
import 'package:jhentai/src/pages/start_page.dart';
import 'package:jhentai/src/pages/webview/webview_page.dart';

import '../pages/blank_page.dart';
import '../pages/details/comment/comment_page.dart';
import '../pages/setting/account/setting_account_page.dart';
import '../pages/setting/advanced/loglist/log/log_page.dart';
import '../pages/setting/advanced/loglist/log_list_page.dart';
import '../pages/single_image/single_image.dart';
import 'EHPage.dart';

class Routes {
  static const String start = "/";
  static const String lock = "/lock";
  static const String blank = "/blank";

  static const String home = "/home";
  static const String details = "/details";
  static const String singleImagePage = "/single_image_page";
  static const String read = "/read";
  static const String comment = "/comment";
  static const String search = "/search";
  static const String webview = "/webview";

  static const String settingPrefix = "/setting_";
  static const String settingAccount = "/setting_account";
  static const String settingEH = "/setting_EH";
  static const String settingStyle = "/setting_style";
  static const String settingRead = "/setting_read";
  static const String settingNetwork = "/setting_network";
  static const String settingDownload = "/setting_download";
  static const String settingAdvanced = "/setting_advanced";
  static const String settingSecurity = "/setting_security";
  static const String settingAbout = "/setting_about";

  static const String login = "/setting_account/login";

  static const String tagSets = "/setting_EH/tagSets";

  static const String hostMapping = "/setting_network/hostMapping";

  static const String logList = "/setting_advanced/logList";
  static const String log = "/setting_advanced/logList/log";

  static List<EHPage> pages = <EHPage>[
    EHPage(
      name: start,
      page: () => StartPage(),
      transition: Transition.cupertino,
      side: Side.fullScreen,
    ),
    EHPage(
      name: lock,
      page: () => LockPage(),
      transition: Transition.cupertino,
      side: Side.fullScreen,
    ),
    EHPage(
      name: blank,
      page: () => BlankPage(),
      transition: Transition.cupertino,
      side: Side.right,
    ),
    EHPage(
      name: home,
      page: () => HomePage(),
      transition: Transition.cupertino,
      side: Side.left,
    ),
    EHPage(
      name: details,
      page: () => DetailsPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: search,
      page: () => SearchPagePage(),
      transition: Transition.cupertino,
      side: Side.left,
    ),
    EHPage(
      name: singleImagePage,
      page: () => SingleImagePage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: webview,
      page: () => WebviewPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: settingAccount,
      page: () => SettingAccountPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingEH,
      page: () => SettingEHPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingStyle,
      page: () => SettingStylePage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingRead,
      page: () => SettingReadPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingNetwork,
      page: () => SettingNetworkPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingDownload,
      page: () => SettingDownloadPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingAdvanced,
      page: () => SettingAdvancedPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingSecurity,
      page: () => SettingSecurityPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingAbout,
      page: () => SettingAboutPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: login,
      page: () => LoginPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: tagSets,
      page: () => TagSetsPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: hostMapping,
      page: () => HostMappingPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: logList,
      page: () => LogListPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: log,
      page: () => LogPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: read,
      page: () => ReadPage(),
      transition: Transition.cupertino,
      side: Side.fullScreen,
    ),
    EHPage(
      name: comment,
      page: () => CommentPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
  ];
}
