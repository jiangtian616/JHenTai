import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/inference/onnx_model_store.dart';
import 'package:jhentai/src/service/inference_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
import 'package:jhentai/src/setting/inference_setting.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_apple_settings_list_view.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';

/// OCR 与图像超分共用的 AI Core 运行后端入口。
class SettingInferencePage extends StatelessWidget {
  const SettingInferencePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('inferenceSetting'.tr),
        actions: [
          EHAppleIconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'inferenceRefresh'.tr,
            onPressed: inferenceService.refreshDetection,
          ),
        ],
      ),
      body: Obx(() {
        inferenceService.runtimeReady.value;
        inferenceService.availableBackends.length;
        inferenceService.onnxModels.installStates.length;
        return EHAppleSettingsListView(
          groups: [
            EHAppleSettingsGroup(
              title: 'inferenceModeSection'.tr,
              children: [_buildMode()],
            ),
            if (inferenceSetting.mode.value == InferenceBackendMode.manual)
              EHAppleSettingsGroup(
                title: 'inferenceManualSection'.tr,
                children: [_buildPreferredBackend()],
              ),
            EHAppleSettingsGroup(
              title: 'inferenceDetectionSection'.tr,
              children: [
                _buildDetectedDevice(),
                _buildResolvedBackend(InferenceDomain.ocr),
                _buildResolvedBackend(InferenceDomain.superResolution),
                if (GetPlatform.isAndroid) _buildEnableNnapi(),
                _buildEnableCpuFallback(),
              ],
            ),
            EHAppleSettingsGroup(
              title: 'inferenceModelSection'.tr,
              children: [
                _buildModelStatus(
                  'inferenceEngineOcr'.tr,
                  imageTranslationSetting.onnxModelId.value,
                  InferenceDomain.ocr,
                  () => toRoute(Routes.imageTranslation),
                ),
                _buildModelStatus(
                  'inferenceEngineSuperResolution'.tr,
                  superResolutionSetting.onnxModelId.value,
                  InferenceDomain.superResolution,
                  () => toRoute(Routes.superResolution),
                ),
                if (inferenceSetting.benchmarkSummary.value != null)
                  _buildBenchmark(),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMode() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SegmentedButton<InferenceBackendMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: InferenceBackendMode.auto,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text('inferenceModeAuto'.tr),
          ),
          ButtonSegment(
            value: InferenceBackendMode.manual,
            icon: const Icon(Icons.tune, size: 18),
            label: Text('inferenceModeManual'.tr),
          ),
          ButtonSegment(
            value: InferenceBackendMode.cpu,
            icon: const Icon(Icons.memory, size: 18),
            label: Text('inferenceModeCpu'.tr),
          ),
        ],
        selected: {inferenceSetting.mode.value},
        onSelectionChanged:
            (selection) => inferenceSetting.saveMode(selection.first),
      ),
    );
  }

  Widget _buildPreferredBackend() {
    final List<InferenceBackend> candidates =
        inferenceService.detectAvailableBackends();
    if (candidates.isEmpty) {
      return ListTile(
        title: Text('inferencePreferredBackend'.tr),
        subtitle: Text('inferenceDeviceNotDetected'.tr),
      );
    }
    final InferenceBackend selected =
        candidates.contains(inferenceSetting.preferredBackend.value)
            ? inferenceSetting.preferredBackend.value
            : candidates.first;
    return ListTile(
      title: Text('inferencePreferredBackend'.tr),
      trailing: EHCodexStyleDropdown<InferenceBackend>(
        value: selected,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (value) {
          if (value != null) {
            inferenceSetting.savePreferredBackend(value);
          }
        },
        items:
            candidates
                .map(
                  (backend) => DropdownMenuItem(
                    value: backend,
                    child: Text(backend.label),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildDetectedDevice() {
    return ListTile(
      title: Text('inferenceDetectedDevice'.tr),
      subtitle: Text(
        inferenceSetting.detectedDeviceLabel.value ??
            'inferenceDeviceNotDetected'.tr,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildResolvedBackend(InferenceDomain domain) {
    final String domainLabel =
        domain == InferenceDomain.ocr
            ? 'inferenceDomainOcr'.tr
            : 'inferenceDomainSuperResolution'.tr;
    return Obx(
      () => ListTile(
        title: Text(domainLabel),
        subtitle: Text(
          inferenceService.resolveBackendFor(domain)?.label ??
              'inferenceDeviceNotDetected'.tr,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.memory, size: 18),
      ),
    );
  }

  Widget _buildEnableNnapi() {
    return EHAppleSwitchListTile(
      title: Text('inferenceEnableNnapi'.tr),
      subtitle: Text(
        'inferenceEnableNnapiHint'.tr,
        style: const TextStyle(fontSize: 12),
      ),
      value: inferenceSetting.enableNnapi.value,
      onChanged: inferenceSetting.saveEnableNnapi,
    );
  }

  Widget _buildEnableCpuFallback() {
    return EHAppleSwitchListTile(
      title: Text('inferenceEnableCpuFallback'.tr),
      subtitle: Text(
        'inferenceEnableCpuFallbackHint'.tr,
        style: const TextStyle(fontSize: 12),
      ),
      value: inferenceSetting.enableCpuFallback.value,
      onChanged: inferenceSetting.saveEnableCpuFallback,
    );
  }

  Widget _buildModelStatus(
    String title,
    String manifestId,
    InferenceDomain domain,
    VoidCallback onTap,
  ) {
    final OnnxModelInstallState state =
        inferenceService.onnxModels.installStates[manifestId] ??
        OnnxModelInstallState.notInstalled;
    final bool modelReady = state == OnnxModelInstallState.ready;
    final InferenceSessionState sessionState = inferenceService.sessionStateFor(
      domain,
    );
    final bool sessionReady = sessionState == InferenceSessionState.ready;
    final String modelStatus = switch (state) {
      OnnxModelInstallState.notInstalled => 'inferenceModelNotDownloaded'.tr,
      OnnxModelInstallState.validating => 'inferenceModelValidating'.tr,
      OnnxModelInstallState.ready => 'inferenceModelVerified'.tr,
      OnnxModelInstallState.invalid => 'inferenceModelInvalid'.tr,
    };
    final String sessionStatus = switch (sessionState) {
      InferenceSessionState.backendUnavailable =>
        'inferenceSessionBackendUnavailable'.tr,
      InferenceSessionState.modelNotInstalled =>
        'inferenceSessionWaitingForModel'.tr,
      InferenceSessionState.notTested => 'inferenceSessionNotTested'.tr,
      InferenceSessionState.ready => 'inferenceSessionReady'.tr,
      InferenceSessionState.failed => 'inferenceSessionFailed'.tr,
    };
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(modelStatus, style: const TextStyle(fontSize: 12)),
          Text(
            '${'inferenceSessionStatus'.tr}: $sessionStatus',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      trailing: Icon(
        sessionState == InferenceSessionState.failed
            ? Icons.error_outline
            : modelReady && sessionReady
            ? Icons.check_circle_outline
            : Icons.circle_outlined,
        color:
            sessionState == InferenceSessionState.failed
                ? Colors.red
                : modelReady && sessionReady
                ? Colors.green
                : Colors.grey,
        size: 18,
      ),
      onTap: onTap,
    );
  }

  Widget _buildBenchmark() {
    return ListTile(
      leading: const Icon(Icons.speed, size: 20),
      title: Text(
        inferenceSetting.benchmarkSummary.value!,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
