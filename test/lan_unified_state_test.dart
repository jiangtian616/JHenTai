import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/model/lan_unified_state.dart';
import 'package:jhentai/src/service/lan_protocol_v2.dart';
import 'package:jhentai/src/service/lan_unified_state_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/cookie_util.dart';

void main() {
  setUpAll(() {
    log.logDirPath = '${Directory.systemTemp.path}/jhentai-lan-test-logs';
  });

  test(
    'same-account login import policy never silently replaces another account',
    () async {
      final int? previous = userSetting.ipbMemberId.value;
      userSetting.ipbMemberId.value = 100;
      final LanLoginImportResult result = await lanUnifiedStateService
          .importLoginState(
            LanLoginStateSnapshot(
              sites: const ['eh', 'jh'],
              accountId: 200,
              cookies: const ['ipb_member_id=200', 'ipb_pass_hash=hash'],
              exportedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      userSetting.ipbMemberId.value = previous;

      expect(result.outcome, LanLoginImportOutcome.rejectedDifferentAccount);
      expect(userSetting.ipbMemberId.value, previous);
    },
  );

  test(
    'newer tombstone wins and prevents an offline older record from reviving',
    () {
      final LanUnifiedRecord tombstone = LanUnifiedRecord(
        type: LanUnifiedRecordType.galleryHistory,
        key: '42',
        updatedAt: DateTime.utc(2026, 1, 2),
        tombstone: true,
        value: const {},
        sourceDeviceId: 'device-b',
      );
      final LanUnifiedRecord oldValue = LanUnifiedRecord(
        type: LanUnifiedRecordType.galleryHistory,
        key: '42',
        updatedAt: DateTime.utc(2026, 1, 1),
        tombstone: false,
        value: const {'jsonBody': '{}'},
        sourceDeviceId: 'device-a',
      );

      final List<LanUnifiedRecord> merged = LanUnifiedStateMerger.merge(
        [tombstone],
        [oldValue],
      );
      expect(merged.single.tombstone, isTrue);
    },
  );

  test(
    'payload guard rejects forbidden secrets while allowing cookie state',
    () {
      final LanUnifiedStatePayload payload = LanUnifiedStatePayload(
        capability: 'applicationHistoryV1',
        sourceDeviceId: 'device-a',
        generatedAt: DateTime.utc(2026, 1, 1),
        records: [
          LanUnifiedRecord(
            type: LanUnifiedRecordType.readProgress,
            key: '42',
            updatedAt: DateTime.utc(2026, 1, 1),
            tombstone: false,
            value: const {'index': 3},
            sourceDeviceId: 'device-a',
          ),
        ],
      );
      expect(payload.toJson()['records'], isNotEmpty);
      expect(
        () => LanUnifiedPayloadGuard.validate({'apiKey': 'must-not-cross-lan'}),
        throwsFormatException,
      );
      expect(
        () => LanUnifiedPayloadGuard.validate({
          'loginState': {
            'cookies': ['ipb_member_id=1'],
          },
        }),
        returnsNormally,
      );
    },
  );

  test(
    'LAN secure record does not expose cookie or history plaintext',
    () async {
      final X25519 algorithm = X25519();
      final SimpleKeyPair client = await algorithm.newKeyPair();
      final SimpleKeyPair server = await algorithm.newKeyPair();
      final SimplePublicKey clientPublic = await client.extractPublicKey();
      final SimplePublicKey serverPublic = await server.extractPublicKey();
      final List<int> clientNonce = List<int>.filled(32, 1);
      final List<int> serverNonce = List<int>.filled(32, 2);
      final List<int> transcript = utf8.encode('lan-unified-state-test');
      final LanSecureSession session = await LanSecureSession.derive(
        localEphemeralKeyPair: client,
        remoteEphemeralPublicKey: serverPublic,
        clientNonce: clientNonce,
        serverNonce: serverNonce,
        transcript: transcript,
        isClient: true,
      );
      final Map<String, dynamic> record = await session.encrypt({
        'type': 'request',
        'op': 'login_state',
        'params': {
          'cookie': 'ipb_pass_hash=super-secret-cookie',
          'history': 'gallery title and private progress',
        },
      });
      final String wire = jsonEncode(record);
      expect(wire, isNot(contains('super-secret-cookie')));
      expect(wire, isNot(contains('gallery title and private progress')));
      expect(record['v'], LanProtocolV2.version);
      session.close();
      client.destroy();
      server.destroy();
      expect(clientPublic.bytes, hasLength(32));
    },
  );

  test(
    'login and history capabilities are separate from legacy permissions',
    () {
      expect(LanProtocolV2.capabilities, contains('loginStateV1'));
      expect(LanProtocolV2.capabilities, contains('applicationHistoryV1'));
      expect(
        LanSharePermission.values,
        contains(LanSharePermission.loginState),
      );
      expect(
        LanSharePermission.values,
        contains(LanSharePermission.applicationHistory),
      );
    },
  );

  test(
    'revoking unified permissions removes both permissions before reconnect',
    () {
      final TrustedLanDevice device = TrustedLanDevice(
        deviceId: 'device-revoke',
        displayName: 'peer',
        identityPublicKey: 'public-key',
        identityFingerprint: 'fingerprint',
        permissions: const {
          LanSharePermission.loginState,
          LanSharePermission.applicationHistory,
        },
        autoConnect: true,
        pairedAt: DateTime.utc(2026, 1, 1),
        lastSeenAt: DateTime.utc(2026, 1, 1),
      );
      final TrustedLanDevice revoked = device.copyWith(permissions: const {});
      expect(revoked.permissions, isEmpty);
      expect(revoked.toJson()['permissions'], isEmpty);
    },
  );

  test(
    'login cookies export as name=value pairs the import parser can round-trip',
    () {
      // The app stores cookies with Set-Cookie attributes. `Cookie.toString()`
      // renders them back with "; HttpOnly", which `parse2Cookies` cannot
      // split (a bare attribute token breaks the parser), so login import
      // failed with `invalidCookie` unless the export uses plain pairs.
      final List<Cookie> cookies = [
        Cookie.fromSetCookieValue('ipb_member_id=7998183; HttpOnly'),
        Cookie.fromSetCookieValue('ipb_pass_hash=abc123; HttpOnly'),
        Cookie.fromSetCookieValue('sk=xyz; HttpOnly'),
      ];

      // Old export format — attributes leak into the wire and break parsing.
      final List<Cookie> legacyParsed = CookieUtil.parse2Cookies(
        cookies.map((cookie) => cookie.toString()).join('; '),
      );
      expect(CookieUtil.validateCookies(legacyParsed), isFalse);

      // New export format — plain name=value pairs survive the round-trip.
      final List<Cookie> fixedParsed = CookieUtil.parse2Cookies(
        cookies
            .where((cookie) => cookie.name != 'nw' && cookie.name != 'datatags')
            .map((cookie) => '${cookie.name}=${cookie.value}')
            .join('; '),
      );
      expect(CookieUtil.validateCookies(fixedParsed), isTrue);
      expect(fixedParsed.map((cookie) => cookie.name), containsAll([
        'ipb_member_id',
        'ipb_pass_hash',
        'sk',
      ]));
    },
  );
}
