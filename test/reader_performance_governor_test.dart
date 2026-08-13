import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/reader_performance_governor.dart';

void main() {
  test('constrains reader work after sustained slow frames', () {
    final policies = <ReaderPerformancePolicy>[];
    final governor = ReaderPerformanceGovernor(
      onPolicyChanged: policies.add,
      sampleSize: 4,
      minimumSamples: 4,
      frameBudget: const Duration(milliseconds: 20),
    );

    for (int i = 0; i < 4; i++) {
      governor.recordFrame(const Duration(milliseconds: 30));
    }

    expect(governor.policy.mode, ReaderPerformanceMode.constrained);
    expect(governor.policy.lookAhead, 1);
    expect(governor.policy.parseConcurrency, 24);
    expect(governor.policy.imagePrefetchConcurrency, 1);
    expect(policies.single.mode, ReaderPerformanceMode.constrained);
  });

  test('uses hysteresis before returning to the balanced policy', () {
    final policies = <ReaderPerformancePolicy>[];
    final governor = ReaderPerformanceGovernor(
      onPolicyChanged: policies.add,
      sampleSize: 4,
      minimumSamples: 4,
      frameBudget: const Duration(milliseconds: 20),
    );

    for (int i = 0; i < 4; i++) {
      governor.recordFrame(const Duration(milliseconds: 30));
    }
    for (int i = 0; i < 4; i++) {
      governor.recordFrame(const Duration(milliseconds: 10));
    }

    expect(governor.policy.mode, ReaderPerformanceMode.balanced);
    expect(policies.map((policy) => policy.mode), [
      ReaderPerformanceMode.constrained,
      ReaderPerformanceMode.balanced,
    ]);
    expect(governor.policy.lookAhead, 3);
    expect(governor.policy.imagePrefetchConcurrency, 2);
  });

  test('derives frame budget from the active display refresh rate', () {
    expect(
      ReaderPerformanceGovernor.frameBudgetForRefreshRate(30),
      const Duration(milliseconds: 40),
    );
    expect(
      ReaderPerformanceGovernor.frameBudgetForRefreshRate(60),
      const Duration(milliseconds: 20),
    );
    expect(
      ReaderPerformanceGovernor.frameBudgetForRefreshRate(120),
      const Duration(milliseconds: 10),
    );
  });

  test('re-evaluates the display refresh rate for each frame sample', () {
    double refreshRate = 60;
    final governor = ReaderPerformanceGovernor(
      onPolicyChanged: (_) {},
      sampleSize: 1,
      minimumSamples: 1,
      refreshRateProvider: () => refreshRate,
    );

    governor.recordFrame(const Duration(milliseconds: 15));
    expect(governor.policy.mode, ReaderPerformanceMode.balanced);

    refreshRate = 120;
    governor.recordFrame(const Duration(milliseconds: 15));
    expect(governor.policy.mode, ReaderPerformanceMode.constrained);
  });
}
