import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/model/reader_bookmark.dart';
import 'package:jhentai/src/model/reader_floating_ball_position.dart';
import 'package:jhentai/src/service/reader_action_persistence.dart';
import 'package:jhentai/src/service/reader_bookmark_service.dart';
import 'package:jhentai/src/service/reader_page_super_resolution_service.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';

class _MemoryKeyValueStore implements ReaderActionKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _MemoryBookmarkRepository implements ReaderBookmarkRepository {
  final Map<String, ReaderBookmark> values = <String, ReaderBookmark>{};

  @override
  Future<List<ReaderBookmark>> list(String galleryKey) async =>
      values.values
          .where((bookmark) => bookmark.galleryKey == galleryKey)
          .toList();

  @override
  Future<void> save(ReaderBookmark bookmark) async {
    values['${bookmark.galleryKey}:${bookmark.pageIndex}'] = bookmark;
  }
}

void main() {
  test(
    'floating ball positions are persisted independently by orientation',
    () async {
      final _MemoryKeyValueStore memory = _MemoryKeyValueStore();
      final ReaderFloatingBallPositionStore store =
          ReaderFloatingBallPositionStore(store: memory);

      await store.save(
        Orientation.portrait,
        const ReaderFloatingBallPosition(x: 0, y: 0.25),
      );
      await store.save(
        Orientation.landscape,
        const ReaderFloatingBallPosition(x: 1, y: 0.75),
      );

      expect(
        await store.load(Orientation.portrait),
        const ReaderFloatingBallPosition(x: 0, y: 0.25),
      );
      expect(
        await store.load(Orientation.landscape),
        const ReaderFloatingBallPosition(x: 1, y: 0.75),
      );
    },
  );

  test(
    'bookmark toggle supports multiple pages and restart recovery',
    () async {
      final _MemoryBookmarkRepository repository = _MemoryBookmarkRepository();
      final ReaderBookmarkService first = ReaderBookmarkService(
        repository: repository,
      );

      expect(await first.toggle(galleryKey: 'gallery', pageIndex: 2), isTrue);
      expect(await first.toggle(galleryKey: 'gallery', pageIndex: 5), isTrue);
      expect(
        (await first.load('gallery')).map((bookmark) => bookmark.pageIndex),
        containsAll(<int>[2, 5]),
      );
      expect(await first.toggle(galleryKey: 'gallery', pageIndex: 2), isFalse);

      final ReaderBookmarkService restarted = ReaderBookmarkService(
        repository: repository,
      );
      expect(
        (await restarted.load('gallery')).map((bookmark) => bookmark.pageIndex),
        <int>[5],
      );

      final ReaderBookmark bookmark = repository.values['gallery:2']!;
      expect(ReaderBookmark.decode(bookmark.encode()).deletedAt, isNotNull);
      expect(ReaderBookmark.decode(bookmark.encode()).note, isNull);
    },
  );

  test(
    'current-page super resolution uses the page queue and disk cache',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'jh-reader-sr',
      );
      final List<String> calls = <String>[];
      int pauseCalls = 0;
      int resumeCalls = 0;
      final ReaderPageSuperResolutionService service =
          ReaderPageSuperResolutionService(
            cacheDirectoryPath: temp.path,
            sourceResolver:
                (mode, image, galleryKey) async => '/tmp/source-$galleryKey',
            wholeGalleryPauser: () async {
              pauseCalls++;
              return SuperResolutionPauseLease(() async {
                resumeCalls++;
              });
            },
            runner: (inputPath, outputPath) async {
              calls.add('$inputPath->$outputPath');
              final File output = File(outputPath);
              await output.parent.create(recursive: true);
              await output.writeAsString('cached');
              return outputPath;
            },
          );
      final GalleryImage image = GalleryImage(url: 'https://example/page.jpg');

      try {
        final String? first = await service.upscale(
          galleryKey: 'g',
          pageIndex: 3,
          mode: ReadMode.online,
          image: image,
        );
        final String? second = await service.upscale(
          galleryKey: 'g',
          pageIndex: 3,
          mode: ReadMode.online,
          image: image,
        );

        expect(first, isNotNull);
        expect(second, first);
        expect(calls, hasLength(1));
        expect(pauseCalls, 1);
        expect(resumeCalls, 1);
        expect(await File(first!).readAsString(), 'cached');
      } finally {
        await service.dispose();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'current-page super resolution releases its pause lease after failure',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'jh-reader-sr-failure',
      );
      int resumeCalls = 0;
      final ReaderPageSuperResolutionService service =
          ReaderPageSuperResolutionService(
            cacheDirectoryPath: temp.path,
            sourceResolver:
                (mode, image, galleryKey) async => '/tmp/source-$galleryKey',
            wholeGalleryPauser: () async => SuperResolutionPauseLease(() async {
              resumeCalls++;
            }),
            runner: (inputPath, outputPath) async {
              throw StateError('upscale failed');
            },
          );

      try {
        expect(
          await service.upscale(
            galleryKey: 'failure',
            pageIndex: 0,
            mode: ReadMode.online,
            image: GalleryImage(url: 'https://example/failure.jpg'),
          ),
          isNull,
        );
        expect(resumeCalls, 1);
      } finally {
        await service.dispose();
        await temp.delete(recursive: true);
      }
    },
  );

  test('whole-gallery pause lease resumes at most once', () async {
    int resumeCalls = 0;
    final SuperResolutionPauseLease lease = SuperResolutionPauseLease(() async {
      resumeCalls++;
    });

    await lease.resume();
    await lease.resume();

    expect(resumeCalls, 1);
  });

  test('user action invalidates only its own reader preemption snapshot', () {
    final SuperResolutionPreemptionTracker tracker =
        SuperResolutionPreemptionTracker();
    final int galleryRevision = tracker.capture(
      1,
      SuperResolutionType.gallery,
    );
    final int archiveRevision = tracker.capture(
      2,
      SuperResolutionType.archive,
    );

    tracker.recordUserAction(1, SuperResolutionType.gallery);

    expect(
      tracker.isCurrent(1, SuperResolutionType.gallery, galleryRevision),
      isFalse,
    );
    expect(
      tracker.isCurrent(2, SuperResolutionType.archive, archiveRevision),
      isTrue,
    );
  });

  test(
    'queued current-page upscales share one whole-gallery pause lease',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'jh-reader-sr-overlap',
      );
      final Completer<void> firstRelease = Completer<void>();
      int runnerCalls = 0;
      int pauseCalls = 0;
      int resumeCalls = 0;
      final ReaderPageSuperResolutionService service =
          ReaderPageSuperResolutionService(
            cacheDirectoryPath: temp.path,
            sourceResolver:
                (mode, image, galleryKey) async => '/tmp/source-$galleryKey',
            wholeGalleryPauser: () async {
              pauseCalls++;
              return SuperResolutionPauseLease(() async {
                resumeCalls++;
              });
            },
            runner: (inputPath, outputPath) async {
              runnerCalls++;
              if (runnerCalls == 1) {
                await firstRelease.future;
              }
              final File output = File(outputPath);
              await output.parent.create(recursive: true);
              await output.writeAsString('done');
              return outputPath;
            },
          );

      try {
        final Future<String?> first = service.upscale(
          galleryKey: 'overlap',
          pageIndex: 0,
          mode: ReadMode.online,
          image: GalleryImage(url: 'https://example/overlap-0.jpg'),
        );
        final Future<String?> second = service.upscale(
          galleryKey: 'overlap',
          pageIndex: 1,
          mode: ReadMode.online,
          image: GalleryImage(url: 'https://example/overlap-1.jpg'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(pauseCalls, 1);
        expect(resumeCalls, 0);
        firstRelease.complete();
        await Future.wait<String?>(<Future<String?>>[first, second]);

        expect(runnerCalls, 2);
        expect(pauseCalls, 1);
        expect(resumeCalls, 1);
      } finally {
        await service.dispose();
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'canceling a translation batch does not delete completed disk cache',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'jh-reader-translation',
      );
      final ImageTranslationService service = ImageTranslationService();
      service.setTranslationCacheDirectoryForTesting(temp);
      try {
        await service.writePersistentResultForKeyForTesting(
          'completed-page',
          const ImageTranslationResult(
            status: ImageTranslationStatus.success,
            sourceText: 'source',
            translatedText: 'translated',
          ),
        );
        final File cache = File('${temp.path}/completed-page.json');
        expect(await cache.exists(), isTrue);
        service.beginBatch(2);
        service.cancelBatch();
        expect(await cache.exists(), isTrue);
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
}
