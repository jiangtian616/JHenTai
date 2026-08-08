import 'package:executor/executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/utils/eh_executor.dart';

void main() {
  test('EHExecutor survives a rate whose maximum is zero (no divide by zero)',
      () async {
    // Before the guard, a non-empty _started list with maximum == 0 threw
    // IntegerDivisionByZeroException and left the task stuck waiting forever.
    final EHExecutor executor =
        EHExecutor(concurrency: 2, rate: Rate(0, Duration(milliseconds: 50)));
    int completed = 0;

    await Future.wait([
      executor.scheduleTask(0, () async => completed++),
      executor.scheduleTask(0, () async => completed++),
    ]);

    expect(completed, 2);
    await executor.close();
  });
}
