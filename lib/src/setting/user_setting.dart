import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class UserSetting {
  static RxnString userName = RxnString();
  static RxnInt ipbMemberId = RxnInt();
  static RxnString ipbPassHash = RxnString();
  static RxnString avatarImgUrl = RxnString();

  static Future<void> init() async {
    Map<String, dynamic>? map = Get.find<StorageService>().read<Map<String, dynamic>>('userSetting');
    if (map != null) {
      _initFromMap(map);
      Log.debug('init UserSetting success', false);
    } else {
      Log.debug('init UserSetting success, not logged in', false);
    }
  }

  static Future<void> saveUserInfo({
    required String userName,
    required int ipbMemberId,
    required String ipbPassHash,
    String? avatarImgUrl,
  }) async {
    Log.debug('saveUserInfo:$userName');
    UserSetting.userName.value = userName;
    UserSetting.ipbPassHash.value = ipbPassHash;
    UserSetting.ipbMemberId.value = ipbMemberId;
    UserSetting.avatarImgUrl.value = avatarImgUrl;
    _save();
  }

  static Future<void> saveUserNameAndAvatar({
    required String userName,
    String? avatarImgUrl,
  }) async {
    Log.debug('saveUserNameAndAvatar:$userName $avatarImgUrl');
    UserSetting.userName.value = userName;
    UserSetting.avatarImgUrl.value = avatarImgUrl;
    _save();
  }

  static bool hasLoggedIn() {
    return ipbMemberId.value != null;
  }

  static void clear() {
    Get.find<StorageService>().remove('userSetting');
    userName.value = null;
    ipbMemberId.value = null;
    ipbPassHash.value = null;
    avatarImgUrl.value = null;
  }

  static Future<void> _save() async {
    await Get.find<StorageService>().write('userSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'userName': userName.value,
      'ipbMemberId': ipbMemberId.value,
      'ipbPassHash': ipbPassHash.value,
      'avatarImgUrl': avatarImgUrl.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    userName = RxnString(map['userName']);
    ipbMemberId = RxnInt(map['ipbMemberId']);
    ipbPassHash = RxnString(map['ipbPassHash']);
    avatarImgUrl = RxnString(map['avatarImgUrl']);
  }
}
