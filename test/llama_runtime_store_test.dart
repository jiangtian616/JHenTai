import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/engine/llama_runtime_store.dart';
import 'package:jhentai/src/service/engine/model_catalog.dart';
import 'package:path/path.dart' as p;

void main() {
  test('managed runtime catalog covers supported desktop architectures', () {
    for (final String platform in <String>['macos', 'linux', 'windows']) {
      for (final String architecture in <String>['arm64', 'x64']) {
        final LlamaRuntimeArtifact? artifact = selectLlamaRuntimeArtifact(
          operatingSystem: platform,
          architecture: architecture,
        );
        expect(artifact, isNotNull);
        expect(artifact!.url.host, 'github.com');
        expect(artifact.sha256, hasLength(64));
        expect(artifact.sizeBytes, greaterThan(0));
      }
    }
    expect(
      selectLlamaRuntimeArtifact(
        operatingSystem: 'android',
        architecture: 'arm64',
      ),
      isNull,
    );
  });

  test(
    'download verifies and installs a managed llama-server archive',
    () async {
      final Directory root = await Directory.systemTemp.createTemp(
        'jhentai-llama-runtime-',
      );
      final ArchiveFile link =
          ArchiveFile('llama-b9637/libllama.so', 0, null)
            ..isFile = false
            ..isSymbolicLink = true
            ..nameOfLinkedFile = 'libllama.so.0';
      final Archive archive =
          Archive()
            ..addFile(
              ArchiveFile('llama-b9637/llama-server', 6, <int>[
                1,
                2,
                3,
                4,
                5,
                6,
              ]),
            )
            ..addFile(ArchiveFile('llama-b9637/libllama.so.0', 1, <int>[7]))
            ..addFile(link);
      final List<int> tar = TarEncoder().encode(archive);
      final List<int> payload = GZipEncoder().encode(tar)!;
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      server.listen((HttpRequest request) async {
        request.response.add(payload);
        await request.response.close();
      });
      final LlamaRuntimeArtifact artifact = LlamaRuntimeArtifact(
        id: 'test-runtime',
        url: Uri.parse('http://127.0.0.1:${server.port}/runtime.tar.gz'),
        sha256: sha256.convert(payload).toString(),
        sizeBytes: payload.length,
        archiveType: 'tar.gz',
        executableRelativePath: p.join('llama-b9637', 'llama-server'),
      );
      final LlamaRuntimeStore store = LlamaRuntimeStore(
        rootDirectory: root,
        artifact: artifact,
      );
      try {
        await store.download();
        expect(await store.installState(), ModelInstallState.ready);
        expect(store.managedExecutablePathSync(), isNotNull);
        if (!Platform.isWindows) {
          expect(
            await Link(
              p.join(store.installDirectory.path, 'llama-b9637', 'libllama.so'),
            ).exists(),
            isTrue,
          );
        }
        await store.delete();
        expect(await store.installState(), ModelInstallState.notInstalled);
      } finally {
        await server.close(force: true);
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
  );
}
