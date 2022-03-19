import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class UserSetting {
  static RxnString userName = RxnString();
  static RxnInt ipbMemberId = RxnInt();
  static RxnString ipbPassHash = RxnString();
  static RxnString avatarUrl = RxnString();

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('userSetting');
    if (map != null) {
      _initFromMap(map);
      Log.info('init UserSetting success');
    }
  }

  static Future<void> saveUserInfo({
    required String userName,
    required int ipbMemberId,
    required String ipbPassHash,
    String? avatarUrl,
  }) async {
    UserSetting.userName.value = userName;
    UserSetting.ipbMemberId.value = ipbMemberId;
    UserSetting.ipbPassHash.value = ipbPassHash;
    UserSetting.avatarUrl.value = avatarUrl;
    _save();
  }

  static bool hasLoggedIn() {
    return ipbMemberId.value != null && ipbMemberId.value != null && ipbPassHash.value != null;
  }

  static String getCookies() {
    return 'ipb_member_id=${ipbMemberId.value};ipb_pass_hash=${ipbPassHash.value}';
  }

  static void clear() {
    userName.value = null;
    ipbMemberId.value = null;
    ipbPassHash.value = null;
    avatarUrl.value = null;
    Get.find<StorageService>().remove('userSetting');
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('userSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'userName': userName.value,
      'ipbMemberId': ipbMemberId.value,
      'ipbPassHash': ipbPassHash.value,
      'avatarUrl': avatarUrl.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    userName = RxnString(map['userName']);
    ipbMemberId = RxnInt(map['ipbMemberId']);
    ipbPassHash = RxnString(map['ipbPassHash']);
    avatarUrl = RxnString(map['avatarUrl']);
  }
}
