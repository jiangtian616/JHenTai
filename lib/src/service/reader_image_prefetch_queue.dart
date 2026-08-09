import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image_library/extended_image_library.dart';
import 'package:path/path.dart' as path;

import '../utils/image_cache_util.dart';
import 'reader_pipeline_scheduler.dart';

typedef ReaderImagePrefetchDownload = Future<bool> Function(String url);

/// Downloads planned reader images into the same disk cache used by EHImage.
///
/// It intentionally does not decode images. Flutter/EHImage remains the owner
/// of decode and memory-cache work when an item approaches the viewport.
class ReaderImagePrefetchQueue {
  ReaderImagePrefetchQueue({
    ReaderImagePrefetchDownload? downloader,
    int concurrency = 2,
  }) : _downloader = downloader ?? prefetchReaderImageToDisk,
       _concurrency = concurrency < 0 ? 0 : concurrency;

  final ReaderImagePrefetchDownload _downloader;
  final Map<int, _ReaderImagePrefetchJob> _pending =
      <int, _ReaderImagePrefetchJob>{};
  final Map<int, _ReaderImagePrefetchJob> _running =
      <int, _ReaderImagePrefetchJob>{};
  final Set<String> _completedCacheKeys = <String>{};
  final List<Completer<void>> _idleWaiters = <Completer<void>>[];

  int _concurrency;
  int _sequence = 0;
  bool _disposed = false;

  int get concurrency => _concurrency;
  int get pendingCount => _pending.length;
  int get runningCount => _running.length;
  int get completedCount => _completedCacheKeys.length;

  Future<void> get idle {
    if (_pending.isEmpty && _running.isEmpty) {
      return Future<void>.value();
    }
    final Completer<void> completer = Completer<void>();
    _idleWaiters.add(completer);
    return completer.future;
  }

  void configure({required int concurrency}) {
    if (_disposed) {
      return;
    }
    _concurrency = concurrency < 0 ? 0 : concurrency;
    _drain();
  }

  /// Replaces queued work with the current viewport plan.
  ///
  /// Visible images are deliberately excluded because EHImage already owns
  /// their demand load. In-flight downloads are allowed to finish and populate
  /// the shared disk cache; stale queued work is dropped immediately.
  void updatePlan(
    Iterable<MapEntry<int, ReaderPagePriority>> plan,
    String? Function(int imageIndex) urlForIndex,
  ) {
    if (_disposed) {
      return;
    }

    final Set<int> desiredIndices = <int>{};
    final List<_ReaderImagePrefetchJob> candidates =
        <_ReaderImagePrefetchJob>[];
    for (final MapEntry<int, ReaderPagePriority> entry in plan) {
      if (entry.value == ReaderPagePriority.visible) {
        continue;
      }
      final String? rawUrl = urlForIndex(entry.key);
      if (rawUrl == null || rawUrl.trim().isEmpty) {
        continue;
      }
      final String url = effectiveEHImageUrl(rawUrl);
      final String cacheKey = normalizedImageCacheKey(url);
      desiredIndices.add(entry.key);
      candidates.add(
        _ReaderImagePrefetchJob(
          imageIndex: entry.key,
          url: url,
          cacheKey: cacheKey,
          priority: entry.value,
          sequence: _sequence++,
        ),
      );
    }

    _pending.clear();
    final Set<int> runningIndices = _running.keys.toSet();
    final Set<String> activeKeys = <String>{
      ..._running.values.map((job) => job.cacheKey),
    };
    for (final _ReaderImagePrefetchJob candidate in candidates) {
      if (!desiredIndices.contains(candidate.imageIndex) ||
          runningIndices.contains(candidate.imageIndex) ||
          _completedCacheKeys.contains(candidate.cacheKey) ||
          activeKeys.contains(candidate.cacheKey)) {
        continue;
      }
      _pending[candidate.imageIndex] = candidate;
      activeKeys.add(candidate.cacheKey);
    }
    _drain();
  }

  void clear() {
    _pending.clear();
    _completeIdleWaitersIfNeeded();
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
    _completeIdleWaitersIfNeeded();
  }

  void _drain() {
    if (_disposed || _concurrency <= 0) {
      _completeIdleWaitersIfNeeded();
      return;
    }
    while (_running.length < _concurrency && _pending.isNotEmpty) {
      final List<_ReaderImagePrefetchJob> ordered =
          _pending.values.toList()..sort((a, b) {
            final int priority = a.priority.executorPriority.compareTo(
              b.priority.executorPriority,
            );
            return priority != 0 ? priority : a.sequence.compareTo(b.sequence);
          });
      final _ReaderImagePrefetchJob job = ordered.first;
      _pending.remove(job.imageIndex);
      _running[job.imageIndex] = job;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_ReaderImagePrefetchJob job) async {
    bool succeeded = false;
    try {
      succeeded = await _downloader(job.url);
    } catch (_) {
      succeeded = false;
    } finally {
      if (succeeded) {
        _completedCacheKeys.add(job.cacheKey);
      }
      _running.remove(job.imageIndex);
      _drain();
      _completeIdleWaitersIfNeeded();
    }
  }

  void _completeIdleWaitersIfNeeded() {
    if (_pending.isNotEmpty || _running.isNotEmpty) {
      return;
    }
    for (final Completer<void> waiter in _idleWaiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _idleWaiters.clear();
  }
}

/// Fetches compressed image bytes without decoding, then atomically publishes
/// them under EHImage's exact disk-cache key.
Future<bool> prefetchReaderImageToDisk(String rawUrl) async {
  final String url = effectiveEHImageUrl(rawUrl);
  final String cacheKey = normalizedImageCacheKey(url);
  final Directory directory = Directory(
    await getExtendedImageDiskCacheDirectory(),
  );
  await directory.create(recursive: true);
  final File destination = File(path.join(directory.path, cacheKey));
  if (await destination.exists()) {
    return true;
  }

  final ExtendedNetworkImageProvider provider = ExtendedNetworkImageProvider(
    url,
    cache: false,
    cacheKey: cacheKey,
    retries: 1,
    printError: false,
  );
  final Uint8List? bytes = await provider.getNetworkImageData();
  if (bytes == null || bytes.isEmpty) {
    return false;
  }

  final File temporary = File(
    path.join(
      directory.path,
      '.$cacheKey.prefetch-$pid-${DateTime.now().microsecondsSinceEpoch}',
    ),
  );
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    if (await destination.exists()) {
      return true;
    }
    try {
      await temporary.rename(destination.path);
    } on FileSystemException {
      if (!await destination.exists()) {
        rethrow;
      }
    }
    return true;
  } finally {
    if (await temporary.exists()) {
      await temporary.delete();
    }
  }
}

class _ReaderImagePrefetchJob {
  const _ReaderImagePrefetchJob({
    required this.imageIndex,
    required this.url,
    required this.cacheKey,
    required this.priority,
    required this.sequence,
  });

  final int imageIndex;
  final String url;
  final String cacheKey;
  final ReaderPagePriority priority;
  final int sequence;
}
