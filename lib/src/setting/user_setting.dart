import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

UserSetting userSetting = UserSetting();

class UserSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  RxnString userName = RxnString();
  RxnInt ipbMemberId = RxnInt();
  RxnString ipbPassHash = RxnString();
  RxnString avatarImgUrl = RxnString();
  RxnString nickName = RxnString();
  RxnInt defaultFavoriteIndex = RxnInt();
  RxnInt defaultTagSetNo = RxnInt();

  bool hasLoggedIn() => ipbMemberId.value != null;

  @override
  ConfigEnum get configEnum => ConfigEnum.userSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    userName = RxnString(map['userName']);
    ipbMemberId = RxnInt(map['ipbMemberId']);
    ipbPassHash = RxnString(map['ipbPassHash']);
    avatarImgUrl = RxnString(map['avatarImgUrl']);
    nickName = RxnString(map['nickName']);
    defaultFavoriteIndex = RxnInt(map['defaultFavoriteIndex']);
    defaultTagSetNo = RxnInt(map['defaultTagSetNo']);
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'userName': userName.value,
      'ipbMemberId': ipbMemberId.value,
      'ipbPassHash': ipbPassHash.value,
      'avatarImgUrl': avatarImgUrl.value,
      'nickName': nickName.value,
      'defaultFavoriteIndex': defaultFavoriteIndex.value,
      'defaultTagSetNo': defaultTagSetNo.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveUserInfo({
    required String userName,
    required int ipbMemberId,
    required String ipbPassHash,
    String? avatarImgUrl,
    String? nickName,
  }) async {
    log.debug('saveUserInfo: $userName, $ipbMemberId, $ipbPassHash, $avatarImgUrl, $nickName');
    this.userName.value = userName;
    this.ipbPassHash.value = ipbPassHash;
    this.ipbMemberId.value = ipbMemberId;
    this.avatarImgUrl.value = avatarImgUrl;
    this.nickName.value = nickName;
    await saveBeanConfig();
  }

  Future<void> saveUserNameAndAvatarAndNickName({
    required String userName,
    String? avatarImgUrl,
    required String nickName,
  }) async {
    log.debug('saveUserNameAndAvatar:$userName $avatarImgUrl $nickName');
    this.userName.value = userName;
    this.avatarImgUrl.value = avatarImgUrl;
    this.nickName.value = nickName;
    await saveBeanConfig();
  }

  Future<void> saveDefaultFavoriteIndex(int? index) async {
    log.debug('saveDefaultFavoriteIndex: $index');
    this.defaultFavoriteIndex.value = index;
    await saveBeanConfig();
  }

  Future<void> saveDefaultTagSetNo(int? number) async {
    log.debug('saveDefaultTagSet: $number');
    this.defaultTagSetNo.value = number;
    await saveBeanConfig();
  }

  @override
  Future<bool> clearBeanConfig() async {
    bool success = await super.clearBeanConfig();
    userName.value = null;
    ipbMemberId.value = null;
    ipbPassHash.value = null;
    avatarImgUrl.value = null;
    nickName.value = null;
    defaultFavoriteIndex.value = null;
    defaultTagSetNo.value = null;
    return success;
  }
}
