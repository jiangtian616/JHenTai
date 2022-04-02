import 'package:get/get.dart';
import 'package:jhentai/src/pages/details/details_page.dart';
import 'package:jhentai/src/pages/home/home_page.dart';
import 'package:jhentai/src/pages/read/read_page.dart';
import 'package:jhentai/src/pages/search/search_page.dart';
import 'package:jhentai/src/pages/setting/about/setting_about_page.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page.dart';
import 'package:jhentai/src/pages/setting/advanced/log/log_list_page.dart';
import 'package:jhentai/src/pages/setting/advanced/log/log_page.dart';
import 'package:jhentai/src/pages/setting/advanced/setting_advanced_page.dart';
import 'package:jhentai/src/pages/setting/download/setting_download_page.dart';
import 'package:jhentai/src/pages/setting/eh/setting_eh_page.dart';
import 'package:jhentai/src/pages/setting/read/setting_read_page.dart';
import 'package:jhentai/src/pages/setting/style/setting_style_page.dart';
import 'package:jhentai/src/pages/start_page.dart';
import 'package:jhentai/src/pages/webview/webview_page.dart';

import '../pages/blank_page.dart';
import '../pages/details/comment/comment_page.dart';
import '../pages/setting/account/setting_account_page.dart';
import '../pages/single_image/single_image.dart';
import 'EHPage.dart';

class Routes {
  static const String start = "/";
  static const String blank = "/blank";

  static const String home = "/home";
  static const String details = "/details";
  static const String singleImagePage = "/single_image_page";
  static const String read = "/read";
  static const String comment = "/comment";
  static const String search = "/search";
  static const String webview = "/webview";

  static const String settingAccount = "/setting_account";
  static const String settingEH = "/setting_EH";
  static const String settingStyle = "/setting_style";
  static const String settingRead = "/setting_read";
  static const String settingDownload = "/setting_download";
  static const String settingAdvanced = "/setting_advanced";
  static const String settingAbout = "/setting_about";

  static const String login = "/setting_account/login";
  static const String logList = "/logList";
  static const String log = "/logList/log";

  static const String settingPrefix = "/setting_";

  static List<EHPage> pages = <EHPage>[
    EHPage(
      name: start,
      className: 'StartPage',
      page: () => StartPage(),
      transition: Transition.cupertino,
      side: Side.fullScreen,
    ),
    EHPage(
      name: blank,
      className: 'BlankPage',
      page: () => BlankPage(),
      transition: Transition.cupertino,
      side: Side.right,
    ),
    EHPage(
      name: home,
      className: 'HomePage',
      page: () => HomePage(),
      transition: Transition.cupertino,
      side: Side.left,
    ),
    EHPage(
      name: details,
      className: 'DetailsPage',
      page: () => DetailsPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: search,
      className: 'SearchPagePage',
      page: () => SearchPagePage(),
      transition: Transition.cupertino,
      side: Side.left,
    ),
    EHPage(
      name: singleImagePage,
      className: 'SingleImagePage',
      page: () => SingleImagePage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: webview,
      className: 'WebviewPage',
      page: () => WebviewPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: settingAccount,
      className: 'SettingAccountPage',
      page: () => SettingAccountPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingEH,
      className: 'SettingEHPage',
      page: () => SettingEHPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingStyle,
      className: 'SettingStylePage',
      page: () => SettingStylePage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingRead,
      className: 'SettingReadPage',
      page: () => SettingReadPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingDownload,
      className: 'SettingDownloadPage',
      page: () => SettingDownloadPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingAdvanced,
      className: 'SettingAdvancedPage',
      page: () => SettingAdvancedPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: settingAbout,
      className: 'SettingAboutPage',
      page: () => SettingAboutPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: login,
      className: 'LoginPage',
      page: () => LoginPage(),
      transition: Transition.cupertino,
      side: Side.fullScreen,
    ),
    EHPage(
      name: logList,
      className: 'LogListPage',
      page: () => LogListPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
    EHPage(
      name: log,
      className: 'LogPage',
      page: () => LogPage(),
      transition: Transition.cupertino,
    ),
    EHPage(
      name: read,
      className: 'ReadPage',
      page: () => ReadPage(),
      transition: Transition.cupertino,
      side: Side.fullScreen,
    ),
    EHPage(
      name: comment,
      className: 'CommentPage',
      page: () => CommentPage(),
      transition: Transition.cupertino,
      offAllBefore: false,
    ),
  ];
}
