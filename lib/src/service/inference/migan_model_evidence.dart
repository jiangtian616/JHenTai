/// Evidence captured from the official ModelScope API/card and a local ONNX
/// inspection of the pinned MI-GAN artifact.
class MiganModelEvidence {
  const MiganModelEvidence._();

  static const String modelId = 'phodit/migan-pipeline-v2';
  static const String modelPageUrl =
      'https://www.modelscope.cn/models/phodit/migan-pipeline-v2';
  static const String artifactUrl =
      'https://www.modelscope.cn/models/phodit/migan-pipeline-v2/resolve/master/migan_pipeline_v2.onnx';
  static const String sourceProjectUrl =
      'https://github.com/lxfater/inpaint-web';
  static const String revision = '78aada3f131d6594ee883f0a16753029a4d0e64b';
  static const int artifactSizeBytes = 28079181;
  static const String artifactSha256 =
      '6f1f3530a1a2324b19752018ce756088b07973cda8d7d890034ace5c8a48c40b';
  static const String declaredLicense =
      'Apache-2.0 (ModelScope README; metadata unset)';
  static const int onnxOpset = 17;
  static const String inputContract =
      'image:uint8[N,3,H,W], mask:uint8[N,1,H,W]';
  static const String outputContract = 'result:uint8[N,3,H,W]';
}
