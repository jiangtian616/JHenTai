import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/log.dart';

class ReLoginService extends GetxService {
  final StorageService storageService = Get.find();

  final bool needReLogin = true;

  static void init() {
    Get.put(ReLoginService());
    Log.verbose('init ReLoginService success', false);
  }

  @override
  void onInit() async {
    super.onInit();

    if (!needReLogin || !UserSetting.hasLoggedIn()) {
      return;
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version.trim();

    String? lastVersion = storageService.read<String>('lastVersion');

    if (lastVersion == currentVersion) {
      return;
    }
    storageService.write('lastVersion', currentVersion);

    await EHRequest.requestLogout();
  }
}
