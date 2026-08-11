import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:extended_image/extended_image.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/engine/engine.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/utils/eh_executor.dart';
import 'package:jhentai/src/utils/image_cache_util.dart';
import 'package:path/path.dart' as path;

typedef ReaderPageUpscaleRunner =
    Future<String> Function(String inputPath, String outputPath);
typedef ReaderPageSourceResolver =
    Future<String?> Function(
      ReadMode mode,
      GalleryImage image,
      String galleryKey,
    );

/// Reader-owned single-page orchestration. It uses the existing engine
/// contract and pauses queued whole-gallery work before scheduling a page at a
/// higher priority; model loading/inference stays inside the existing adapter.
class ReaderPageSuperResolutionService {
  ReaderPageSuperResolutionService({
    ReaderPageUpscaleRunner? runner,
    ReaderPageSourceResolver? sourceResolver,
    String? cacheDirectoryPath,
  }) : _runner = runner ?? _runWithRegisteredEngine,
       _sourceResolver = sourceResolver,
       _cacheDirectoryPath = cacheDirectoryPath;

  final ReaderPageUpscaleRunner _runner;
  final ReaderPageSourceResolver? _sourceResolver;
  final String? _cacheDirectoryPath;
  final EHExecutor _executor = EHExecutor(concurrency: 1);

  Future<String?> upscale({
    required String galleryKey,
    required int pageIndex,
    required ReadMode mode,
    required GalleryImage image,
  }) async {
    final String outputPath = outputPathFor(
      galleryKey: galleryKey,
      pageIndex: pageIndex,
      image: image,
    );
    final File output = File(outputPath);
    if (await output.exists() && await output.length() > 0) {
      return outputPath;
    }

    final String? inputPath = await (_sourceResolver ?? _resolveSource)(
      mode,
      image,
      galleryKey,
    );
    if (inputPath == null) return null;

    try {
      await superResolutionService.pauseAllForReaderPage();
      return await _executor.scheduleTask(
        -100,
        () => _runner(inputPath, outputPath),
      );
    } on Object {
      return null;
    }
  }

  Future<void> dispose() => _executor.close();

  String outputPathFor({
    required String galleryKey,
    required int pageIndex,
    required GalleryImage image,
  }) {
    final String sourceIdentity =
        '${image.imageHash ?? image.url}|${image.path ?? ''}';
    final String key =
        sha256
            .convert('$galleryKey|$pageIndex|$sourceIdentity'.codeUnits)
            .toString();
    return path.join(
      _cacheDirectoryPath ?? pathService.tempDir.path,
      'reader-super-resolution',
      '$key.png',
    );
  }

  Future<String?> _resolveSource(
    ReadMode mode,
    GalleryImage image,
    String galleryKey,
  ) async {
    if (image.path != null) {
      final String sourcePath = switch (mode) {
        ReadMode.downloaded =>
          GalleryDownloadService.computeImageDownloadAbsolutePathFromRelativePath(
            image.path!,
          ),
        ReadMode.archive || ReadMode.local => path.join(
          pathService.getVisibleDir().path,
          image.path!,
        ),
        ReadMode.online => image.path!,
      };
      if (await File(sourcePath).exists()) return sourcePath;
    }
    if (mode != ReadMode.online || image.url.isEmpty) return null;

    final bytes = await getNetworkImageData(effectiveEHImageUrl(image.url));
    if (bytes == null || bytes.isEmpty) return null;
    final String inputPath = path.join(
      _cacheDirectoryPath ?? pathService.tempDir.path,
      'reader-super-resolution',
      'inputs',
      '${sha256.convert('$galleryKey|${image.url}'.codeUnits)}.input',
    );
    final File input = File(inputPath);
    await input.parent.create(recursive: true);
    if (!await input.exists()) {
      await input.writeAsBytes(bytes, flush: true);
    }
    return input.path;
  }

  static Future<String> _runWithRegisteredEngine(
    String inputPath,
    String outputPath,
  ) async {
    final SuperResolutionEngine? engine = engineRegistry.findSuperResolution(
      'onnx-super-resolution',
    );
    if (engine == null || !engine.isReady) {
      throw StateError('Reader page super-resolution engine is unavailable');
    }
    final EngineTask<String> task = engine.upscale(
      ImageProcessingRequest(imagePath: inputPath, outputPath: outputPath),
      scale: 4,
    );
    return task.future;
  }
}

ReaderPageSuperResolutionService readerPageSuperResolutionService =
    ReaderPageSuperResolutionService();
