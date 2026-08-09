import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/service/inference_service.dart';
import 'package:jhentai/src/setting/inference_setting.dart';

void main() {
  test('AI Core policy defaults are safe for existing configs', () {
    final InferenceSetting setting = InferenceSetting();

    setting.applyBeanConfig('{}');

    expect(setting.mode.value, InferenceBackendMode.auto);
    expect(setting.preferredBackend.value, InferenceBackend.auto);
    expect(setting.enableNnapi.value, isTrue);
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
}
