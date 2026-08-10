import 'dart:async';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart' as ort;
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/setting/inference_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';

import 'inference/ocr_inference_engine.dart';
import 'inference/onnx_model_store.dart';
import 'inference/onnx_ocr_worker.dart';
import 'inference/onnx_runtime.dart';
import 'inference/onnx_super_resolution_worker.dart';
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

  /// OCR and super-resolution sessions live inside worker isolates, so the
  /// main-isolate session registry never sees them. These reactive flags mirror
  /// the worker's session state so the Obx-based inference settings page
  /// live-updates when the workers report readiness.
  final RxBool _ocrSessionsVerified = false.obs;
  final RxnString _ocrSessionError = RxnString();
  final RxBool _srSessionsVerified = false.obs;
  final RxnString _srSessionError = RxnString();

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

    _ocrEngine = OnnxOcrIsolateEngine(
      providerResolver: () => providersFor(InferenceDomain.ocr),
      modelIdResolver: () => imageTranslationSetting.onnxModelId.value,
      onSessionStateChanged: ({required bool verified, String? error}) {
        _ocrSessionsVerified.value = verified;
        _ocrSessionError.value = error;
        updateSafely();
      },
    );
    _superResolutionEngine = OnnxSuperResolutionIsolateEngine(
      providerResolver: () => providersFor(InferenceDomain.superResolution),
      modelIdResolver: () => superResolutionSetting.onnxModelId.value,
      onSessionStateChanged: ({required bool verified, String? error}) {
        _srSessionsVerified.value = verified;
        _srSessionError.value = error;
        updateSafely();
      },
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
      // Switching the active ONNX super-resolution model must drop the old
      // model's native session; the new manifest resolves lazily on the next
      // upscale. In-flight tasks finish (they hold a session lease), so a tap
      // mid-batch cannot close a session out from under a running tile.
      ever<String>(
        superResolutionSetting.onnxModelId,
        (_) => _superResolutionModelChanged(),
      ),
      // Same for the active ONNX OCR model (e.g. PP-OCRv6 small vs tiny).
      ever<String>(
        imageTranslationSetting.onnxModelId,
        (_) => _ocrModelChanged(),
      ),
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
    final OcrInferenceEngine? ocrEngine = _ocrEngine;
    if (ocrEngine is OnnxOcrIsolateEngine) {
      unawaited(ocrEngine.dispose());
    }
    final SuperResolutionInferenceEngine? srEngine = _superResolutionEngine;
    if (srEngine is OnnxSuperResolutionIsolateEngine) {
      unawaited(srEngine.dispose());
    }
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
    final bool isOcr = domain == InferenceDomain.ocr;
    final bool isSr = domain == InferenceDomain.superResolution;
    return classifyInferenceSessionState(
      backendAvailable: runtimeReady.value && resolveBackendFor(domain) != null,
      modelState: modelState,
      // OCR and super-resolution sessions are owned by worker isolates; mirror
      // their state.
      hasReadySessions:
          OnnxRuntime.instance.hasReadySessions(paths) ||
          (isOcr && _ocrSessionsVerified.value) ||
          (isSr && _srSessionsVerified.value),
      hasSessionError:
          OnnxRuntime.instance.sessionErrorFor(paths) != null ||
          (isOcr && _ocrSessionError.value != null) ||
          (isSr && _srSessionError.value != null),
    );
  }

  String _manifestIdFor(InferenceDomain domain) => switch (domain) {
    // Follow the active ONNX model the user selected.
    InferenceDomain.ocr => imageTranslationSetting.onnxModelId.value,
    InferenceDomain.superResolution => superResolutionSetting.onnxModelId.value,
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
    // Provider availability may have changed: reset the mirrors and ask the
    // worker isolates to re-initialize (which also retries a transient startup
    // failure), re-arming the mirrors from their results.
    _resetSessionMirrors();
    unawaited(_reinitializeWorkers());
    updateSafely();
  }

  Future<void> _saveDetectionSummary() =>
      inferenceSetting.saveDetectedDeviceLabel(frameworkDetectionSummary());

  void _backendPolicyChanged() {
    _resetSessionMirrors();
    updateSafely();
    final List<Future<void>> closes = <Future<void>>[
      OnnxRuntime.instance.closeSessions(),
    ];
    final OcrInferenceEngine? ocrEngine = _ocrEngine;
    if (ocrEngine is OnnxOcrIsolateEngine) {
      closes.add(ocrEngine.closeSessions());
    }
    final SuperResolutionInferenceEngine? srEngine = _superResolutionEngine;
    if (srEngine is OnnxSuperResolutionIsolateEngine) {
      closes.add(srEngine.closeSessions());
    }
    // Re-arm the mirrors only after the workers acknowledge the close, so a
    // racing in-flight success cannot leave the mirror stale once the sessions
    // are gone.
    Future.wait(closes).whenComplete(() {
      _resetSessionMirrors();
      updateSafely();
    });
  }

  /// Clears both session mirrors back to the "not verified / no error" state.
  void _resetSessionMirrors() {
    _ocrSessionsVerified.value = false;
    _ocrSessionError.value = null;
    _srSessionsVerified.value = false;
    _srSessionError.value = null;
  }

  /// Asks each spawned worker isolate to re-run its ONNX runtime
  /// initialization and re-arms its mirror from the outcome. A worker that was
  /// never spawned stays "not tested"; a spawned worker that fails to
  /// re-initialize is marked failed so the settings page shows it.
  Future<void> _reinitializeWorkers() async {
    final OcrInferenceEngine? ocrEngine = _ocrEngine;
    if (ocrEngine is OnnxOcrIsolateEngine) {
      final bool? ok = await ocrEngine.reinitialize();
      if (ok != null) {
        _ocrSessionsVerified.value = ok;
        _ocrSessionError.value =
            ok ? null : 'ONNX runtime reinitialization failed';
        updateSafely();
      }
    }
    final SuperResolutionInferenceEngine? srEngine = _superResolutionEngine;
    if (srEngine is OnnxSuperResolutionIsolateEngine) {
      final bool? ok = await srEngine.reinitialize();
      if (ok != null) {
        _srSessionsVerified.value = ok;
        _srSessionError.value =
            ok ? null : 'ONNX runtime reinitialization failed';
        updateSafely();
      }
    }
  }

  /// The active ONNX super-resolution model changed: re-validate the session
  /// state (the new manifest resolves lazily on the next upscale) and drop the
  /// old model's cached native sessions.
  void _superResolutionModelChanged() {
    _resetSessionMirrors();
    updateSafely();
    final SuperResolutionInferenceEngine? srEngine = _superResolutionEngine;
    if (srEngine is OnnxSuperResolutionIsolateEngine) {
      srEngine.closeSessions().whenComplete(() {
        _resetSessionMirrors();
        updateSafely();
      });
    }
  }

  /// The active ONNX OCR model changed (e.g. PP-OCRv6 small vs tiny): drop the
  /// old model's cached native sessions; the new manifest resolves lazily on
  /// the next recognize.
  void _ocrModelChanged() {
    _resetSessionMirrors();
    updateSafely();
    final OcrInferenceEngine? ocrEngine = _ocrEngine;
    if (ocrEngine is OnnxOcrIsolateEngine) {
      ocrEngine.closeSessions().whenComplete(() {
        _resetSessionMirrors();
        updateSafely();
      });
    }
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
