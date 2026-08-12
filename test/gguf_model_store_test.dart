import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/engine/gguf_model_store.dart';
import 'package:jhentai/src/service/engine/model_catalog.dart';
import 'package:path/path.dart' as p;

/// A one-model catalog used to drive [GgufModelStore] against a local server.
class _SingleModelCatalog extends ModelCatalog {
  _SingleModelCatalog(this.model);

  final ModelDescriptor model;

  @override
  List<ModelDescriptor> get models => <ModelDescriptor>[model];
}

ModelDescriptor _buildModel(List<int> payload, String sha256Hex, int port) =>
    ModelDescriptor(
      id: 'parallel-test-model',
      kind: 'translation',
      version: 'test@0000000/Q4_K_M',
      displayName: 'Parallel Test Model',
      description: 'Local test model.',
      licenseName: 'Apache-2.0',
      licenseUrl: 'https://example.com/LICENSE',
      sourceProjectUrl: 'https://example.com/model',
      artifacts: <ModelArtifactDescriptor>[
        ModelArtifactDescriptor(
          id: 'parallel-test-model',
          fileName: 'model.gguf',
          sizeBytes: payload.length,
          sha256: sha256Hex,
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'test-source',
              url: 'http://127.0.0.1:$port/model.gguf',
            ),
          ],
        ),
      ],
      engineIds: <String>['llama-server-translation'],
    );

/// A server that honours byte ranges (206), recording the ranges it saw.
Future<HttpServer> _bindRangeServer(
  List<int> payload,
  List<String> requestedRanges,
) async {
  final HttpServer server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  server.listen((HttpRequest request) async {
    final String? range = request.headers.value(HttpHeaders.rangeHeader);
    requestedRanges.add(range ?? '(none)');
    final Match? match = RegExp(r'bytes=(\d+)-(\d+)?').firstMatch(range ?? '');
    if (match == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final int start = int.parse(match.group(1)!);
    final String? endRaw = match.group(2);
    final int end = endRaw == null || endRaw.isEmpty
        ? payload.length - 1
        : int.parse(endRaw);
    final List<int> slice = payload.sublist(start, end + 1);
    request.response.statusCode = HttpStatus.partialContent;
    request.response.contentLength = slice.length;
    request.response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${payload.length}',
    );
    request.response.add(slice);
    await request.response.close();
  });
  return server;
}

void main() {
  test(
    'cancelling a GGUF download stops the body stream instead of waiting '
    'for the full payload', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'jhentai-gguf-cancel-',
    );
    // 512 KiB payload streamed in 4 KiB chunks every 50 ms, so a full
    // download would take several seconds. Cancellation must interrupt it
    // long before then.
    final List<int> payload = List<int>.filled(512 * 1024, 7);
    final String sha256Hex = sha256.convert(payload).toString();
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    server.listen((HttpRequest request) {
      request.response.contentLength = payload.length;
      final int chunkCount = (payload.length / 4096).ceil();
      request.response.addStream(
        Stream<List<int>>.periodic(
          const Duration(milliseconds: 50),
          (int i) => payload.sublist(
            i * 4096,
            ((i + 1) * 4096) < payload.length
                ? (i + 1) * 4096
                : payload.length,
          ),
        ).take(chunkCount),
      ).then((void _) => request.response.close());
    });

    final ModelDescriptor model = ModelDescriptor(
      id: 'cancel-test-model',
      kind: 'translation',
      version: 'test@0000000/Q4_K_M',
      displayName: 'Cancel Test Model',
      description: 'Local test model.',
      licenseName: 'Apache-2.0',
      licenseUrl: 'https://example.com/LICENSE',
      sourceProjectUrl: 'https://example.com/model',
      artifacts: <ModelArtifactDescriptor>[
        ModelArtifactDescriptor(
          id: 'cancel-test-model',
          fileName: 'model.gguf',
          sizeBytes: payload.length,
          sha256: sha256Hex,
          sources: <ModelSourceDescriptor>[
            ModelSourceDescriptor(
              id: 'test-source',
              url: 'http://127.0.0.1:${server.port}/model.gguf',
            ),
          ],
        ),
      ],
      engineIds: <String>['llama-server-translation'],
    );
    final GgufModelStore store = GgufModelStore(
      catalog: _SingleModelCatalog(model),
      rootDirectory: root,
      diskSpaceProbe: (String _) async => 1 << 30,
    );

    try {
      final Future<void> downloadFuture = store.download(model.id);
      // Give the download enough time to open the connection and start
      // streaming the body.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await store.cancel(model.id);
      await expectLater(
        downloadFuture,
        throwsA(isA<GgufModelDownloadCancelled>()),
      );
      expect(await store.installState(model.id), ModelInstallState.notInstalled);
    } finally {
      await server.close(force: true);
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });

  test('parallel download assembles multiple range chunks correctly', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'jhentai-gguf-parallel-',
    );
    // 40 MiB resolves to 2 chunks (16 MiB minimum per chunk, max 4).
    final int size = 40 * 1024 * 1024;
    final List<int> payload = List<int>.generate(
      size,
      (int i) => (i * 31 + 7) & 0xff,
    );
    final String sha256Hex = sha256.convert(payload).toString();
    final List<String> requestedRanges = <String>[];
    final HttpServer server = await _bindRangeServer(payload, requestedRanges);
    final ModelDescriptor model = _buildModel(payload, sha256Hex, server.port);
    final GgufModelStore store = GgufModelStore(
      catalog: _SingleModelCatalog(model),
      rootDirectory: root,
      diskSpaceProbe: (String _) async => 1 << 30,
    );
    try {
      await store.download(model.id);
      expect(await store.installState(model.id), ModelInstallState.ready);
      final List<int> installed = await File(
        p.join(root.path, model.id, 'model.gguf'),
      ).readAsBytes();
      expect(installed.length, size);
      expect(sha256.convert(installed).toString(), sha256Hex);
      expect(requestedRanges.length, 2);
      expect(requestedRanges, contains('bytes=0-20971519'));
      expect(requestedRanges, contains('bytes=20971520-41943039'));
    } finally {
      await server.close(force: true);
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });

  test('an interrupted download resumes from existing chunk parts', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'jhentai-gguf-resume-',
    );
    final int size = 40 * 1024 * 1024;
    final List<int> payload = List<int>.generate(
      size,
      (int i) => (i * 31 + 7) & 0xff,
    );
    final String sha256Hex = sha256.convert(payload).toString();
    final List<String> requestedRanges = <String>[];
    final HttpServer server = await _bindRangeServer(payload, requestedRanges);
    final ModelDescriptor model = _buildModel(payload, sha256Hex, server.port);

    // Simulate a half-finished download: chunk 0 already has its first 5 MiB.
    final Directory partial = Directory(
      p.join(root.path, '.partial', model.id),
    );
    await partial.create(recursive: true);
    await File(p.join(partial.path, 'model.gguf.part.0')).writeAsBytes(
      payload.sublist(0, 5 * 1024 * 1024),
    );

    final GgufModelStore store = GgufModelStore(
      catalog: _SingleModelCatalog(model),
      rootDirectory: root,
      diskSpaceProbe: (String _) async => 1 << 30,
    );
    try {
      await store.download(model.id);
      expect(await store.installState(model.id), ModelInstallState.ready);
      final List<int> installed = await File(
        p.join(root.path, model.id, 'model.gguf'),
      ).readAsBytes();
      expect(sha256.convert(installed).toString(), sha256Hex);
      // Chunk 0 resumed from 5 MiB instead of re-fetching the whole chunk.
      expect(requestedRanges, contains('bytes=5242880-20971519'));
      expect(requestedRanges, contains('bytes=20971520-41943039'));
    } finally {
      await server.close(force: true);
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });
}
