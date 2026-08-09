import 'dart:async';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/setting/inference_setting.dart';

import 'inference/ocr_inference_engine.dart';
import 'inference/onnx_model_store.dart';
import 'inference/onnx_ocr_engine.dart';
import 'inference/onnx_runtime.dart';
import 'inference/onnx_super_resolution_engine.dart';
import 'inference/super_resolution_inference_engine.dart';
import 'jh_service.dart';

InferenceService inferenceService = InferenceService();

enum InferenceSessionState {
  backendUnavailable,
  modelNotInstalled,
  notTested,
  ready,
  failed,
}

InferenceSessionState classifyInferenceSessionState({
  required bool backendAvailable,
  required OnnxModelInstallState modelState,
  required bool hasReadySessions,
  required bool hasSessionError,
}) {
  if (!backendAvailable) {
    return InferenceSessionState.backendUnavailable;
  }
  if (modelState != OnnxModelInstallState.ready) {
    return InferenceSessionState.modelNotInstalled;
  }
  if (hasSessionError) {
    return InferenceSessionState.failed;
  }
  return hasReadySessions
      ? InferenceSessionState.ready
      : InferenceSessionState.notTested;
}

/// Unified AI Core for OCR and image super-resolution.
///
/// The service owns native runtime detection, provider policy, model/session
/// lifecycle, and the domain engines. UI reads the same resolved providers that
/// are passed to native session creation; there is no separate cosmetic path.
class InferenceService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  OcrInferenceEngine? _ocrEngine;
  SuperResolutionInferenceEngine? _superResolutionEngine;
  final RxList<InferenceBackend> availableBackends = <InferenceBackend>[].obs;
  final RxBool runtimeReady = false.obs;
  final List<Worker> _settingWorkers = <Worker>[];

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies..add(inferenceSetting);

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
    Get.put(OnnxModelStore.instance, permanent: true);

    runtimeReady.value = await OnnxRuntime.instance.initialize();
    _refreshAvailableBackends();
    await OnnxModelStore.instance.refreshInstalledState();

    _ocrEngine = OnnxOcrInferenceEngine(
      providerResolver: () => providersFor(InferenceDomain.ocr),
    );
    _superResolutionEngine = OnnxSuperResolutionInferenceEngine(
      providerResolver: () => providersFor(InferenceDomain.superResolution),
    );

    _settingWorkers.addAll(<Worker>[
      ever<InferenceBackendMode>(
        inferenceSetting.mode,
        (_) => _backendPolicyChanged(),
      ),
      ever<InferenceBackend>(
        inferenceSetting.preferredBackend,
        (_) => _backendPolicyChanged(),
      ),
      ever<bool>(
        inferenceSetting.enableCpuFallback,
        (_) => _backendPolicyChanged(),
      ),
      ever<bool>(inferenceSetting.enableNnapi, (_) => _backendPolicyChanged()),
    ]);
    await _saveDetectionSummary();
  }

  @override
  Future<void> doAfterBeanReady() async {}

  @override
  void onClose() {
    for (final Worker worker in _settingWorkers) {
      worker.dispose();
    }
    unawaited(OnnxRuntime.instance.dispose());
    super.onClose();
  }

  OnnxModelStore get onnxModels => OnnxModelStore.instance;

  OcrInferenceEngine get ocrEngine =>
      _ocrEngine ?? const NotConfiguredOcrInferenceEngine();

  SuperResolutionInferenceEngine get superResolutionEngine =>
      _superResolutionEngine ??
      const NotConfiguredSuperResolutionInferenceEngine();

  void registerOcrEngine(OcrInferenceEngine engine) {
    _ocrEngine = engine;
    updateSafely();
  }

  void registerSuperResolutionEngine(SuperResolutionInferenceEngine engine) {
    _superResolutionEngine = engine;
    updateSafely();
  }

  List<InferenceBackend> detectAvailableBackends() =>
      List<InferenceBackend>.unmodifiable(availableBackends);

  void _refreshAvailableBackends() {
    final Set<InferenceBackend> detected =
        OnnxRuntime.instance.availableProviders
            .map(_backendForProvider)
            .whereType<InferenceBackend>()
            .toSet();
    final List<InferenceBackend> platformPriority =
        GetPlatform.isWindows
            ? const <InferenceBackend>[
              InferenceBackend.directml,
              InferenceBackend.cuda,
              InferenceBackend.xnnpack,
              InferenceBackend.cpu,
            ]
            : GetPlatform.isLinux
            ? const <InferenceBackend>[
              InferenceBackend.cuda,
              InferenceBackend.openvino,
              InferenceBackend.xnnpack,
              InferenceBackend.cpu,
            ]
            : GetPlatform.isAndroid
            ? const <InferenceBackend>[
              InferenceBackend.nnapi,
              InferenceBackend.xnnpack,
              InferenceBackend.cpu,
            ]
            : (GetPlatform.isIOS || GetPlatform.isMacOS)
            ? const <InferenceBackend>[
              InferenceBackend.coreml,
              InferenceBackend.xnnpack,
              InferenceBackend.cpu,
            ]
            : const <InferenceBackend>[
              InferenceBackend.xnnpack,
              InferenceBackend.cpu,
            ];
    availableBackends.assignAll(
      platformPriority.where(detected.contains).toList(growable: false),
    );
  }

  Set<InferenceBackend> _supportedBy(InferenceDomain domain) =>
      switch (domain) {
        InferenceDomain.ocr => const <InferenceBackend>{
          InferenceBackend.directml,
          InferenceBackend.cuda,
          InferenceBackend.openvino,
          InferenceBackend.nnapi,
          InferenceBackend.coreml,
          InferenceBackend.xnnpack,
          InferenceBackend.cpu,
        },
        InferenceDomain.superResolution => const <InferenceBackend>{
          InferenceBackend.directml,
          InferenceBackend.cuda,
          InferenceBackend.openvino,
          InferenceBackend.nnapi,
          InferenceBackend.coreml,
          InferenceBackend.xnnpack,
          InferenceBackend.cpu,
        },
      };

  InferenceBackend? resolveBackendFor(InferenceDomain domain) {
    final Set<InferenceBackend> supported = _supportedBy(domain);
    final List<InferenceBackend> detected = availableBackends
        .where(supported.contains)
        .where(
          (InferenceBackend backend) =>
              backend != InferenceBackend.nnapi ||
              inferenceSetting.enableNnapi.value,
        )
        .toList(growable: false);

    if (inferenceSetting.mode.value == InferenceBackendMode.cpu) {
      return detected.contains(InferenceBackend.cpu)
          ? InferenceBackend.cpu
          : null;
    }
    if (inferenceSetting.mode.value == InferenceBackendMode.manual &&
        inferenceSetting.preferredBackend.value != InferenceBackend.auto) {
      final InferenceBackend preferred =
          inferenceSetting.preferredBackend.value;
      if (detected.contains(preferred)) {
        return preferred;
      }
      return inferenceSetting.enableCpuFallback.value &&
              detected.contains(InferenceBackend.cpu)
          ? InferenceBackend.cpu
          : null;
    }
    return detected.isEmpty ? null : detected.first;
  }

  List<ort.OrtProvider> providersFor(InferenceDomain domain) {
    final InferenceBackend? backend = resolveBackendFor(domain);
    if (backend == null) {
      return const <ort.OrtProvider>[];
    }
    final ort.OrtProvider? primary = _providerForBackend(backend);
    if (primary == null) {
      return const <ort.OrtProvider>[];
    }
    final List<ort.OrtProvider> providers = <ort.OrtProvider>[primary];
    if (primary != ort.OrtProvider.CPU &&
        inferenceSetting.enableCpuFallback.value &&
        OnnxRuntime.instance.availableProviders.contains(ort.OrtProvider.CPU)) {
      providers.add(ort.OrtProvider.CPU);
    }
    return providers;
  }

  InferenceSessionState sessionStateFor(InferenceDomain domain) {
    final String manifestId = _manifestIdFor(domain);
    final OnnxModelInstallState modelState =
        onnxModels.installStates[manifestId] ??
        OnnxModelInstallState.notInstalled;
    final List<String> paths = _modelPathsFor(domain);
    return classifyInferenceSessionState(
      backendAvailable: runtimeReady.value && resolveBackendFor(domain) != null,
      modelState: modelState,
      hasReadySessions: OnnxRuntime.instance.hasReadySessions(paths),
      hasSessionError: OnnxRuntime.instance.sessionErrorFor(paths) != null,
    );
  }

  String _manifestIdFor(InferenceDomain domain) => switch (domain) {
    InferenceDomain.ocr => OnnxModelStore.ocrManifestId,
    InferenceDomain.superResolution => OnnxModelStore.superResolutionManifestId,
  };

  List<String> _modelPathsFor(InferenceDomain domain) {
    final Map<String, String>? files = onnxModels.manifestFilePaths(
      _manifestIdFor(domain),
    );
    if (files == null) {
      return const <String>[];
    }
    return switch (domain) {
      InferenceDomain.ocr => <String>[
        if (files['det'] case final String path) path,
        if (files['cls'] case final String path) path,
        if (files['rec'] case final String path) path,
      ],
      InferenceDomain.superResolution => <String>[
        if (files['model'] case final String path) path,
      ],
    };
  }

  String frameworkDetectionSummary() {
    final String providers = OnnxRuntime.instance.availableProviders
        .map((ort.OrtProvider provider) => provider.name)
        .join(' / ');
    return providers.isEmpty ? 'ONNX Runtime unavailable' : providers;
  }

  Future<void> refreshDetection() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    runtimeReady.value = await OnnxRuntime.instance.initialize();
    _refreshAvailableBackends();
    await OnnxModelStore.instance.refreshInstalledState();
    stopwatch.stop();
    await _saveDetectionSummary();
    await inferenceSetting.saveBenchmarkSummary(
      'provider/model probe ${stopwatch.elapsedMilliseconds} ms',
    );
    updateSafely();
  }

  Future<void> _saveDetectionSummary() =>
      inferenceSetting.saveDetectedDeviceLabel(frameworkDetectionSummary());

  void _backendPolicyChanged() {
    unawaited(OnnxRuntime.instance.closeSessions());
    updateSafely();
  }

  InferenceBackend? _backendForProvider(ort.OrtProvider provider) =>
      switch (provider) {
        ort.OrtProvider.CPU => InferenceBackend.cpu,
        ort.OrtProvider.DIRECT_ML => InferenceBackend.directml,
        ort.OrtProvider.CUDA => InferenceBackend.cuda,
        ort.OrtProvider.OPEN_VINO => InferenceBackend.openvino,
        ort.OrtProvider.NNAPI => InferenceBackend.nnapi,
        ort.OrtProvider.CORE_ML => InferenceBackend.coreml,
        ort.OrtProvider.XNNPACK => InferenceBackend.xnnpack,
        _ => null,
      };

  ort.OrtProvider? _providerForBackend(InferenceBackend backend) =>
      switch (backend) {
        InferenceBackend.cpu => ort.OrtProvider.CPU,
        InferenceBackend.directml => ort.OrtProvider.DIRECT_ML,
        InferenceBackend.cuda => ort.OrtProvider.CUDA,
        InferenceBackend.openvino => ort.OrtProvider.OPEN_VINO,
        InferenceBackend.nnapi => ort.OrtProvider.NNAPI,
        InferenceBackend.coreml => ort.OrtProvider.CORE_ML,
        InferenceBackend.xnnpack => ort.OrtProvider.XNNPACK,
        InferenceBackend.auto || InferenceBackend.vulkan => null,
      };
}
