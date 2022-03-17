import 'package:get/get.dart';
import 'package:jhentai/src/pages/details/details_page.dart';
import 'package:jhentai/src/pages/home/home_page.dart';
import 'package:jhentai/src/pages/read/read_page.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page.dart';
import 'package:jhentai/src/pages/setting/advanced/setting_advanced_page.dart';
import 'package:jhentai/src/pages/test.dart';

import '../pages/setting/account/setting_account_page.dart';
import '../pages/single_image/single_image.dart';

class Routes {
  static const String home = "/";
  static const String details = "/details";
  static const String singleImagePage = "/single_image_page";
  static const String read = "/read";

  static const String settingAccount = "/setting_account";
  static const String settingEh = "/setting_account";
  static const String settingHome = "/setting_home";
  static const String settingRead = "/setting_read";
  static const String settingDownload = "/setting_download";
  static const String settingAdvanced = "/setting_advanced";
  static const String settingAbout = "/setting_about";
  static const String login = "/setting_account/login";

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
          name: singleImagePage,
          page: () => SingleImagePage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingAccount,
          page: () => SettingAccountPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: settingAdvanced,
          page: () => SettingAdvancedPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: login,
          page: () => LoginPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: read,
          page: () => ReadPage(),
          transition: Transition.cupertino,
        ),
        GetPage(
          name: test,
          page: () => TestPage(),
          transition: Transition.cupertino,
        ),
      ];
}
