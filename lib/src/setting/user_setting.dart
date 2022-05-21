import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class UserSetting {
  static RxnString userName = RxnString();
  static RxnInt ipbMemberId = RxnInt();
  static RxnString ipbPassHash = RxnString();

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('userSetting');
    if (map != null) {
      _initFromMap(map);
      Log.verbose('init UserSetting success', false);
    } else {
      Log.verbose('init UserSetting success, not logged in', false);
    }
  }

  static Future<void> saveUserInfo({
    required String userName,
    required int ipbMemberId,
    required String ipbPassHash,
  }) async {
    UserSetting.userName.value = userName;
    UserSetting.ipbPassHash.value = ipbPassHash;
    UserSetting.ipbMemberId.value = ipbMemberId;
    _save();
  }

  static bool hasLoggedIn() {
    return ipbMemberId.value != null;
  }

  static String getCookies() {
    return 'ipb_member_id=${ipbMemberId.value};ipb_pass_hash=${ipbPassHash.value}';
  }

  static void clear() {
    Get.find<StorageService>().remove('userSetting');
    userName.value = null;
    ipbMemberId.value = null;
    ipbPassHash.value = null;
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('userSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'userName': userName.value,
      'ipbMemberId': ipbMemberId.value,
      'ipbPassHash': ipbPassHash.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    userName = RxnString(map['userName']);
    ipbMemberId = RxnInt(map['ipbMemberId']);
    ipbPassHash = RxnString(map['ipbPassHash']);
  }
}
