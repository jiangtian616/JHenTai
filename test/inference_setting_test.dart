import 'dart:async';
import 'dart:convert';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/inference/inference_safety.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/service/inference_service.dart';
import 'package:jhentai/src/setting/inference_setting.dart';

void main() {
  test('AI Core policy defaults are safe for existing configs', () {
    final InferenceSetting setting = InferenceSetting();

    setting.applyBeanConfig('{}');

    expect(setting.mode.value, InferenceBackendMode.auto);
    expect(setting.preferredBackend.value, InferenceBackend.auto);
    expect(setting.enableNnapi.value, isFalse);
    expect(setting.enableCpuFallback.value, isTrue);
  });

  test('AI Core policy round-trips and unknown enum values migrate safely', () {
    final InferenceSetting setting = InferenceSetting();
    setting.mode.value = InferenceBackendMode.manual;
    setting.preferredBackend.value = InferenceBackend.coreml;
    setting.enableNnapi.value = false;
    setting.enableCpuFallback.value = false;

    final InferenceSetting restored = InferenceSetting();
    restored.applyBeanConfig(setting.toConfigString());

    expect(restored.mode.value, InferenceBackendMode.manual);
    expect(restored.preferredBackend.value, InferenceBackend.coreml);
    expect(restored.enableNnapi.value, isFalse);
    expect(restored.enableCpuFallback.value, isFalse);

    restored.applyBeanConfig(
      jsonEncode(<String, dynamic>{
        'mode': 'futureMode',
        'preferredBackend': 'futureProvider',
      }),
    );
    expect(restored.mode.value, InferenceBackendMode.auto);
    expect(restored.preferredBackend.value, InferenceBackend.auto);
  });

  test('session state keeps provider, model and native session distinct', () {
    expect(
      classifyInferenceSessionState(
        backendAvailable: false,
        modelState: OnnxModelInstallState.ready,
        hasReadySessions: false,
        hasSessionError: false,
      ),
      InferenceSessionState.backendUnavailable,
    );
    expect(
      classifyInferenceSessionState(
        backendAvailable: true,
        modelState: OnnxModelInstallState.notInstalled,
        hasReadySessions: false,
        hasSessionError: false,
      ),
      InferenceSessionState.modelNotInstalled,
    );
    expect(
      classifyInferenceSessionState(
        backendAvailable: true,
        modelState: OnnxModelInstallState.ready,
        hasReadySessions: false,
        hasSessionError: false,
      ),
      InferenceSessionState.notTested,
    );
    expect(
      classifyInferenceSessionState(
        backendAvailable: true,
        modelState: OnnxModelInstallState.ready,
        hasReadySessions: true,
        hasSessionError: false,
      ),
      InferenceSessionState.ready,
    );
    expect(
      classifyInferenceSessionState(
        backendAvailable: true,
        modelState: OnnxModelInstallState.ready,
        hasReadySessions: false,
        hasSessionError: true,
      ),
      InferenceSessionState.failed,
    );
  });

  test(
    'provider policy blocks a failed accelerator and keeps CPU fallback',
    () {
      final List<ort.OrtProvider> available = <ort.OrtProvider>[
        ort.OrtProvider.CORE_ML,
        ort.OrtProvider.CPU,
      ];
      expect(
        InferenceProviderPolicy.providers(
          backend: 'coreml',
          available: available,
          enableNnapi: false,
          enableCpuFallback: true,
          canaryBlocked: false,
        ),
        <ort.OrtProvider>[ort.OrtProvider.CORE_ML, ort.OrtProvider.CPU],
      );
      expect(
        InferenceProviderPolicy.providers(
          backend: 'coreml',
          available: available,
          enableNnapi: false,
          enableCpuFallback: true,
          canaryBlocked: true,
        ),
        <ort.OrtProvider>[ort.OrtProvider.CPU],
      );
      expect(
        InferenceProviderPolicy.providers(
          backend: 'nnapi',
          available: <ort.OrtProvider>[
            ort.OrtProvider.NNAPI,
            ort.OrtProvider.CPU,
          ],
          enableNnapi: false,
          enableCpuFallback: true,
          canaryBlocked: false,
        ),
        <ort.OrtProvider>[ort.OrtProvider.CPU],
      );
    },
  );

  test('canary running state round-trips and blocks the same key', () {
    const InferenceCanaryKey key = InferenceCanaryKey(
      deviceModel: 'test-device',
      systemVersion: 'test-os',
      appVersion: '1.0+1',
      ortVersion: '1.23.0',
      modelHash: 'model-sha',
      epConfig: 'coreml',
    );
    final InferenceSetting setting = InferenceSetting();
    setting.canaryRecord.value = const InferenceCanaryRecord(
      status: InferenceCanaryStatus.running,
      key: key,
    );
    final InferenceSetting restored = InferenceSetting();
    restored.applyBeanConfig(setting.toConfigString());
    expect(
      InferenceProviderPolicy.isCanaryBlocked(key, restored.canaryRecord.value),
      isTrue,
    );
    restored.canaryRecord.value = const InferenceCanaryRecord(
      status: InferenceCanaryStatus.succeeded,
      key: key,
    );
    expect(
      InferenceProviderPolicy.isCanaryBlocked(key, restored.canaryRecord.value),
      isFalse,
    );
  });

  test('pixel budget scales 2208 square input below the hard limit', () {
    final InferencePixelSize fitted = const InferencePixelBudget(
      4 * 1024 * 1024,
    ).fit(2208, 2208, alignment: 32);
    expect(fitted.pixels, lessThanOrEqualTo(4 * 1024 * 1024));
    expect(fitted.width % 32, 0);
    expect(fitted.height % 32, 0);
  });

  test('inference task queue serializes overlapping calls', () async {
    final InferenceTaskQueue queue = InferenceTaskQueue();
    final Completer<void> gate = Completer<void>();
    int active = 0;
    int maximumActive = 0;
    Future<void> task() async {
      active++;
      maximumActive = maximumActive < active ? active : maximumActive;
      await gate.future;
      active--;
    }

    final Future<void> first = queue.run(task);
    final Future<void> second = queue.run(task);
    await Future<void>.delayed(Duration.zero);
    expect(maximumActive, 1);
    gate.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(maximumActive, 1);
  });
}
