class InferenceCancelledException implements Exception {
  const InferenceCancelledException([this.reason = 'cancelled']);

  final String reason;

  @override
  String toString() => 'InferenceCancelledException: $reason';
}

class InferenceCancellationToken {
  bool _cancelled = false;
  String _reason = 'cancelled';

  bool get isCancelled => _cancelled;
  String get reason => _reason;

  void cancel([String reason = 'cancelled']) {
    _cancelled = true;
    _reason = reason;
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw InferenceCancelledException(_reason);
    }
  }
}

typedef InferenceProgressCallback = void Function(double progress);
