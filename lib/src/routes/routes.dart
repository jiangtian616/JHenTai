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
import 'package:jhentai/src/pages/setting/gallery/setting_gallery_page.dart';
import 'package:jhentai/src/pages/setting/read/setting_read_page.dart';
import 'package:jhentai/src/pages/test.dart';
import 'package:jhentai/src/pages/webview/webview_page.dart';

import '../pages/details/comment/comment_page.dart';
import '../pages/setting/account/setting_account_page.dart';
import '../pages/single_image/single_image.dart';

class Routes {
  static const String home = "/";
  static const String details = "/details";
  static const String singleImagePage = "/single_image_page";
  static const String read = "/read";
  static const String comment = "/comment";
  static const String search = "/search";
  static const String webview = "/webview";

  static const String settingAccount = "/setting_account";
  static const String settingEH = "/setting_EH";
  static const String settingGallery = "/setting_gallery";
  static const String settingRead = "/setting_read";
  static const String settingDownload = "/setting_download";
  static const String settingAdvanced = "/setting_advanced";
  static const String settingAbout = "/setting_about";

  static const String login = "/setting_account/login";
  static const String logList = "/logList";
  static const String log = "/logList/log";

  static const String settingPrefix = "/setting_";

  static const String test = "/test";

  static List<GetPage> getPages() => <GetPage>[
        GetPage(
          name: home,
          page: () => HomePage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: details,
          page: () => DetailsPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: search,
          page: () => SearchPagePage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: singleImagePage,
          page: () => SingleImagePage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: webview,
          page: () => WebviewPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingAccount,
          page: () => SettingAccountPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingEH,
          page: () => SettingEHPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingGallery,
          page: () => SettingGalleryPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingRead,
          page: () => SettingReadPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingDownload,
          page: () => SettingDownloadPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingAdvanced,
          page: () => SettingAdvancedPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingAbout,
          page: () => SettingAboutPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: login,
          page: () => LoginPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: logList,
          page: () => LogListPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: log,
          page: () => LogPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: read,
          page: () => ReadPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: comment,
          page: () => CommentPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: test,
          page: () => TestPage(),
          transition: Transition.cupertino,
        ),
      ];
}
