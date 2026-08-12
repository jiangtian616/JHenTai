import 'dart:async';
import 'package:flutter/foundation.dart';

enum ReaderThumbnailLoadStatus { idle, loading, completed, failed, cancelled }

/// A process-wide limiter for thumbnail network loads that prioritises the
/// thumbnails closest to the viewport.
///
/// The details page builds dozens of thumbnails in one frame (grid + large
/// scroll cache extent) and the read page keeps a strip of them alive. Without a
/// cap, every built thumbnail fires a request at once and EH's image servers
/// rate-limit the burst, so the thumbnails the user is actually looking at get
/// no advantage. [ThumbnailLoadGate] keeps at most [maxConcurrent] downloads
/// in flight and, whenever a slot frees, hands it to the waiting thumbnail whose
/// [ThumbnailGateWaiter.priority] (viewport distance) is smallest — the user's
/// scroll position decides what loads next.
class ThumbnailLoadGate {
  ThumbnailLoadGate._();

  /// Matches a browser's typical per-host connection budget: visible thumbnails
  /// load immediately, the rest stream in as the user scrolls.
  static const int maxConcurrent = 6;

  static int _active = 0;
  static final List<ThumbnailGateWaiter> _waiters = <ThumbnailGateWaiter>[];

  /// Returns true if the caller may start a load now.
  static bool tryAcquire() {
    if (_active < maxConcurrent) {
      _active++;
      return true;
    }
    return false;
  }

  /// Registers [onAvailable] with [priority] (lower = closer to the viewport).
  /// Re-registering the same [id] replaces the previous entry.
  static void whenAvailable(
    String id,
    double priority,
    VoidCallback onAvailable,
  ) {
    _waiters
      ..removeWhere((w) => w.id == id)
      ..add(ThumbnailGateWaiter(id, priority, onAvailable));
    _dispatch();
  }

  /// Re-ranks a waiter whose distance to the viewport changed (user scrolled).
  static void updatePriority(String id, double priority) {
    for (final ThumbnailGateWaiter w in _waiters) {
      if (w.id == id) {
        w.priority = priority;
        break;
      }
    }
    _dispatch();
  }

  /// Frees a slot and lets the closest-to-viewport waiter take it.
  static void release() {
    if (_active > 0) {
      _active--;
    }
    _dispatch();
  }

  static void _dispatch() {
    while (_active < maxConcurrent && _waiters.isNotEmpty) {
      int best = 0;
      for (int i = 1; i < _waiters.length; i++) {
        if (_waiters[i].priority < _waiters[best].priority) {
          best = i;
        }
      }
      final ThumbnailGateWaiter waiter = _waiters.removeAt(best);
      _active++;
      waiter.onAvailable();
    }
  }
}

class ThumbnailGateWaiter {
  ThumbnailGateWaiter(this.id, this.priority, this.onAvailable);

  final String id;
  double priority;
  final VoidCallback onAvailable;
}

class ReaderThumbnailRequestToken {
  const ReaderThumbnailRequestToken(this.identity, this.generation);

  final String identity;
  final int generation;

  @override
  bool operator ==(Object other) =>
      other is ReaderThumbnailRequestToken &&
      identity == other.identity &&
      generation == other.generation;

  @override
  int get hashCode => Object.hash(identity, generation);
}

typedef ReaderThumbnailAttemptCallback =
    void Function(ReaderThumbnailRequestToken token);
typedef ReaderThumbnailStatusCallback =
    void Function(ReaderThumbnailLoadStatus status);

/// Owns the lifetime of one reader thumbnail request.
///
/// The image widget can be recycled while its ImageStream is still pending.
/// Every callback therefore carries an identity and generation, and callbacks
/// from an older attempt are ignored. The controller deliberately does not
/// know about Flutter widgets or a particular network provider, which makes
/// the timeout/cancellation rules testable without a real network.
class ReaderThumbnailRequestController {
  static const int defaultWatchdogMilliseconds = 8000;

  ReaderThumbnailRequestController({
    this.watchdogTimeout = const Duration(seconds: 8),
    this.autoRetryDelay = const Duration(milliseconds: 350),
    this.maxAutomaticRetries = 1,
    this.onRetryRequested,
    this.onAttemptTimedOut,
    this.onStatusChanged,
  }) : assert(maxAutomaticRetries >= 0);

  final Duration watchdogTimeout;
  final Duration autoRetryDelay;
  final int maxAutomaticRetries;
  final ReaderThumbnailAttemptCallback? onRetryRequested;
  final ReaderThumbnailAttemptCallback? onAttemptTimedOut;
  final ReaderThumbnailStatusCallback? onStatusChanged;

  Timer? _watchdog;
  Timer? _retryTimer;
  String? _identity;
  int _generation = 0;
  int _automaticRetries = 0;
  bool _disposed = false;
  ReaderThumbnailLoadStatus _status = ReaderThumbnailLoadStatus.idle;
  ReaderThumbnailRequestToken? _currentToken;

  ReaderThumbnailLoadStatus get status => _status;
  ReaderThumbnailRequestToken? get currentToken => _currentToken;

  ReaderThumbnailRequestToken start(String identity) {
    _cancelTimers();
    _identity = identity;
    _automaticRetries = 0;
    return _beginAttempt(notify: false);
  }

  bool isCurrent(ReaderThumbnailRequestToken token) =>
      !_disposed && token == _currentToken;

  void progress(ReaderThumbnailRequestToken token) {
    if (!isCurrent(token) || _status != ReaderThumbnailLoadStatus.loading) {
      return;
    }
    _armWatchdog(token);
  }

  void completed(ReaderThumbnailRequestToken token) {
    if (!isCurrent(token)) {
      return;
    }
    _cancelTimers();
    // Idempotent: ExtendedImage re-invokes the completed widget builder on
    // every rebuild (loadStateChanged is re-fired while returnLoadStateChanged
    // is true), and EHThumbnail's onStatusChanged schedules another rebuild.
    // Not guarding here turned a single finished thumbnail into a per-frame
    // completed → rebuild → completed loop (29k+ rebuilds per page in the
    // details grid), which kept thumbnails flickering/spinning, pinned the GPU
    // and starved other thumbnail loads into the watchdog.
    if (_status == ReaderThumbnailLoadStatus.completed) {
      return;
    }
    _status = ReaderThumbnailLoadStatus.completed;
    onStatusChanged?.call(_status);
  }

  void failed(ReaderThumbnailRequestToken token) {
    if (!isCurrent(token)) {
      return;
    }
    _cancelWatchdog();
    if (_status == ReaderThumbnailLoadStatus.failed) {
      return;
    }
    _status = ReaderThumbnailLoadStatus.failed;
    onStatusChanged?.call(_status);
    _scheduleAutomaticRetry(token);
  }

  /// Starts a new provider attempt after a visible error.
  void retry() {
    if (_disposed || _identity == null) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _automaticRetries = 0;
    _beginAttempt(notify: true);
  }

  void cancel() {
    if (_disposed) {
      return;
    }
    _cancelTimers();
    _generation++;
    _currentToken = null;
    _status = ReaderThumbnailLoadStatus.cancelled;
    onStatusChanged?.call(_status);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelTimers();
    _generation++;
    _currentToken = null;
  }

  ReaderThumbnailRequestToken _beginAttempt({required bool notify}) {
    final String identity = _identity!;
    final ReaderThumbnailRequestToken token = ReaderThumbnailRequestToken(
      identity,
      ++_generation,
    );
    _currentToken = token;
    _status = ReaderThumbnailLoadStatus.loading;
    _armWatchdog(token);
    if (notify) {
      onStatusChanged?.call(_status);
    }
    if (notify) {
      onRetryRequested?.call(token);
    }
    return token;
  }

  void _armWatchdog(ReaderThumbnailRequestToken token) {
    _watchdog?.cancel();
    _watchdog = Timer(watchdogTimeout, () {
      if (!isCurrent(token) || _status != ReaderThumbnailLoadStatus.loading) {
        return;
      }
      _watchdog = null;
      _status = ReaderThumbnailLoadStatus.failed;
      onAttemptTimedOut?.call(token);
      onStatusChanged?.call(_status);
      _scheduleAutomaticRetry(token);
    });
  }

  void _scheduleAutomaticRetry(ReaderThumbnailRequestToken token) {
    if (!isCurrent(token) ||
        _automaticRetries >= maxAutomaticRetries ||
        _disposed) {
      return;
    }
    _automaticRetries++;
    _retryTimer?.cancel();
    _retryTimer = Timer(autoRetryDelay, () {
      _retryTimer = null;
      if (isCurrent(token) && _status == ReaderThumbnailLoadStatus.failed) {
        _beginAttempt(notify: true);
      }
    });
  }

  void _cancelTimers() {
    _cancelWatchdog();
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _cancelWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }
}
