/// Pinned evidence for the optional CTD runtime download.
class CtdModelEvidence {
  const CtdModelEvidence._();

  static const String repositoryUrl =
      'https://github.com/dmMaze/comic-text-detector';
  static const String licenseName = 'GPL-3.0-only';
  static const String licenseUrl =
      'https://github.com/dmMaze/comic-text-detector/blob/master/LICENSE';
  static const String referencedModelReleaseUrl =
      'https://github.com/zyddnys/manga-image-translator/releases/tag/beta-0.3';
  static const String artifactUrl =
      'https://github.com/zyddnys/manga-image-translator/releases/download/beta-0.3/comictextdetector.pt.onnx';
  static const int artifactSizeBytes = 94669756;
  static const String artifactSha256 =
      '1a86ace74961413cbd650002e7bb4dcec4980ffa21b2f19b86933372071d718f';
  static const bool modelArtifactPinned = true;
  static const bool nativeRuntimeVerified = true;
  static const String inputName = 'images';
  static const List<int> inputShape = <int>[1, 3, 1024, 1024];
  static const String segmentationOutputName = 'seg';
  static const List<int> segmentationOutputShape = <int>[1, 1, 1024, 1024];
}
