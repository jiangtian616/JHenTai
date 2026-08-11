import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/reader_thumbnail_request_controller.dart';

void main() {
  test(
    'watchdog marks a request failed, then performs one finite auto retry',
    () async {
      final List<ReaderThumbnailRequestToken> retries =
          <ReaderThumbnailRequestToken>[];
      final ReaderThumbnailRequestController controller =
          ReaderThumbnailRequestController(
            watchdogTimeout: const Duration(milliseconds: 10),
            autoRetryDelay: const Duration(milliseconds: 5),
            onRetryRequested: retries.add,
          );

      final ReaderThumbnailRequestToken first = controller.start('page-1');
      await Future<void>.delayed(const Duration(milliseconds: 12));
      expect(controller.status, ReaderThumbnailLoadStatus.failed);

      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(retries, hasLength(1));
      expect(controller.status, ReaderThumbnailLoadStatus.loading);
      expect(retries.single, isNot(first));

      await Future<void>.delayed(const Duration(milliseconds: 12));
      await Future<void>.delayed(const Duration(milliseconds: 8));
      expect(retries, hasLength(1));
    },
  );

  test('manual retry starts a new generation and ignores stale completion', () {
    final List<ReaderThumbnailRequestToken> retries =
        <ReaderThumbnailRequestToken>[];
    final ReaderThumbnailRequestController controller =
        ReaderThumbnailRequestController(onRetryRequested: retries.add);

    final ReaderThumbnailRequestToken first = controller.start('same-slot');
    controller.failed(first);
    controller.retry();

    expect(retries, hasLength(1));
    final ReaderThumbnailRequestToken second = retries.single;
    controller.completed(first);
    expect(controller.status, ReaderThumbnailLoadStatus.loading);
    controller.completed(second);
    expect(controller.status, ReaderThumbnailLoadStatus.completed);
  });

  test(
    'cancel invalidates callbacks from a recycled thumbnail request',
    () async {
      final Completer<void> settled = Completer<void>();
      final ReaderThumbnailRequestController controller =
          ReaderThumbnailRequestController(
            watchdogTimeout: const Duration(milliseconds: 5),
            onStatusChanged: (ReaderThumbnailLoadStatus status) {
              if (status == ReaderThumbnailLoadStatus.cancelled &&
                  !settled.isCompleted) {
                settled.complete();
              }
            },
          );

      final ReaderThumbnailRequestToken old = controller.start('old-image');
      controller.cancel();
      await settled.future;
      controller.completed(old);
      controller.progress(old);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.status, ReaderThumbnailLoadStatus.cancelled);
    },
  );

  test(
    'progress resets the watchdog while decoding is making progress',
    () async {
      final ReaderThumbnailRequestController controller =
          ReaderThumbnailRequestController(
            watchdogTimeout: const Duration(milliseconds: 12),
          );
      final ReaderThumbnailRequestToken token = controller.start('progressive');
      await Future<void>.delayed(const Duration(milliseconds: 7));
      controller.progress(token);
      await Future<void>.delayed(const Duration(milliseconds: 7));
      expect(controller.status, ReaderThumbnailLoadStatus.loading);
      controller.completed(token);
    },
  );
}
