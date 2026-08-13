class InferenceCancelledException implements Exception {
  const InferenceCancelledException([this.reason = 'cancelled']);

  final String reason;

  @override
  String toString() => 'InferenceCancelledException: $reason';
}

class InferenceCancellationToken {
  bool _cancelled = false;
  String _reason = 'cancelled';
  final List<void Function(String reason)> _listeners =
      <void Function(String reason)>[];

  bool get isCancelled => _cancelled;
  String get reason => _reason;

  void addListener(void Function(String reason) listener) {
    if (_cancelled) {
      listener(_reason);
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function(String reason) listener) {
    _listeners.remove(listener);
  }

  void cancel([String reason = 'cancelled']) {
    _cancelled = true;
    _reason = reason;
    for (final void Function(String reason) listener in List.of(_listeners)) {
      listener(reason);
    }
    _listeners.clear();
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw InferenceCancelledException(_reason);
    }
  }
}

typedef InferenceProgressCallback = void Function(double progress);
