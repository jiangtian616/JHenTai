import 'dart:async';

enum ReaderThumbnailLoadStatus { idle, loading, completed, failed, cancelled }

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
    _status = ReaderThumbnailLoadStatus.completed;
    onStatusChanged?.call(_status);
  }

  void failed(ReaderThumbnailRequestToken token) {
    if (!isCurrent(token)) {
      return;
    }
    _cancelWatchdog();
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
