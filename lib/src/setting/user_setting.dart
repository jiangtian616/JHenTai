import 'package:get/get.dart';
import 'package:jhentai/src/utils/log.dart';

import '../service/storage_service.dart';

class UserSetting {
  static RxnString userName = RxnString();
  static RxnInt ipbMemberId = RxnInt();
  static RxnString ipbPassHash = RxnString();
  static RxnString avatarImgUrl = RxnString();
  static RxnString nickName = RxnString();
  static RxnInt defaultFavoriteIndex = RxnInt();

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
    String? nickName,
  }) async {
    Log.debug('saveUserInfo: $userName, $ipbMemberId, $ipbPassHash, $avatarImgUrl, $nickName');
    UserSetting.userName.value = userName;
    UserSetting.ipbPassHash.value = ipbPassHash;
    UserSetting.ipbMemberId.value = ipbMemberId;
    UserSetting.avatarImgUrl.value = avatarImgUrl;
    UserSetting.nickName.value = nickName;
    save();
  }

  static Future<void> saveUserNameAndAvatarAndNickName({
    required String userName,
    String? avatarImgUrl,
    required String nickName,
  }) async {
    Log.debug('saveUserNameAndAvatar:$userName $avatarImgUrl $nickName');
    UserSetting.userName.value = userName;
    UserSetting.avatarImgUrl.value = avatarImgUrl;
    UserSetting.nickName.value = nickName;
    save();
  }
  
  static Future<void> saveDefaultFavoriteIndex(int? index) async {
    Log.debug('saveDefaultFavoriteIndex: $index');
    UserSetting.defaultFavoriteIndex.value = index;
    save();
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
    nickName.value = null;
    defaultFavoriteIndex.value = null;
  }

  static Future<void> save() async {
    await Get.find<StorageService>().write('userSetting', _toMap());
  }

  static Map<String, dynamic> _toMap() {
    return {
      'userName': userName.value,
      'ipbMemberId': ipbMemberId.value,
      'ipbPassHash': ipbPassHash.value,
      'avatarImgUrl': avatarImgUrl.value,
      'nickName': nickName.value,
      'defaultFavoriteIndex': defaultFavoriteIndex.value,
    };
  }

  static _initFromMap(Map<String, dynamic> map) {
    userName = RxnString(map['userName']);
    ipbMemberId = RxnInt(map['ipbMemberId']);
    ipbPassHash = RxnString(map['ipbPassHash']);
    avatarImgUrl = RxnString(map['avatarImgUrl']);
    nickName = RxnString(map['nickName']);
    defaultFavoriteIndex = RxnInt(map['defaultFavoriteIndex']);
  }
}
