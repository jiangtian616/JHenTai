import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';

import 'onnx_runtime.dart';

enum OnnxModelSource { modelScope, huggingFace, github, gitee }

extension OnnxModelSourceLabel on OnnxModelSource {
  String get displayName => switch (this) {
    OnnxModelSource.modelScope => 'ModelScope',
    OnnxModelSource.huggingFace => 'Hugging Face',
    OnnxModelSource.github => 'GitHub',
    OnnxModelSource.gitee => 'Gitee',
  };
}

enum OnnxModelInstallState { notInstalled, validating, ready, invalid }

/// Versioned, integrity-checked model storage shared by every AI Core domain.
///
/// A model becomes runnable only after every file has the exact manifest size
/// and SHA-256. Downloads are serialized, bounded, staged in a temporary
/// directory, and published by directory rename. A verified marker makes UI
/// readiness checks cheap without weakening the initial validation.
class OnnxModelStore extends GetxController {
  OnnxModelStore._();

  static final OnnxModelStore instance = OnnxModelStore._();

  static const String ocrManifestId = 'rapidocr-ppocrv6-small-multilingual';

  /// Lighter OCR tier of the same PP-OCRv6 family: a reduced dictionary and
  /// smaller det/rec networks — fastest and smallest, lower accuracy on
  /// complex glyphs.
  static const String ocrTinyManifestId = 'rapidocr-ppocrv6-tiny-multilingual';

  static const String superResolutionManifestId = 'realesrgan-x4plus-anime-6b';

  /// Lighter tier of the same anime model family (4 blocks x 32 features vs
  /// 6 x 64), x4, identical [0,1] RGB contract — a fast/light anime preset.
  static const String superResolutionFastManifestId =
      'realesrgan-x4plus-anime-4b32f';

  static const List<OnnxModelManifest> manifests = [
    OnnxModelManifest(
      id: ocrManifestId,
      kind: 'ocr',
      version: 'RapidOCR-v3.9.2-PP-OCRv6-small',
      displayName: 'RapidOCR · PP-OCRv6 small（多语言）',
      description: 'onnxModelDescRapidOcrSmall',
      licenseName: 'Apache-2.0',
      licenseUrl: 'https://github.com/RapidAI/RapidOCR/blob/main/LICENSE',
      sourceProjectUrl: 'https://github.com/RapidAI/RapidOCR',
      files: [
        OnnxModelFile(
          id: 'det',
          fileName: 'PP-OCRv6_det_small.onnx',
          sha256:
              '090f04abcd9d9a7498bc4ebf677e4cb9bdce1fe4197ddb7e529f1ef44e1ff94f',
          sizeBytes: 9929594,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/det/PP-OCRv6_det_small.onnx',
          },
        ),
        OnnxModelFile(
          id: 'rec',
          fileName: 'PP-OCRv6_rec_small.onnx',
          sha256:
              '6f327246b50388f3c176ae304bd95767ea6dc0c9ae92153ef8cbe210b3c14884',
          sizeBytes: 21234383,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/rec/PP-OCRv6_rec_small.onnx',
          },
        ),
        OnnxModelFile(
          id: 'cls',
          fileName: 'ch_ppocr_mobile_v2.0_cls_mobile.onnx',
          sha256:
              'e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c',
          sizeBytes: 585532,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv4/cls/ch_ppocr_mobile_v2.0_cls_mobile.onnx',
          },
        ),
        OnnxModelFile(
          id: 'dict',
          fileName: 'ppocrv6_dict.txt',
          sha256:
              'b5f2bfe2bdd9448429e3e82b51c789775d9b42f2403d082b00662eb77e401c5d',
          sizeBytes: 74947,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/paddle/PP-OCRv6/rec/PP-OCRv6_rec_small/ppocrv6_dict.txt',
          },
        ),
      ],
    ),
    OnnxModelManifest(
      id: ocrTinyManifestId,
      kind: 'ocr',
      version: 'RapidOCR-v3.9.2-PP-OCRv6-tiny',
      displayName: 'RapidOCR · PP-OCRv6 tiny（轻量·多语言）',
      description: 'onnxModelDescRapidOcrTiny',
      licenseName: 'Apache-2.0',
      licenseUrl: 'https://github.com/RapidAI/RapidOCR/blob/main/LICENSE',
      sourceProjectUrl: 'https://github.com/RapidAI/RapidOCR',
      files: [
        OnnxModelFile(
          id: 'det',
          fileName: 'PP-OCRv6_det_tiny.onnx',
          sha256:
              'f42c0fbd294d95eac1a550e131b277dac97462c8025fa4b6c3cec1b7894bd3d5',
          sizeBytes: 1829618,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/det/PP-OCRv6_det_tiny.onnx',
          },
        ),
        OnnxModelFile(
          id: 'rec',
          fileName: 'PP-OCRv6_rec_tiny.onnx',
          sha256:
              'e16e242de5937ad92609223f19bc2aff3727ee40b095f996907c24749bad251b',
          sizeBytes: 4489813,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv6/rec/PP-OCRv6_rec_tiny.onnx',
          },
        ),
        OnnxModelFile(
          id: 'cls',
          fileName: 'ch_ppocr_mobile_v2.0_cls_mobile.onnx',
          sha256:
              'e47acedf663230f8863ff1ab0e64dd2d82b838fceb5957146dab185a89d6215c',
          sizeBytes: 585532,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/onnx/PP-OCRv4/cls/ch_ppocr_mobile_v2.0_cls_mobile.onnx',
          },
        ),
        OnnxModelFile(
          id: 'dict',
          fileName: 'ppocrv6_tiny_dict.txt',
          sha256:
              'c5cbe34ef40c29c4df07ed012bf96569cb69a2d2a01a07027e9f13cb832bd9cd',
          sizeBytes: 27156,
          urls: {
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/v3.9.2/paddle/PP-OCRv6/rec/PP-OCRv6_rec_tiny/ppocrv6_tiny_dict.txt',
          },
        ),
      ],
    ),
    OnnxModelManifest(
      id: superResolutionManifestId,
      kind: 'superResolution',
      version: 'Real-ESRGAN-v0.2.2.4-onnx-deepghs-35e0ed8',
      displayName: 'Real-ESRGAN x4plus-anime-6B',
      description: 'onnxModelDescRealEsrgan6B',
      licenseName: 'BSD-3-Clause',
      licenseUrl: 'https://github.com/xinntao/Real-ESRGAN/blob/master/LICENSE',
      sourceProjectUrl: 'https://github.com/xinntao/Real-ESRGAN',
      files: [
        OnnxModelFile(
          id: 'model',
          fileName: 'RealESRGAN_x4plus_anime_6B.onnx',
          sha256:
              '2648cab4c4343541c1aa291c6754e9e8edbe7a813fffc2a677423dd12cb6b7f7',
          sizeBytes: 17906556,
          urls: {
            // ModelScope first so domestic downloads work out of the box; the
            // byte-identical HuggingFace copy stays as a fallback source.
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/deepghs/imgutils-models/resolve/master/real_esrgan/RealESRGAN_x4plus_anime_6B.onnx',
            OnnxModelSource.huggingFace:
                'https://huggingface.co/deepghs/imgutils-models/resolve/main/real_esrgan/RealESRGAN_x4plus_anime_6B.onnx?download=true',
          },
        ),
      ],
    ),
    OnnxModelManifest(
      id: superResolutionFastManifestId,
      kind: 'superResolution',
      version: 'Real-ESRGAN-v0.2.5.0-anime-4B32F',
      displayName: 'Real-ESRGAN anime 4B32F（快速档）',
      description: 'onnxModelDescRealEsrgan4B32F',
      licenseName: 'BSD-3-Clause',
      licenseUrl: 'https://github.com/xinntao/Real-ESRGAN/blob/master/LICENSE',
      sourceProjectUrl: 'https://github.com/xinntao/Real-ESRGAN',
      files: [
        OnnxModelFile(
          id: 'model',
          fileName: 'RealESRGAN_x4plus_anime_4B32F.onnx',
          sha256:
              '2208c7ae8db793330abf1248fbce15585ad317e921c456265572836b92926c9a',
          sizeBytes: 5156099,
          urls: {
            // ModelScope first so domestic downloads work out of the box; the
            // byte-identical HuggingFace copy stays as a fallback source.
            OnnxModelSource.modelScope:
                'https://www.modelscope.cn/models/deepghs/imgutils-models/resolve/master/real_esrgan/RealESRGAN_x4plus_anime_4B32F.onnx',
            OnnxModelSource.huggingFace:
                'https://huggingface.co/deepghs/imgutils-models/resolve/main/real_esrgan/RealESRGAN_x4plus_anime_4B32F.onnx?download=true',
          },
        ),
      ],
    ),
  ];

  final Rx<LoadingState> downloadState = LoadingState.idle.obs;
  final RxString downloadProgress = ''.obs;
  final RxnString downloadingManifestId = RxnString();
  final RxnString downloadingFileId = RxnString();
  final RxnString lastError = RxnString();
  final RxMap<String, OnnxModelInstallState> installStates =
      <String, OnnxModelInstallState>{}.obs;
  final RxMap<String, OnnxModelSource> selectedSources =
      <String, OnnxModelSource>{}.obs;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
    ),
  );
  Future<void>? _activeDownload;
  CancelToken? _downloadCancelToken;

  Directory rootDir() =>
      Directory(join(pathService.jhOcrModelDir.path, 'onnx'));

  Directory manifestDir(String manifestId) =>
      Directory(join(rootDir().path, manifestId));

  OnnxModelManifest? manifestOf(String manifestId) {
    for (final OnnxModelManifest manifest in manifests) {
      if (manifest.id == manifestId) {
        return manifest;
      }
    }
    return null;
  }

  /// All manifests of [kind] (e.g. 'superResolution'), in catalog order — the
  /// list a model picker offers.
  List<OnnxModelManifest> manifestsOfKind(String kind) =>
      manifests.where((OnnxModelManifest manifest) => manifest.kind == kind).toList();

  List<OnnxModelSource> availableSources(String manifestId) =>
      manifestOf(manifestId)?.availableSources ?? const [];

  OnnxModelSource preferredSource(
    String manifestId, {
    OnnxModelSource? requested,
  }) {
    final List<OnnxModelSource> sources = availableSources(manifestId);
    if (requested != null && sources.contains(requested)) {
      return requested;
    }
    final OnnxModelSource? selected = selectedSources[manifestId];
    if (selected != null && sources.contains(selected)) {
      return selected;
    }
    if (sources.isEmpty) {
      throw StateError('no model source for $manifestId');
    }
    return sources.first;
  }

  void selectSource(String manifestId, OnnxModelSource source) {
    if (!availableSources(manifestId).contains(source)) {
      return;
    }
    selectedSources[manifestId] = source;
    update();
  }

  bool isManifestDownloaded(String manifestId) {
    final OnnxModelManifest? manifest = manifestOf(manifestId);
    if (manifest == null) {
      return false;
    }
    if (installStates[manifestId] == OnnxModelInstallState.invalid ||
        installStates[manifestId] == OnnxModelInstallState.validating) {
      return false;
    }
    final Directory dir = manifestDir(manifestId);
    final File marker = File(join(dir.path, '.verified.json'));
    if (!marker.existsSync()) {
      return false;
    }
    try {
      final Map<String, dynamic> data =
          jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
      if (data['id'] != manifest.id || data['version'] != manifest.version) {
        return false;
      }
      final Map<String, dynamic> hashes = Map<String, dynamic>.from(
        data['sha256'] as Map? ?? const {},
      );
      for (final OnnxModelFile file in manifest.files) {
        final File installed = File(join(dir.path, file.fileName));
        if (!installed.existsSync() ||
            installed.lengthSync() != file.sizeBytes ||
            hashes[file.id] != file.sha256) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String>? manifestFilePaths(String manifestId) {
    final OnnxModelManifest? manifest = manifestOf(manifestId);
    if (manifest == null || !isManifestDownloaded(manifestId)) {
      return null;
    }
    final Directory dir = manifestDir(manifestId);
    return {
      for (final OnnxModelFile file in manifest.files)
        file.id: join(dir.path, file.fileName),
    };
  }

  String? filePath(String manifestId, String fileId) =>
      manifestFilePaths(manifestId)?[fileId];

  String? fingerprintOf(String manifestId) =>
      manifestOf(manifestId)?.fingerprint;

  Future<void> refreshInstalledState() async {
    for (final OnnxModelManifest manifest in manifests) {
      await validateManifest(manifest.id);
    }
  }

  Future<bool> validateManifest(String manifestId) async {
    final OnnxModelManifest? manifest = manifestOf(manifestId);
    if (manifest == null) {
      return false;
    }
    final Directory dir = manifestDir(manifestId);
    if (!await dir.exists()) {
      installStates[manifestId] = OnnxModelInstallState.notInstalled;
      update();
      return false;
    }
    installStates[manifestId] = OnnxModelInstallState.validating;
    update();
    try {
      for (final OnnxModelFile file in manifest.files) {
        final File installed = File(join(dir.path, file.fileName));
        if (!await installed.exists() ||
            await installed.length() != file.sizeBytes ||
            await _sha256Of(installed) != file.sha256) {
          installStates[manifestId] = OnnxModelInstallState.invalid;
          update();
          return false;
        }
      }
      await _writeVerifiedMarker(dir, manifest);
      installStates[manifestId] = OnnxModelInstallState.ready;
      update();
      return true;
    } catch (e, s) {
      log.error('validate ONNX manifest failed: $manifestId', e, s);
      installStates[manifestId] = OnnxModelInstallState.invalid;
      update();
      return false;
    }
  }

  Future<void> downloadManifest(String manifestId, {OnnxModelSource? source}) {
    final Future<void>? active = _activeDownload;
    if (active != null) {
      return Future<void>.error(
        StateError('another ONNX model download is active'),
      );
    }
    final Future<void> task = _downloadManifest(
      manifestId,
      source: preferredSource(manifestId, requested: source),
    );
    _activeDownload = task;
    return task.whenComplete(() {
      if (identical(_activeDownload, task)) {
        _activeDownload = null;
      }
    });
  }

  Future<void> _downloadManifest(
    String manifestId, {
    required OnnxModelSource source,
  }) async {
    final OnnxModelManifest? manifest = manifestOf(manifestId);
    if (manifest == null) {
      throw StateError('unknown ONNX model manifest: $manifestId');
    }
    if (!manifest.availableSources.contains(source)) {
      throw StateError(
        '${source.displayName} is not available for $manifestId',
      );
    }

    await rootDir().create(recursive: true);
    final Directory staging = Directory(
      join(
        rootDir().path,
        '.${manifest.id}.staging-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await staging.create(recursive: true);
    final CancelToken cancelToken = CancelToken();
    _downloadCancelToken = cancelToken;
    downloadState.value = LoadingState.loading;
    downloadingManifestId.value = manifestId;
    downloadProgress.value = '0%';
    lastError.value = null;
    update();

    try {
      int completedBytes = 0;
      final int totalBytes = manifest.totalBytes;
      for (final OnnxModelFile file in manifest.files) {
        downloadingFileId.value = file.id;
        update();
        final String url = file.urls[source]!;
        final File target = File(join(staging.path, file.fileName));
        final Response<ResponseBody> response = await _dio.get<ResponseBody>(
          url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus:
                (int? status) =>
                    status != null && status >= 200 && status < 400,
          ),
        );
        final IOSink sink = target.openWrite();
        int received = 0;
        try {
          await for (final List<int> chunk in response.data!.stream) {
            received += chunk.length;
            if (received > file.sizeBytes) {
              throw StateError('model exceeds declared size: ${file.fileName}');
            }
            sink.add(chunk);
            final int overall = completedBytes + received;
            downloadProgress.value =
                '${(overall / totalBytes * 100).toStringAsFixed(1)}%';
            update();
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (received != file.sizeBytes) {
          throw StateError(
            'model size mismatch: ${file.fileName}, $received != ${file.sizeBytes}',
          );
        }
        final String digest = await _sha256Of(target);
        if (digest != file.sha256) {
          throw StateError('model SHA-256 mismatch: ${file.fileName}');
        }
        completedBytes += received;
      }

      await _writeVerifiedMarker(staging, manifest);
      final Directory destination = manifestDir(manifest.id);
      final Directory backup = Directory('${destination.path}.backup');
      await OnnxRuntime.instance.withPathsInvalidated<void>(
        manifest.files.map(
          (OnnxModelFile file) => join(destination.path, file.fileName),
        ),
        () async {
          if (await backup.exists()) {
            await backup.delete(recursive: true);
          }
          if (await destination.exists()) {
            await destination.rename(backup.path);
          }
          try {
            await staging.rename(destination.path);
            if (await backup.exists()) {
              await backup.delete(recursive: true);
            }
          } catch (_) {
            if (!await destination.exists() && await backup.exists()) {
              await backup.rename(destination.path);
            }
            rethrow;
          }
        },
      );
      installStates[manifestId] = OnnxModelInstallState.ready;
      downloadState.value = LoadingState.success;
      log.info(
        'ONNX model installed: ${manifest.displayName} from ${source.displayName}',
      );
    } on DioException catch (e, s) {
      final String message =
          CancelToken.isCancel(e)
              ? 'download cancelled'
              : (e.message ?? e.toString());
      lastError.value = message;
      downloadState.value = LoadingState.error;
      log.error('ONNX model download failed: $manifestId', e, s);
      rethrow;
    } catch (e, s) {
      lastError.value = e.toString();
      downloadState.value = LoadingState.error;
      log.error('ONNX model download failed: $manifestId', e, s);
      rethrow;
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      if (identical(_downloadCancelToken, cancelToken)) {
        _downloadCancelToken = null;
      }
      downloadingManifestId.value = null;
      downloadingFileId.value = null;
      update();
    }
  }

  void cancelDownload() {
    _downloadCancelToken?.cancel('cancelled by user');
  }

  Future<void> deleteManifest(String manifestId) async {
    if (downloadingManifestId.value == manifestId) {
      cancelDownload();
      try {
        await _activeDownload;
      } catch (_) {}
    }
    final OnnxModelManifest? manifest = manifestOf(manifestId);
    final Directory dir = manifestDir(manifestId);
    if (manifest != null) {
      await OnnxRuntime.instance.withPathsInvalidated<void>(
        manifest.files.map(
          (OnnxModelFile file) => join(dir.path, file.fileName),
        ),
        () async {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        },
      );
    } else if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    installStates[manifestId] = OnnxModelInstallState.notInstalled;
    update();
  }

  Future<String> _sha256Of(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<void> _writeVerifiedMarker(
    Directory dir,
    OnnxModelManifest manifest,
  ) async {
    final File marker = File(join(dir.path, '.verified.json'));
    final File temporary = File('${marker.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'id': manifest.id,
        'version': manifest.version,
        'sha256': {
          for (final OnnxModelFile file in manifest.files) file.id: file.sha256,
        },
      }),
      flush: true,
    );
    if (await marker.exists()) {
      await marker.delete();
    }
    await temporary.rename(marker.path);
  }
}

class OnnxModelManifest {
  const OnnxModelManifest({
    required this.id,
    required this.kind,
    required this.version,
    required this.displayName,
    required this.description,
    required this.licenseName,
    required this.licenseUrl,
    required this.sourceProjectUrl,
    required this.files,
  });

  final String id;
  final String kind;
  final String version;
  final String displayName;

  /// i18n key describing how this tier differs from the others (speed, size,
  /// accuracy). Shown under the model name in the model picker.
  final String description;

  final String licenseName;
  final String licenseUrl;
  final String sourceProjectUrl;
  final List<OnnxModelFile> files;

  int get totalBytes => files.fold<int>(
    0,
    (int total, OnnxModelFile file) => total + file.sizeBytes,
  );

  String get fingerprint =>
      '$id@$version:${files.map((OnnxModelFile file) => file.sha256).join(':')}';

  List<OnnxModelSource> get availableSources => OnnxModelSource.values
      .where(
        (OnnxModelSource source) =>
            files.every((OnnxModelFile file) => file.urls.containsKey(source)),
      )
      .toList(growable: false);
}

class OnnxModelFile {
  const OnnxModelFile({
    required this.id,
    required this.fileName,
    required this.sha256,
    required this.sizeBytes,
    required this.urls,
  });

  final String id;
  final String fileName;
  final String sha256;
  final int sizeBytes;
  final Map<OnnxModelSource, String> urls;
}
