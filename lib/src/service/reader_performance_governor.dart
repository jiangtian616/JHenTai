import 'dart:collection';
import 'dart:ui';

import 'package:flutter/scheduler.dart';

enum ReaderPerformanceMode { balanced, constrained }

class ReaderPerformancePolicy {
  const ReaderPerformancePolicy({
    required this.mode,
    required this.lookAhead,
    required this.lookBehind,
    required this.parseConcurrency,
    required this.cacheConcurrency,
    required this.imagePrefetchConcurrency,
  });

  static const balanced = ReaderPerformancePolicy(
    mode: ReaderPerformanceMode.balanced,
    lookAhead: 3,
    lookBehind: 1,
    parseConcurrency: 100,
    cacheConcurrency: 20,
    imagePrefetchConcurrency: 2,
  );

  static const constrained = ReaderPerformancePolicy(
    mode: ReaderPerformanceMode.constrained,
    lookAhead: 1,
    lookBehind: 0,
    parseConcurrency: 24,
    cacheConcurrency: 8,
    imagePrefetchConcurrency: 1,
  );

  final ReaderPerformanceMode mode;
  final int lookAhead;
  final int lookBehind;
  final int parseConcurrency;
  final int cacheConcurrency;
  final int imagePrefetchConcurrency;
}

typedef ReaderPerformancePolicyChanged =
    void Function(ReaderPerformancePolicy policy);

/// A small frame-budget governor with hysteresis.
///
/// It intentionally uses public Flutter frame timings only. A sustained jank
/// ratio reduces reader prefetch and executor concurrency; recovery requires a
/// substantially lower ratio so the policy does not oscillate every frame.
class ReaderPerformanceGovernor {
  ReaderPerformanceGovernor({
    required this.onPolicyChanged,
    this.sampleSize = 30,
    this.minimumSamples = 12,
    this.frameBudget,
    this.refreshRateProvider = _defaultRefreshRate,
  });

  final ReaderPerformancePolicyChanged onPolicyChanged;
  final int sampleSize;
  final int minimumSamples;

  /// A fixed budget for deterministic tests or explicit overrides. When null,
  /// the current view's refresh rate is resolved for every sample so moving a
  /// window between displays also updates the budget.
  final Duration? frameBudget;
  final double Function() refreshRateProvider;

  final ListQueue<bool> _jankSamples = ListQueue<bool>();
  late final TimingsCallback _timingsCallback = _handleFrameTimings;
  ReaderPerformancePolicy _policy = ReaderPerformancePolicy.balanced;
  bool _running = false;

  ReaderPerformancePolicy get policy => _policy;
  bool get isRunning => _running;
  Duration get effectiveFrameBudget =>
      frameBudget ?? frameBudgetForRefreshRate(refreshRateProvider());

  /// Allows 20% scheduling/measurement headroom over one display interval.
  /// This preserves the former 20 ms threshold on 60 Hz while correctly
  /// tightening it to 10 ms on 120 Hz displays.
  static Duration frameBudgetForRefreshRate(double refreshRate) {
    final double safeRefreshRate =
        refreshRate.isFinite && refreshRate > 0 ? refreshRate : 60;
    return Duration(
      microseconds:
          (Duration.microsecondsPerSecond / safeRefreshRate * 1.2).round(),
    );
  }

  static double _defaultRefreshRate() {
    final PlatformDispatcher dispatcher = PlatformDispatcher.instance;
    if (dispatcher.views.isNotEmpty) {
      return dispatcher.views.first.display.refreshRate;
    }
    if (dispatcher.displays.isNotEmpty) {
      return dispatcher.displays.first.refreshRate;
    }
    return 60;
  }

  void start() {
    if (_running) {
      return;
    }
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback);
    onPolicyChanged(_policy);
  }

  void stop() {
    if (_running) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback);
    }
    _running = false;
    _jankSamples.clear();
    _setPolicy(ReaderPerformancePolicy.balanced);
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      recordFrame(timing.totalSpan);
    }
  }

  void recordFrame(Duration duration) {
    _jankSamples.addLast(duration > effectiveFrameBudget);
    while (_jankSamples.length > sampleSize) {
      _jankSamples.removeFirst();
    }
    if (_jankSamples.length < minimumSamples) {
      return;
    }

    final int jankyFrames = _jankSamples.where((sample) => sample).length;
    final double ratio = jankyFrames / _jankSamples.length;
    if (_policy.mode == ReaderPerformanceMode.balanced && ratio >= 0.25) {
      _setPolicy(ReaderPerformancePolicy.constrained);
    } else if (_policy.mode == ReaderPerformanceMode.constrained &&
        ratio <= 0.08) {
      _setPolicy(ReaderPerformancePolicy.balanced);
    }
  }

  void _setPolicy(ReaderPerformancePolicy policy) {
    if (_policy.mode == policy.mode) {
      return;
    }
    _policy = policy;
    onPolicyChanged(policy);
  }
}
