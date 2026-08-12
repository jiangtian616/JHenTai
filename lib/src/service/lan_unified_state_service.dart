import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/database/dao/gallery_history_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/lan_unified_state.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/history_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';

LanUnifiedStateService lanUnifiedStateService = LanUnifiedStateService();

class LanUnifiedStateService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String statusChangedId = 'lanUnifiedStateStatus';
  static const String _stateConfigPrefix = 'record::';

  final HistoryService _historyService;
  final LocalConfigService _localConfigService;
  final DateTime Function() _clock;
  final List<LanUnifiedSyncStatus> statuses = <LanUnifiedSyncStatus>[];

  LanUnifiedStateService({
    HistoryService? historyService,
    LocalConfigService? localConfigService,
    DateTime Function()? clock,
  }) : _historyService = historyService ?? historyServiceGlobal,
       _localConfigService = localConfigService ?? localConfigServiceGlobal,
       _clock = clock ?? DateTime.now;

  @override
  List<JHLifeCircleBean> get initDependencies => [
    _historyService,
    _localConfigService,
    ehRequest,
    userSetting,
  ];

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<LanUnifiedStatePayload> exportHistory({
    required String sourceDeviceId,
    Iterable<LanUnifiedRecord> bookmarks = const <LanUnifiedRecord>[],
  }) async {
    try {
      final List<LanUnifiedRecord> current = await _readCurrentRecords(
        sourceDeviceId,
      );
      final List<LanUnifiedRecord> stored = await _readStoredRecords();
      final List<LanUnifiedRecord> records = LanUnifiedStateMerger.merge(
        current,
        <LanUnifiedRecord>[...stored, ...bookmarks],
      );
      final LanUnifiedStatePayload payload = LanUnifiedStatePayload(
        capability: 'applicationHistoryV1',
        sourceDeviceId: sourceDeviceId,
        generatedAt: _clock().toUtc(),
        records: records,
      );
      payload.toJson();
      _recordStatus(
        sourceDeviceId: sourceDeviceId,
        type: 'applicationHistory',
        count: records.length,
      );
      log.info(
        'LAN export history: ${records.length} records for $sourceDeviceId',
      );
      return payload;
    } on Object catch (error) {
      _recordStatus(
        sourceDeviceId: sourceDeviceId,
        type: 'applicationHistory',
        count: 0,
        failureReason: _safeFailure(error),
      );
      log.warning('LAN export history failed: $error');
      rethrow;
    }
  }

  Future<int> importHistory(LanUnifiedStatePayload payload) async {
    if (payload.capability != 'applicationHistoryV1') {
      throw const FormatException('LAN payload is not application history');
    }
    payload.toJson();
    try {
      final List<LanUnifiedRecord> merged = LanUnifiedStateMerger.merge(
        <LanUnifiedRecord>[
          ...await _readCurrentRecords('local'),
          ...await _readStoredRecords(),
        ],
        payload.records,
      );
      final List<GalleryHistoryV2Data> galleries = <GalleryHistoryV2Data>[];
      for (final LanUnifiedRecord record in merged) {
        await _materializeRecord(record, galleries);
      }
      await GalleryHistoryDao.batchReplaceHistory(galleries);
      _recordStatus(
        sourceDeviceId: payload.sourceDeviceId,
        type: 'applicationHistory',
        count: payload.records.length,
      );
      log.info(
        'LAN import history: ${payload.records.length} records from '
        '${payload.sourceDeviceId}',
      );
      return payload.records.length;
    } on Object catch (error) {
      _recordStatus(
        sourceDeviceId: payload.sourceDeviceId,
        type: 'applicationHistory',
        count: 0,
        failureReason: _safeFailure(error),
      );
      log.warning('LAN import history failed: $error');
      rethrow;
    }
  }

  Future<LanLoginStateSnapshot?> exportLoginState({
    required String sourceDeviceId,
  }) async {
    if (!userSetting.hasLoggedIn()) {
      _recordStatus(
        sourceDeviceId: sourceDeviceId,
        type: 'loginState',
        count: 0,
        failureReason: 'source_not_logged_in',
      );
      log.info('LAN export login state skipped: source not logged in');
      return null;
    }
    final List<Cookie> cookies = ehRequest.cookies.toList();
    if (!CookieUtil.validateCookies(cookies)) {
      _recordStatus(
        sourceDeviceId: sourceDeviceId,
        type: 'loginState',
        count: 0,
        failureReason: 'source_cookie_invalid',
      );
      log.warning('LAN export login state skipped: source cookie invalid');
      return null;
    }
    final LanLoginStateSnapshot snapshot = LanLoginStateSnapshot(
      sites: const <String>['eh', 'jh'],
      accountId: userSetting.ipbMemberId.value!,
      cookies:
          cookies
              .where(
                (cookie) => cookie.name != 'nw' && cookie.name != 'datatags',
              )
              // `Cookie.toString()` renders attributes like "; HttpOnly",
              // which the import side's `parse2Cookies` cannot round-trip.
              // Export plain name=value pairs instead.
              .map((cookie) => '${cookie.name}=${cookie.value}')
              .toList(),
      exportedAt: _clock().toUtc(),
    );
    _recordStatus(sourceDeviceId: sourceDeviceId, type: 'loginState', count: 1);
    log.info(
      'LAN export login state: account ${snapshot.accountId}, '
      '${snapshot.cookies.length} cookies for $sourceDeviceId',
    );
    return snapshot;
  }

  Future<LanLoginImportResult> importLoginState(
    LanLoginStateSnapshot snapshot,
  ) async {
    final String incomingAccount = snapshot.accountId.toString();
    final String? currentAccount = userSetting.ipbMemberId.value?.toString();
    if (currentAccount != null && currentAccount != incomingAccount) {
      _recordStatus(
        sourceDeviceId: '',
        type: 'loginState',
        count: 0,
        failureReason: 'different_account',
      );
      log.warning(
        'LAN import login state rejected: incoming account $incomingAccount '
        'differs from local $currentAccount',
      );
      return const LanLoginImportResult(
        LanLoginImportOutcome.rejectedDifferentAccount,
        failureReason: 'different_account',
      );
    }
    final List<Cookie> incomingCookies;
    try {
      incomingCookies = CookieUtil.parse2Cookies(snapshot.cookies.join('; '));
      if (snapshot.accountId <= 0 ||
          !CookieUtil.validateCookies(incomingCookies)) {
        throw const FormatException('Invalid login cookie');
      }
    } on Object catch (error) {
      _recordStatus(
        sourceDeviceId: '',
        type: 'loginState',
        count: 0,
        failureReason: 'invalid_cookie',
      );
      log.warning(
        'LAN import login state rejected: invalid cookie '
        '(account ${snapshot.accountId})',
      );
      log.trace(error);
      return const LanLoginImportResult(
        LanLoginImportOutcome.invalidCookie,
        failureReason: 'invalid_cookie',
      );
    }

    final List<Cookie> oldCookies = ehRequest.cookies.toList();
    try {
      await ehRequest.storeEHCookies(incomingCookies);
      log.info(
        'LAN import login state: revalidating account ${snapshot.accountId} '
        'against EH forums',
      );
      // Best-effort revalidation: the whole point of LAN login sync is that an
      // offline device adopts a trusted peer's session. If the forums request
      // fails because the network is unreachable (offline phone, Cloudflare
      // block), adopt the peer's cookies anyway — they were exported from a
      // trusted, logged-in host. Only a *reachable* page that proves the
      // cookies are invalid (profile == null) rejects the import.
      Map<String, String?>? profile;
      try {
        profile = await ehRequest.requestForum(
          snapshot.accountId,
          EHSpiderParser.profilePage2UserInfo,
        );
      } on Object catch (error) {
        log.warning(
          'LAN import login state revalidation unavailable '
          '(offline/blocked), adopting trusted peer cookies anyway: $error',
        );
        profile = const <String, String?>{};
      }
      if (profile == null) {
        throw const FormatException('Cookie revalidation failed');
      }
      final String passHash =
          incomingCookies
              .firstWhere((cookie) => cookie.name == 'ipb_pass_hash')
              .value;
      final String displayName = profile['userName'] ?? 'EHUser';
      await userSetting.saveUserInfo(
        userName: displayName,
        ipbMemberId: snapshot.accountId,
        ipbPassHash: passHash,
      );
      await userSetting.saveUserNameAndAvatarAndNickName(
        userName: displayName,
        avatarImgUrl: profile['avatarImgUrl'],
        nickName: profile['nickName'] ?? displayName,
      );
      _recordStatus(
        sourceDeviceId: '',
        type: 'loginState',
        count: 1,
        failureReason: currentAccount == null ? null : 'refreshed',
      );
      log.info(
        'LAN import login state ${currentAccount == null ? 'imported' : 'refreshed'}: '
        'account ${snapshot.accountId}, user $displayName',
      );
      return LanLoginImportResult(
        currentAccount == null
            ? LanLoginImportOutcome.imported
            : LanLoginImportOutcome.refreshed,
      );
    } on Object catch (error) {
      await ehRequest.removeAllCookies();
      if (oldCookies.isNotEmpty) {
        await ehRequest.storeEHCookies(oldCookies);
      }
      _recordStatus(
        sourceDeviceId: '',
        type: 'loginState',
        count: 0,
        failureReason: _safeFailure(error),
      );
      log.warning(
        'LAN import login state failed, cookies rolled back: '
        '${_safeFailure(error)}',
      );
      return LanLoginImportResult(
        LanLoginImportOutcome.invalidCookie,
        failureReason: _safeFailure(error),
      );
    }
  }

  Future<void> saveBookmarkRecord(LanUnifiedRecord record) async {
    if (record.type != LanUnifiedRecordType.bookmark) {
      throw ArgumentError.value(record.type, 'record', 'Expected bookmark');
    }
    await _localConfigService.write(
      configKey: ConfigEnum.lanUnifiedState,
      subConfigKey: '$_stateConfigPrefix${record.storageKey}',
      value: jsonEncode(record.toJson()),
    );
  }

  Future<List<LanUnifiedRecord>> _readCurrentRecords(
    String sourceDeviceId,
  ) async {
    final List<LanUnifiedRecord> records = <LanUnifiedRecord>[];
    final List<GalleryHistoryV2Data> histories =
        await _historyService.getLatest10000RawHistory();
    for (final GalleryHistoryV2Data history in histories) {
      records.add(
        LanUnifiedRecord(
          type: LanUnifiedRecordType.galleryHistory,
          key: history.gid.toString(),
          updatedAt: _parseTime(history.lastReadTime),
          tombstone: false,
          value: <String, dynamic>{'jsonBody': history.jsonBody},
          sourceDeviceId: sourceDeviceId,
        ),
      );
    }
    final List<LocalConfig> progress = await _localConfigService
        .readWithAllSubKeys(configKey: ConfigEnum.readIndexRecord);
    for (final LocalConfig item in progress) {
      final int? index = int.tryParse(item.value);
      if (index == null || item.subConfigKey.isEmpty) {
        continue;
      }
      records.add(
        LanUnifiedRecord(
          type: LanUnifiedRecordType.readProgress,
          key: item.subConfigKey,
          updatedAt: _parseTime(item.utime),
          tombstone: false,
          value: <String, dynamic>{'index': index},
          sourceDeviceId: sourceDeviceId,
        ),
      );
    }
    return records;
  }

  Future<List<LanUnifiedRecord>> _readStoredRecords() async {
    final List<LocalConfig> items = await _localConfigService
        .readWithAllSubKeys(configKey: ConfigEnum.lanUnifiedState);
    return items
        .where((item) => item.subConfigKey.startsWith(_stateConfigPrefix))
        .map((item) {
          try {
            return LanUnifiedRecord.fromJson(
              jsonDecode(item.value) as Map<String, dynamic>,
            );
          } on Object {
            return null;
          }
        })
        .whereType<LanUnifiedRecord>()
        .toList();
  }

  Future<void> _materializeRecord(
    LanUnifiedRecord record,
    List<GalleryHistoryV2Data> galleries,
  ) async {
    if (record.type == LanUnifiedRecordType.galleryHistory) {
      final int? gid = int.tryParse(record.key);
      final String? jsonBody = record.value['jsonBody'] as String?;
      if (gid == null || (jsonBody == null && !record.tombstone)) {
        throw const FormatException('Invalid gallery history record');
      }
      if (record.tombstone) {
        await GalleryHistoryDao.deleteHistory(gid);
      } else {
        galleries.add(
          GalleryHistoryV2Data(
            gid: gid,
            jsonBody: jsonBody!,
            lastReadTime: record.updatedAt.toString(),
          ),
        );
      }
    } else if (record.type == LanUnifiedRecordType.readProgress) {
      if (record.tombstone) {
        await _localConfigService.delete(
          configKey: ConfigEnum.readIndexRecord,
          subConfigKey: record.key,
        );
      } else {
        final int? index = (record.value['index'] as num?)?.toInt();
        if (index == null) {
          throw const FormatException('Invalid read progress record');
        }
        await _localConfigService.write(
          configKey: ConfigEnum.readIndexRecord,
          subConfigKey: record.key,
          value: index.toString(),
        );
      }
    }
    await _localConfigService.write(
      configKey: ConfigEnum.lanUnifiedState,
      subConfigKey: '$_stateConfigPrefix${record.storageKey}',
      value: jsonEncode(record.toJson()),
    );
  }

  DateTime _parseTime(String value) =>
      DateTime.tryParse(value)?.toUtc() ??
      DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);

  void _recordStatus({
    required String sourceDeviceId,
    required String type,
    required int count,
    String? failureReason,
  }) {
    statuses.insert(
      0,
      LanUnifiedSyncStatus(
        sourceDeviceId: sourceDeviceId,
        type: type,
        at: _clock().toUtc(),
        count: count,
        failureReason: failureReason,
      ),
    );
    if (statuses.length > 20) {
      statuses.removeRange(20, statuses.length);
    }
    update([statusChangedId]);
  }

  String _safeFailure(Object error) {
    final String text = error.toString();
    if (text.contains('ipb_pass_hash') || text.contains('Cookie')) {
      return 'sync_failed';
    }
    return text.length > 160 ? text.substring(0, 160) : text;
  }
}

// Aliases make constructor injection in tests explicit while retaining the
// app's existing global-service convention.
final HistoryService historyServiceGlobal = historyService;
final LocalConfigService localConfigServiceGlobal = localConfigService;
