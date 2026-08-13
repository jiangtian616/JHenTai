import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../utils/archive_util.dart';
import '../path_service.dart';
import 'model_catalog.dart';

class LlamaRuntimeArtifact {
  const LlamaRuntimeArtifact({
    required this.id,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.archiveType,
    required this.executableRelativePath,
  });

  final String id;
  final Uri url;
  final String sha256;
  final int sizeBytes;
  final String archiveType;
  final String executableRelativePath;
}

const String llamaRuntimeVersion = 'b9637';

LlamaRuntimeArtifact? selectLlamaRuntimeArtifact({
  required String operatingSystem,
  required String architecture,
}) {
  const String release =
      'https://github.com/ggml-org/llama.cpp/releases/download/$llamaRuntimeVersion';
  final ({String file, String sha256, int size, String archive})?
  selected = switch ('$operatingSystem-$architecture') {
    'macos-arm64' => (
      file: 'llama-b9637-bin-macos-arm64.tar.gz',
      sha256:
          '72a93f3e68c31de3e438d462669aad1fcdb423b995e9c41033cc7d27a9a3ac69',
      size: 10586927,
      archive: 'tar.gz',
    ),
    'macos-x64' => (
      file: 'llama-b9637-bin-macos-x64.tar.gz',
      sha256:
          '71743f8db0958e7c266cceb7add7b16aa418a964667e471094aa6ae65b9c8298',
      size: 10877158,
      archive: 'tar.gz',
    ),
    'linux-arm64' => (
      file: 'llama-b9637-bin-ubuntu-arm64.tar.gz',
      sha256:
          '211d9e9ee738698beb7ca271be82661ae2b5da3fbb489cf7d9e4e6ed601be106',
      size: 12528190,
      archive: 'tar.gz',
    ),
    'linux-x64' => (
      file: 'llama-b9637-bin-ubuntu-x64.tar.gz',
      sha256:
          'a50ee14f021a9d8e92e30f622f7e3be1318ee1125bb9a9ba8d2025388df48743',
      size: 15512345,
      archive: 'tar.gz',
    ),
    'windows-arm64' => (
      file: 'llama-b9637-bin-win-cpu-arm64.zip',
      sha256:
          'db1d3f4c13c08b693f539e100bf6d3a435148b0ffc186b044fdd65d490cc6df7',
      size: 10846442,
      archive: 'zip',
    ),
    'windows-x64' => (
      file: 'llama-b9637-bin-win-cpu-x64.zip',
      sha256:
          'f7783c2b8c007f95e710ac40f26a24861a80b603b0b739fc54d7c926a4716c1e',
      size: 16906751,
      archive: 'zip',
    ),
    _ => null,
  };
  if (selected == null) {
    return null;
  }
  return LlamaRuntimeArtifact(
    id: '$operatingSystem-$architecture-$llamaRuntimeVersion',
    url: Uri.parse('$release/${selected.file}'),
    sha256: selected.sha256,
    sizeBytes: selected.size,
    archiveType: selected.archive,
    executableRelativePath: p.join(
      'llama-$llamaRuntimeVersion',
      operatingSystem == 'windows' ? 'llama-server.exe' : 'llama-server',
    ),
  );
}

String currentLlamaRuntimeArchitecture() => switch (Abi.current()) {
  Abi.macosArm64 || Abi.windowsArm64 || Abi.linuxArm64 => 'arm64',
  Abi.macosX64 || Abi.windowsX64 || Abi.linuxX64 => 'x64',
  _ => 'unsupported',
};

class LlamaRuntimeStore {
  LlamaRuntimeStore({
    Directory? rootDirectory,
    HttpClient? client,
    LlamaRuntimeArtifact? artifact,
  }) : _rootDirectory = rootDirectory,
       _client = client ?? HttpClient(),
       _artifact = artifact;

  static LlamaRuntimeStore? _instance;

  static LlamaRuntimeStore get instance => _instance ??= LlamaRuntimeStore();

  final Directory? _rootDirectory;
  final HttpClient _client;
  final LlamaRuntimeArtifact? _artifact;
  HttpClientRequest? _activeRequest;
  bool _cancelled = false;

  LlamaRuntimeArtifact? get artifact =>
      _artifact ??
      selectLlamaRuntimeArtifact(
        operatingSystem: Platform.operatingSystem,
        architecture: currentLlamaRuntimeArchitecture(),
      );

  Directory get rootDirectory =>
      _rootDirectory ??
      Directory(
        p.join(pathService.jhTranslationModelDir.path, 'llama-runtime'),
      );

  Directory get installDirectory {
    final LlamaRuntimeArtifact selected = _requireArtifact();
    return Directory(p.join(rootDirectory.path, selected.id));
  }

  String? managedExecutablePathSync() {
    try {
      final LlamaRuntimeArtifact selected = _requireArtifact();
      final File marker = File(p.join(installDirectory.path, 'install.json'));
      final File executable = File(
        p.join(installDirectory.path, selected.executableRelativePath),
      );
      if (!marker.existsSync() || !executable.existsSync()) {
        return null;
      }
      final Map<String, dynamic> record =
          jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
      if (record['artifactId'] != selected.id ||
          record['sha256'] != selected.sha256) {
        return null;
      }
      return executable.path;
    } on Object {
      return null;
    }
  }

  Future<ModelInstallState> installState() async {
    if (artifact == null) {
      return ModelInstallState.invalid;
    }
    return managedExecutablePathSync() == null
        ? ModelInstallState.notInstalled
        : ModelInstallState.ready;
  }

  Future<void> download({void Function(double progress)? onProgress}) async {
    final LlamaRuntimeArtifact selected = _requireArtifact();
    if (await installState() == ModelInstallState.ready) {
      return;
    }
    _cancelled = false;
    await rootDirectory.create(recursive: true);
    final File archive = File(
      p.join(rootDirectory.path, '${selected.id}.${selected.archiveType}.part'),
    );
    if (await archive.exists()) {
      await archive.delete();
    }
    try {
      final HttpClientRequest request = await _client.getUrl(selected.url);
      _activeRequest = request;
      final HttpClientResponse response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'llama.cpp runtime download failed: HTTP ${response.statusCode}',
          uri: selected.url,
        );
      }
      final IOSink sink = archive.openWrite();
      int received = 0;
      try {
        await for (final List<int> chunk in response) {
          if (_cancelled) {
            throw const LlamaRuntimeDownloadCancelled();
          }
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call((received / selected.sizeBytes).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }
      final Digest digest = await sha256.bind(archive.openRead()).first;
      if (digest.toString() != selected.sha256) {
        throw StateError('llama.cpp runtime SHA-256 mismatch.');
      }
      final bool extracted =
          selected.archiveType == 'zip'
              ? await extractZipArchive(archive.path, installDirectory.path)
              : await extractTarGZipArchive(
                archive.path,
                installDirectory.path,
              );
      if (!extracted) {
        throw StateError('Unable to extract the llama.cpp runtime.');
      }
      final File executable = File(
        p.join(installDirectory.path, selected.executableRelativePath),
      );
      if (!await executable.exists()) {
        throw StateError('llama-server was not found in the runtime archive.');
      }
      if (!Platform.isWindows) {
        final ProcessResult chmod = await Process.run('chmod', <String>[
          '+x',
          executable.path,
        ]);
        if (chmod.exitCode != 0) {
          throw StateError('Unable to make llama-server executable.');
        }
      }
      await File(p.join(installDirectory.path, 'install.json')).writeAsString(
        jsonEncode(<String, Object>{
          'artifactId': selected.id,
          'sha256': selected.sha256,
          'source': selected.url.toString(),
        }),
        flush: true,
      );
      onProgress?.call(1);
    } on Object {
      if (_cancelled) {
        throw const LlamaRuntimeDownloadCancelled();
      }
      rethrow;
    } finally {
      _activeRequest = null;
      if (await archive.exists()) {
        await archive.delete();
      }
    }
  }

  void cancel() {
    _cancelled = true;
    _activeRequest?.abort(const LlamaRuntimeDownloadCancelled());
  }

  Future<void> delete() async {
    cancel();
    if (await installDirectory.exists()) {
      await installDirectory.delete(recursive: true);
    }
  }

  LlamaRuntimeArtifact _requireArtifact() {
    final LlamaRuntimeArtifact? selected = artifact;
    if (selected == null) {
      throw UnsupportedError(
        'No managed llama.cpp runtime is available for this platform.',
      );
    }
    return selected;
  }
}

class LlamaRuntimeDownloadCancelled implements Exception {
  const LlamaRuntimeDownloadCancelled();

  @override
  String toString() => 'llama.cpp runtime download cancelled';
}
