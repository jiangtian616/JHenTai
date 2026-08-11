import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/lan_protocol_v2.dart';

void main() {
  test('negotiates v2 and only the intersection of capabilities', () {
    expect(LanProtocolV2.negotiateVersion(const <int>[1, 2]), 2);
    expect(LanProtocolV2.negotiateVersion(const <int>[1, 7]), 1);
    expect(LanProtocolV2.negotiateVersion(const <int>[7]), isNull);
    expect(
      LanProtocolV2.negotiateCapabilities(const <String>[
        'imageChunkingV1',
        'unknown',
        'secureSessionV2',
      ], LanProtocolV2.capabilities),
      const <String>['imageChunkingV1', 'secureSessionV2'],
    );
  });

  test('X25519 ephemeral keys derive interoperable AEAD sessions', () async {
    final X25519 x25519 = X25519();
    final SimpleKeyPair clientEphemeral = await x25519.newKeyPairFromSeed(
      List<int>.generate(32, (int index) => index + 1),
    );
    final SimpleKeyPair serverEphemeral = await x25519.newKeyPairFromSeed(
      List<int>.generate(32, (int index) => index + 33),
    );
    final SimplePublicKey clientPublic =
        await clientEphemeral.extractPublicKey();
    final SimplePublicKey serverPublic =
        await serverEphemeral.extractPublicKey();
    final List<int> clientNonce = List<int>.generate(32, (int index) => index);
    final List<int> serverNonce = List<int>.generate(
      32,
      (int index) => index + 64,
    );
    final List<int> transcript = utf8.encode('lan-v2-test-transcript');
    final LanSecureSession client = await LanSecureSession.derive(
      localEphemeralKeyPair: clientEphemeral,
      remoteEphemeralPublicKey: serverPublic,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      transcript: transcript,
      isClient: true,
    );
    final LanSecureSession server = await LanSecureSession.derive(
      localEphemeralKeyPair: serverEphemeral,
      remoteEphemeralPublicKey: clientPublic,
      clientNonce: clientNonce,
      serverNonce: serverNonce,
      transcript: transcript,
      isClient: false,
    );

    final Map<String, dynamic> first = await client.encrypt({
      'type': 'request',
      'op': 'image',
      'url': 'https://e-hentai.org/s/private-metadata',
    });
    expect(first['seq'], 0);
    final Map<String, dynamic> decoded = await server.decrypt(first);
    expect(decoded['op'], 'image');
    expect(server.nextReceiveSequence, 1);

    final Map<String, dynamic> response = await server.encrypt({
      'type': 'response',
      'ok': true,
      'metadata': 'private',
    });
    expect((await client.decrypt(response))['ok'], isTrue);

    client.close();
    server.close();
    clientEphemeral.destroy();
    serverEphemeral.destroy();
  });

  test('rejects replay, gaps and authenticated tampering', () async {
    final X25519 x25519 = X25519();
    final SimpleKeyPair clientEphemeral = await x25519.newKeyPairFromSeed(
      List<int>.filled(32, 3),
    );
    final SimpleKeyPair serverEphemeral = await x25519.newKeyPairFromSeed(
      List<int>.filled(32, 4),
    );
    final SimplePublicKey clientPublic =
        await clientEphemeral.extractPublicKey();
    final SimplePublicKey serverPublic =
        await serverEphemeral.extractPublicKey();
    final LanSecureSession client = await LanSecureSession.derive(
      localEphemeralKeyPair: clientEphemeral,
      remoteEphemeralPublicKey: serverPublic,
      clientNonce: List<int>.filled(32, 5),
      serverNonce: List<int>.filled(32, 6),
      transcript: const <int>[1, 2, 3],
      isClient: true,
    );
    final LanSecureSession server = await LanSecureSession.derive(
      localEphemeralKeyPair: serverEphemeral,
      remoteEphemeralPublicKey: clientPublic,
      clientNonce: List<int>.filled(32, 5),
      serverNonce: List<int>.filled(32, 6),
      transcript: const <int>[1, 2, 3],
      isClient: false,
    );
    final Map<String, dynamic> record = await client.encrypt({'type': 'one'});
    await server.decrypt(record);
    await expectLater(
      server.decrypt(record),
      throwsA(isA<LanProtocolException>()),
    );

    final Map<String, dynamic> gap = await client.encrypt({'type': 'two'});
    gap['seq'] = 7;
    await expectLater(
      server.decrypt(gap),
      throwsA(isA<LanProtocolException>()),
    );

    final Map<String, dynamic> tampered = await client.encrypt({
      'type': 'three',
    });
    tampered['ciphertext'] = '${tampered['ciphertext']}A';
    await expectLater(
      server.decrypt(tampered),
      throwsA(isA<LanProtocolException>()),
    );

    client.close();
    server.close();
    clientEphemeral.destroy();
    serverEphemeral.destroy();
  });
}
