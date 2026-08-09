import 'dart:async';
import 'dart:io';

import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/reader_image_prefetch_queue.dart';
import 'package:jhentai/src/service/reader_pipeline_scheduler.dart';
import 'package:jhentai/src/utils/image_cache_util.dart';
import 'package:path/path.dart' as path;

void main() {
  tearDown(() => extendedImageDiskCacheDirectory = null);

  test(
    'prefetches nearby before background with bounded concurrency',
    () async {
      final List<String> started = <String>[];
      final Map<String, Completer<bool>> downloads =
          <String, Completer<bool>>{};
      final ReaderImagePrefetchQueue queue = ReaderImagePrefetchQueue(
        concurrency: 1,
        downloader: (String url) {
          started.add(url);
          return (downloads[url] = Completer<bool>()).future;
        },
      );

      queue.updatePlan(const <MapEntry<int, ReaderPagePriority>>[
        MapEntry<int, ReaderPagePriority>(2, ReaderPagePriority.background),
        MapEntry<int, ReaderPagePriority>(1, ReaderPagePriority.nearby),
      ], (int index) => 'https://example.com/$index.jpg');

      expect(started, <String>['https://example.com/1.jpg']);
      expect(queue.runningCount, 1);
      expect(queue.pendingCount, 1);
      downloads[started.first]!.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(started, <String>[
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ]);
      downloads[started.last]!.complete(true);
      await queue.idle;
      expect(queue.completedCount, 2);
    },
  );

  test('drops stale queued work after the viewport plan changes', () async {
    final List<String> started = <String>[];
    final Map<String, Completer<bool>> downloads = <String, Completer<bool>>{};
    final ReaderImagePrefetchQueue queue = ReaderImagePrefetchQueue(
      concurrency: 1,
      downloader: (String url) {
        started.add(url);
        return (downloads[url] = Completer<bool>()).future;
      },
    );

    queue.updatePlan(const <MapEntry<int, ReaderPagePriority>>[
      MapEntry<int, ReaderPagePriority>(1, ReaderPagePriority.nearby),
      MapEntry<int, ReaderPagePriority>(2, ReaderPagePriority.nearby),
    ], (int index) => 'https://example.com/$index.jpg');
    queue.updatePlan(const <MapEntry<int, ReaderPagePriority>>[
      MapEntry<int, ReaderPagePriority>(8, ReaderPagePriority.nearby),
    ], (int index) => 'https://example.com/$index.jpg');

    downloads['https://example.com/1.jpg']!.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(started, <String>[
      'https://example.com/1.jpg',
      'https://example.com/8.jpg',
    ]);
    downloads['https://example.com/8.jpg']!.complete(true);
    await queue.idle;
  });

  test(
    'replaces a queued background job when its priority increases',
    () async {
      final List<String> started = <String>[];
      final Map<String, Completer<bool>> downloads =
          <String, Completer<bool>>{};
      final ReaderImagePrefetchQueue queue = ReaderImagePrefetchQueue(
        concurrency: 1,
        downloader: (String url) {
          started.add(url);
          return (downloads[url] = Completer<bool>()).future;
        },
      );
      queue.updatePlan(const <MapEntry<int, ReaderPagePriority>>[
        MapEntry<int, ReaderPagePriority>(1, ReaderPagePriority.nearby),
        MapEntry<int, ReaderPagePriority>(2, ReaderPagePriority.background),
        MapEntry<int, ReaderPagePriority>(3, ReaderPagePriority.nearby),
      ], (int index) => 'https://example.com/$index.jpg');
      queue.updatePlan(const <MapEntry<int, ReaderPagePriority>>[
        MapEntry<int, ReaderPagePriority>(1, ReaderPagePriority.nearby),
        MapEntry<int, ReaderPagePriority>(2, ReaderPagePriority.nearby),
        MapEntry<int, ReaderPagePriority>(3, ReaderPagePriority.background),
      ], (int index) => 'https://example.com/$index.jpg');

      downloads['https://example.com/1.jpg']!.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(started.last, 'https://example.com/2.jpg');
      downloads['https://example.com/2.jpg']!.complete(true);
      await Future<void>.delayed(Duration.zero);
      downloads['https://example.com/3.jpg']!.complete(true);
      await queue.idle;
    },
  );

  test(
    'reducing concurrency waits for active downloads before new work',
    () async {
      final List<String> started = <String>[];
      final Map<String, Completer<bool>> downloads =
          <String, Completer<bool>>{};
      final ReaderImagePrefetchQueue queue = ReaderImagePrefetchQueue(
        concurrency: 2,
        downloader: (String url) {
          started.add(url);
          return (downloads[url] = Completer<bool>()).future;
        },
      );
      queue.updatePlan(const <MapEntry<int, ReaderPagePriority>>[
        MapEntry<int, ReaderPagePriority>(1, ReaderPagePriority.nearby),
        MapEntry<int, ReaderPagePriority>(2, ReaderPagePriority.nearby),
        MapEntry<int, ReaderPagePriority>(3, ReaderPagePriority.nearby),
      ], (int index) => 'https://example.com/$index.jpg');
      expect(started, hasLength(2));

      queue.configure(concurrency: 1);
      downloads['https://example.com/1.jpg']!.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(started, hasLength(2));

      downloads['https://example.com/2.jpg']!.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(started, hasLength(3));
      downloads['https://example.com/3.jpg']!.complete(true);
      await queue.idle;
    },
  );

  test(
    'disk prefetch publishes into the EHImage cache without decoding',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'reader_prefetch',
      );
      extendedImageDiskCacheDirectory = temp.path;
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      int requests = 0;
      final StreamSubscription<HttpRequest> subscription = server.listen((
        HttpRequest request,
      ) async {
        requests++;
        request.response.statusCode = HttpStatus.ok;
        request.response.add(<int>[1, 2, 3, 4]);
        await request.response.close();
      });
      final String url =
          'http://${server.address.host}:${server.port}/image.jpg';

      try {
        expect(await prefetchReaderImageToDisk(url), isTrue);
        final File cached = File(
          path.join(temp.path, normalizedImageCacheKey(url)),
        );
        expect(await cached.readAsBytes(), <int>[1, 2, 3, 4]);
        expect(await prefetchReaderImageToDisk(url), isTrue);
        expect(requests, 1);
      } finally {
        await subscription.cancel();
        await server.close(force: true);
        await temp.delete(recursive: true);
      }
    },
  );
}
