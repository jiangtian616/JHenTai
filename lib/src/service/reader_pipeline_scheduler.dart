import 'dart:async';

enum ReaderPagePriority {
  visible(0),
  nearby(1000),
  background(2000);

  const ReaderPagePriority(this.executorPriority);

  final int executorPriority;
}

typedef ReaderPageRequest =
    void Function(int imageIndex, ReaderPagePriority priority);

class ReaderViewportDelta {
  const ReaderViewportDelta({required this.entering, required this.leaving});

  final Set<int> entering;
  final Set<int> leaving;
}

/// Tracks viewport membership so frame-by-frame scroll callbacks do not
/// repeat page-entry work such as disk-backed translation hydration.
class ReaderViewportTracker {
  Set<int> _visible = <int>{};

  Set<int> get visible => Set<int>.unmodifiable(_visible);

  ReaderViewportDelta update(Set<int> next) {
    final ReaderViewportDelta delta = ReaderViewportDelta(
      entering: next.difference(_visible),
      leaving: _visible.difference(next),
    );
    _visible = Set<int>.of(next);
    return delta;
  }

  void clear() => _visible = <int>{};
}

typedef ReaderPageHydrator = Future<void> Function(int index);
typedef ReaderHydrationErrorHandler =
    void Function(int index, Object error, StackTrace stackTrace);

/// Keeps translation-cache hydration out of widget builders and layout
/// initialization. At most one task runs for a page; an image-load event that
/// arrives while the viewport-entry task is active queues exactly one follow-up
/// attempt, after the image has reached the disk cache.
class ReaderPageHydrationScheduler {
  final Map<int, Future<void>> _active = <int, Future<void>>{};
  final Map<int, _ReaderHydrationRequest> _pending =
      <int, _ReaderHydrationRequest>{};
  bool _disposed = false;

  bool get isIdle => _active.isEmpty && _pending.isEmpty;

  void schedule({
    required int index,
    required ReaderPageHydrator hydrate,
    bool retryIfActive = false,
    ReaderHydrationErrorHandler? onError,
  }) {
    if (_disposed) {
      return;
    }
    final _ReaderHydrationRequest request = _ReaderHydrationRequest(
      hydrate: hydrate,
      onError: onError,
    );
    if (_active.containsKey(index)) {
      if (retryIfActive) {
        _pending[index] = request;
      }
      return;
    }
    _start(index, request);
  }

  void _start(int index, _ReaderHydrationRequest request) {
    late final Future<void> task;
    task = Future<void>.sync(() => request.hydrate(index));
    _active[index] = task;
    unawaited(
      task.then<void>(
        (_) => _complete(index, task),
        onError: (Object error, StackTrace stackTrace) {
          try {
            request.onError?.call(index, error, stackTrace);
          } finally {
            _complete(index, task);
          }
        },
      ),
    );
  }

  void _complete(int index, Future<void> task) {
    if (!identical(_active[index], task)) {
      return;
    }
    _active.remove(index);
    final _ReaderHydrationRequest? pending = _pending.remove(index);
    if (!_disposed && pending != null) {
      _start(index, pending);
    }
  }

  void dispose() {
    _disposed = true;
    _pending.clear();
  }
}

class _ReaderHydrationRequest {
  const _ReaderHydrationRequest({required this.hydrate, this.onError});

  final ReaderPageHydrator hydrate;
  final ReaderHydrationErrorHandler? onError;
}

/// Converts viewport changes into a small, direction-aware page work plan.
///
/// Network, decode and post-processing remain owned by their existing
/// services. This class only decides which image indices should advance
/// through the reader pipeline first.
class ReaderPipelineScheduler {
  ReaderPipelineScheduler({
    required this.pageCount,
    required this.onPageRequested,
    int lookAhead = 3,
    int lookBehind = 1,
  }) : _lookAhead = lookAhead,
       _lookBehind = lookBehind;

  final int pageCount;
  final ReaderPageRequest onPageRequested;
  int _lookAhead;
  int _lookBehind;

  List<int> _visibleIndices = const [];
  List<MapEntry<int, ReaderPagePriority>> _plan = const [];
  int? _lastAnchor;
  int _direction = 1;
  bool _disposed = false;

  List<MapEntry<int, ReaderPagePriority>> get plan => List.unmodifiable(_plan);
  int get lookAhead => _lookAhead;
  int get lookBehind => _lookBehind;
  bool isPlanned(int imageIndex) =>
      _plan.any((entry) => entry.key == imageIndex);

  /// Whether any image from a detail page is still part of the active plan.
  ///
  /// Thumbnail href parsing is deduplicated at detail-page granularity, so
  /// cancellation must use that same granularity. Otherwise a fast jump to a
  /// different image on the same detail page can cancel the only task capable
  /// of filling both images.
  bool isDetailPagePlanned(int detailPageIndex, int imagesPerDetailPage) {
    if (detailPageIndex < 0 || imagesPerDetailPage <= 0) {
      return false;
    }
    return _plan.any(
      (entry) => entry.key ~/ imagesPerDetailPage == detailPageIndex,
    );
  }

  void configure({required int lookAhead, required int lookBehind}) {
    if (_disposed) {
      return;
    }
    _lookAhead = lookAhead < 0 ? 0 : lookAhead;
    _lookBehind = lookBehind < 0 ? 0 : lookBehind;
    if (_visibleIndices.isNotEmpty) {
      updateViewport(_visibleIndices);
    }
  }

  void updateViewport(Iterable<int> visibleIndices) {
    if (_disposed || pageCount <= 0) {
      return;
    }

    final List<int> visible =
        visibleIndices
            .where((index) => index >= 0 && index < pageCount)
            .toSet()
            .toList()
          ..sort();
    if (visible.isEmpty) {
      return;
    }

    final int anchor = visible.first;
    if (_lastAnchor != null && anchor != _lastAnchor) {
      _direction = anchor > _lastAnchor! ? 1 : -1;
    }
    _lastAnchor = anchor;
    _visibleIndices = visible;

    final List<MapEntry<int, ReaderPagePriority>> nextPlan = [];
    final Set<int> scheduled = <int>{};

    void add(int index, ReaderPagePriority priority) {
      if (index < 0 || index >= pageCount || !scheduled.add(index)) {
        return;
      }
      nextPlan.add(MapEntry(index, priority));
    }

    for (final int index in visible) {
      add(index, ReaderPagePriority.visible);
    }

    final int leadingEdge = _direction > 0 ? visible.last : visible.first;
    for (int distance = 1; distance <= _lookAhead; distance++) {
      add(leadingEdge + (_direction * distance), ReaderPagePriority.nearby);
    }

    final int trailingEdge = _direction > 0 ? visible.first : visible.last;
    for (int distance = 1; distance <= _lookBehind; distance++) {
      add(
        trailingEdge - (_direction * distance),
        ReaderPagePriority.background,
      );
    }

    final Map<int, ReaderPagePriority> previousPriorities = {
      for (final entry in _plan) entry.key: entry.value,
    };
    _plan = nextPlan;

    for (final entry in nextPlan) {
      final ReaderPagePriority? previous = previousPriorities[entry.key];
      if (previous == null || entry.value.index < previous.index) {
        onPageRequested(entry.key, entry.value);
      }
    }
  }

  /// Replays the current plan after one pipeline stage completes, allowing
  /// pages that now have an href to advance to image-URL parsing.
  void refresh() {
    if (_disposed || _visibleIndices.isEmpty) {
      return;
    }
    for (final entry in _plan) {
      onPageRequested(entry.key, entry.value);
    }
  }

  void clear() {
    _visibleIndices = const [];
    _plan = const [];
    _lastAnchor = null;
    _direction = 1;
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}
