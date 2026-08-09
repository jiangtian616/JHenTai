import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/inference/inference_task.dart';

void main() {
  test('cancellation token preserves its reason and throws cooperatively', () {
    final InferenceCancellationToken token = InferenceCancellationToken();

    expect(token.isCancelled, isFalse);
    expect(token.throwIfCancelled, returnsNormally);

    token.cancel('user stopped OCR');

    expect(token.isCancelled, isTrue);
    expect(token.reason, 'user stopped OCR');
    expect(
      token.throwIfCancelled,
      throwsA(
        isA<InferenceCancelledException>().having(
          (InferenceCancelledException error) => error.reason,
          'reason',
          'user stopped OCR',
        ),
      ),
    );
  });
}
