import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:retry/retry.dart';

import '../network/eh_request.dart';
import 'jh_service.dart';
import 'local_block_rule_service.dart';
import 'log.dart';

BuiltInBlockedUserService builtInBlockedUserService = BuiltInBlockedUserService();

typedef EHUser = ({int userId, String name});

class BuiltInBlockedUserService with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean, ExtraBlockRuleProvider {
  final RxList<EHUser> _blockedUsers = RxList();

  List<EHUser> get blockedUsers => _blockedUsers.toList();

  @override
  ConfigEnum get configEnum => ConfigEnum.builtInBlockedUser;

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll([localBlockRuleService]);

  @override
  void applyBeanConfig(String configString) {
    List list = jsonDecode(configString);
    if (list.isNotEmpty) {
      _blockedUsers.value = list.map((map) => (userId: map['userId'] as int, name: map['name'] as String)).toList();
    }
  }

  @override
  String toConfigString() {
    return jsonEncode(_blockedUsers.map((user) => {'userId': user.userId, 'name': user.name}).toList());
  }

  @override
  Future<void> doInitBean() async {
    localBlockRuleService.registerExtraBlockRuleProvider(this);
  }

  @override
  Future<void> doAfterBeanReady() async {
    String json;
    try {
      json = await retry(
        () => ehRequest.get(
          url: 'https://raw.githubusercontent.com/jiangtian616/JHenTai/refs/heads/master/built_in_blocked_user.json',
          parser: simpleParser,
        ),
        maxAttempts: 5,
        onRetry: (error) => log.warning('Get built-in blocked user data failed, retrying', error),
      );
    } on DioException catch (e) {
      log.error('Get built-in blocked user data failed after 5 times', e);
      return;
    }

    Map map = jsonDecode(json);
    if (map.isEmpty) {
      log.warning('Built-in blocked user data is empty');
      return;
    }

    int version = map['version'] as int;
    int formatVersion = map['formatVersion'] as int;
    String updateTime = map['updateTime'] as String;
    List<EHUser> users = (map['blockedUsers'] as List).map((map) => (userId: map['userId'] as int, name: map['name'] as String)).toList();

    log.info('Built-in blocked user data loaded, version: $version, formatVersion: $formatVersion, updateTime: $updateTime, user count: ${users.length}');

    _blockedUsers.value = users;

    saveBeanConfig();
  }

  @override
  LocalBlockTargetEnum get target => LocalBlockTargetEnum.comment;

  @override
  Map<String, List<LocalBlockRule>> get extraGroupedRules => preferenceSetting.useBuiltInBlockedUsers.isTrue
      ? {
          'userIdGroup': _blockedUsers
              .map((user) => LocalBlockRule(
                    target: LocalBlockTargetEnum.comment,
                    attribute: LocalBlockAttributeEnum.userId,
                    pattern: LocalBlockPatternEnum.equal,
                    expression: user.userId.toString(),
                  ))
              .toList(),
          'nameGroup': _blockedUsers
              .map((user) => LocalBlockRule(
                    target: LocalBlockTargetEnum.comment,
                    attribute: LocalBlockAttributeEnum.userName,
                    pattern: LocalBlockPatternEnum.equal,
                    expression: user.name,
                  ))
              .toList(),
        }
      : {};
}
