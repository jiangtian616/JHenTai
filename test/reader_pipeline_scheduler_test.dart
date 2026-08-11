import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/reader_pipeline_scheduler.dart';

void main() {
  test('viewport tracker only reports pages that actually enter or leave', () {
    final ReaderViewportTracker tracker = ReaderViewportTracker();

    final ReaderViewportDelta first = tracker.update(<int>{4, 5});
    expect(first.entering, <int>{4, 5});
    expect(first.leaving, isEmpty);

    final ReaderViewportDelta repeated = tracker.update(<int>{4, 5});
    expect(repeated.entering, isEmpty);
    expect(repeated.leaving, isEmpty);

    final ReaderViewportDelta moved = tracker.update(<int>{5, 6});
    expect(moved.entering, <int>{6});
    expect(moved.leaving, <int>{4});
  });

  test(
    'prioritizes visible pages and looks ahead in the reading direction',
    () {
      final List<MapEntry<int, ReaderPagePriority>> requests = [];
      final scheduler = ReaderPipelineScheduler(
        pageCount: 20,
        onPageRequested: (index, priority) {
          requests.add(MapEntry(index, priority));
        },
      );

      scheduler.updateViewport([5, 6]);

      expect(requests.map(_requestLabel), [
        '5:visible',
        '6:visible',
        '7:nearby',
        '8:nearby',
        '9:nearby',
        '4:background',
      ]);
    },
  );

  test('reverses look-ahead after the viewport moves backwards', () {
    final List<MapEntry<int, ReaderPagePriority>> requests = [];
    final scheduler = ReaderPipelineScheduler(
      pageCount: 20,
      onPageRequested: (index, priority) {
        requests.add(MapEntry(index, priority));
      },
    );

    scheduler.updateViewport([8]);
    requests.clear();
    scheduler.updateViewport([6]);

    expect(scheduler.plan.map(_requestLabel), [
      '6:visible',
      '5:nearby',
      '4:nearby',
      '3:nearby',
      '7:background',
    ]);
    expect(requests.map(_requestLabel), [
      '6:visible',
      '5:nearby',
      '4:nearby',
      '3:nearby',
    ]);
  });

  test('refresh replays the plan so completed stages can advance', () {
    final List<int> requests = [];
    final scheduler = ReaderPipelineScheduler(
      pageCount: 3,
      onPageRequested: (index, _) => requests.add(index),
    );

    scheduler.updateViewport([0]);
    requests.clear();
    scheduler.refresh();

    expect(requests, [0, 1, 2]);
  });

  test('clamps work to valid page indices and stops after dispose', () {
    final List<int> requests = [];
    final scheduler = ReaderPipelineScheduler(
      pageCount: 2,
      onPageRequested: (index, _) => requests.add(index),
    );

    scheduler.updateViewport([-1, 0, 5]);
    expect(requests, [0, 1]);

    scheduler.dispose();
    scheduler.updateViewport([1]);
    scheduler.refresh();
    expect(requests, [0, 1]);
  });

  test('rebuilds its plan when the governor changes the prefetch window', () {
    final requests = <int>[];
    final scheduler = ReaderPipelineScheduler(
      pageCount: 10,
      onPageRequested: (index, _) => requests.add(index),
    );

    scheduler.updateViewport([4]);
    requests.clear();
    scheduler.configure(lookAhead: 1, lookBehind: 0);

    expect(scheduler.lookAhead, 1);
    expect(scheduler.lookBehind, 0);
    expect(scheduler.plan.map((entry) => entry.key), [4, 5]);
    expect(scheduler.isPlanned(5), isTrue);
    expect(scheduler.isPlanned(3), isFalse);
  });

  test('keeps a shared detail-page task when another image is planned', () {
    final scheduler = ReaderPipelineScheduler(
      pageCount: 30,
      onPageRequested: (_, __) {},
    );

    scheduler.updateViewport([12]);

    expect(scheduler.isPlanned(10), isFalse);
    expect(scheduler.isDetailPagePlanned(2, 5), isTrue);
    expect(scheduler.isDetailPagePlanned(1, 5), isFalse);
    expect(scheduler.isDetailPagePlanned(2, 0), isFalse);
  });
}

String _requestLabel(MapEntry<int, ReaderPagePriority> request) =>
    '${request.key}:${request.value.name}';
