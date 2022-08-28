import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/log.dart';

class ReLoginService extends GetxService {
  final StorageService storageService = Get.find();

  final bool needReLogin = false;

  static void init() {
    Get.put(ReLoginService());
    Log.debug('init ReLoginService success', false);
  }

  @override
  void onInit() async {
    super.onInit();

    if (!needReLogin) {
      return;
    }

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version.trim();

    String? lastVersion = storageService.read<String>('lastVersion');

    Log.info('last version:$lastVersion, current version:$currentVersion', false);
    if (lastVersion == currentVersion) {
      return;
    }

    storageService.write('lastVersion', currentVersion);

    Log.info('Logout due to app update', false);
    await EHRequest.requestLogout();
  }
}
