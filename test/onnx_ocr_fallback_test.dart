import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/inference/inference_safety.dart';
import 'package:jhentai/src/service/inference/inference_task.dart';
import 'package:jhentai/src/service/inference/onnx_ocr_worker.dart';

void main() {
  const InferenceSessionSafetyConfig acceleratedConfig =
      InferenceSessionSafetyConfig(
        useArena: false,
        providerOptions: <String, Map<String, String>>{
          'CORE_ML': <String, String>{
            'MLComputeUnits': 'CPUAndNeuralEngine',
            'RequireStaticInputShapes': '1',
          },
        },
        sessionConfigEntries: <String, String>{
          'session.enable_cpu_mem_arena': '0',
        },
        mlComputeUnits: 'CPUAndNeuralEngine',
        requireStaticShapes: true,
        memoryBudgetBytes: 128 * 1024 * 1024,
        maxInputPixels: 4 * 1024 * 1024,
      );

  test('accelerator failure retries the same OCR task once on CPU', () async {
    final List<List<ort.OrtProvider>> attempts = <List<ort.OrtProvider>>[];
    final List<InferenceSessionSafetyConfig> configs =
        <InferenceSessionSafetyConfig>[];
    int started = 0;
    int succeeded = 0;
    int failed = 0;
    int resets = 0;

    final String result = await runOnnxOcrWithCpuFallback<String>(
      primaryProviders: const <ort.OrtProvider>[
        ort.OrtProvider.CORE_ML,
        ort.OrtProvider.CPU,
      ],
      primarySafetyConfig: acceleratedConfig,
      cancellationToken: InferenceCancellationToken(),
      modelHash: 'model-hash',
      onAcceleratorStarted: (_, __) async => started++,
      onAcceleratorSucceeded: (_, __) async => succeeded++,
      onAcceleratorFailed: (_, __, ___) async => failed++,
      resetAcceleratedSessions: () async => resets++,
      attempt: ({required providers, required safetyConfig}) async {
        attempts.add(List<ort.OrtProvider>.from(providers));
        configs.add(safetyConfig);
        if (providers.first == ort.OrtProvider.CORE_ML) {
          throw StateError('coreml session failed');
        }
        return 'cpu-result';
      },
    );

    expect(result, 'cpu-result');
    expect(attempts, <List<ort.OrtProvider>>[
      <ort.OrtProvider>[ort.OrtProvider.CORE_ML, ort.OrtProvider.CPU],
      <ort.OrtProvider>[ort.OrtProvider.CPU],
    ]);
    expect(configs.first.useArena, isFalse);
    expect(configs.last.useArena, isTrue);
    expect(configs.last.providerOptions, isEmpty);
    expect(started, 1);
    expect(succeeded, 0);
    expect(failed, 1);
    expect(resets, 1);
  });

  test('accelerator success does not start a CPU retry', () async {
    int attempts = 0;
    int succeeded = 0;

    final String result = await runOnnxOcrWithCpuFallback<String>(
      primaryProviders: const <ort.OrtProvider>[
        ort.OrtProvider.CORE_ML,
        ort.OrtProvider.CPU,
      ],
      primarySafetyConfig: acceleratedConfig,
      cancellationToken: InferenceCancellationToken(),
      modelHash: 'model-hash',
      onAcceleratorSucceeded: (_, __) async => succeeded++,
      resetAcceleratedSessions: () async => fail('must not reset sessions'),
      attempt: ({required providers, required safetyConfig}) async {
        attempts++;
        return 'accelerated-result';
      },
    );

    expect(result, 'accelerated-result');
    expect(attempts, 1);
    expect(succeeded, 1);
  });

  test('cancellation never records provider failure or retries', () async {
    int failed = 0;
    int resets = 0;

    final Future<String> result = runOnnxOcrWithCpuFallback<String>(
      primaryProviders: const <ort.OrtProvider>[
        ort.OrtProvider.CORE_ML,
        ort.OrtProvider.CPU,
      ],
      primarySafetyConfig: acceleratedConfig,
      cancellationToken: InferenceCancellationToken(),
      modelHash: 'model-hash',
      onAcceleratorFailed: (_, __, ___) async => failed++,
      resetAcceleratedSessions: () async => resets++,
      attempt: ({required providers, required safetyConfig}) async {
        throw const InferenceCancelledException('user stopped');
      },
    );

    await expectLater(result, throwsA(isA<InferenceCancelledException>()));
    expect(failed, 0);
    expect(resets, 0);
  });

  test('disabled CPU fallback preserves the accelerator error', () async {
    int attempts = 0;
    int failed = 0;

    final Future<String> result = runOnnxOcrWithCpuFallback<String>(
      primaryProviders: const <ort.OrtProvider>[ort.OrtProvider.CORE_ML],
      primarySafetyConfig: acceleratedConfig,
      cancellationToken: InferenceCancellationToken(),
      modelHash: 'model-hash',
      onAcceleratorFailed: (_, __, ___) async => failed++,
      resetAcceleratedSessions: () async => fail('must not reset sessions'),
      attempt: ({required providers, required safetyConfig}) async {
        attempts++;
        throw StateError('original accelerator error');
      },
    );

    await expectLater(
      result,
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'original accelerator error',
        ),
      ),
    );
    expect(attempts, 1);
    expect(failed, 1);
  });

  test('CPU retry failure is final and never recurses', () async {
    int attempts = 0;
    int resets = 0;

    final Future<String> result = runOnnxOcrWithCpuFallback<String>(
      primaryProviders: const <ort.OrtProvider>[
        ort.OrtProvider.CORE_ML,
        ort.OrtProvider.CPU,
      ],
      primarySafetyConfig: acceleratedConfig,
      cancellationToken: InferenceCancellationToken(),
      modelHash: 'model-hash',
      resetAcceleratedSessions: () async => resets++,
      attempt: ({required providers, required safetyConfig}) async {
        attempts++;
        if (providers.first == ort.OrtProvider.CORE_ML) {
          throw StateError('accelerator failed');
        }
        throw StateError('cpu failed');
      },
    );

    await expectLater(
      result,
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          'cpu failed',
        ),
      ),
    );
    expect(attempts, 2);
    expect(resets, 1);
  });

  test('cancellation between attempts prevents CPU execution', () async {
    final InferenceCancellationToken token = InferenceCancellationToken();
    int attempts = 0;
    int resets = 0;

    final Future<String> result = runOnnxOcrWithCpuFallback<String>(
      primaryProviders: const <ort.OrtProvider>[
        ort.OrtProvider.NNAPI,
        ort.OrtProvider.CPU,
      ],
      primarySafetyConfig: acceleratedConfig,
      cancellationToken: token,
      modelHash: 'model-hash',
      onAcceleratorFailed: (_, __, ___) async => token.cancel('page closed'),
      resetAcceleratedSessions: () async => resets++,
      attempt: ({required providers, required safetyConfig}) async {
        attempts++;
        throw StateError('nnapi failed');
      },
    );

    await expectLater(
      result,
      throwsA(
        isA<InferenceCancelledException>().having(
          (InferenceCancelledException error) => error.reason,
          'reason',
          'page closed',
        ),
      ),
    );
    expect(attempts, 1);
    expect(resets, 0);
  });
}
