/// Evidence-only CTD record.
///
/// CTD is intentionally not exposed in the verified model catalog: the
/// upstream project is GPL-3.0 and the release/model files referenced by its
/// documentation are not pinned here with a complete five-platform runtime
/// contract. The adapter therefore remains safe but unavailable by default.
class CtdModelEvidence {
  const CtdModelEvidence._();

  static const String repositoryUrl =
      'https://github.com/dmMaze/comic-text-detector';
  static const String licenseName = 'GPL-3.0-only';
  static const String licenseUrl =
      'https://github.com/dmMaze/comic-text-detector/blob/master/LICENSE';
  static const String referencedModelReleaseUrl =
      'https://github.com/zyddnys/manga-image-translator/releases/tag/beta-0.2.1';
  static const bool modelArtifactPinned = false;
  static const bool nativeRuntimeVerified = false;
  static const String blocker =
      'No redistributable CTD artifact, checksum, and five-platform native '
      'runtime are pinned in this checkout; no catalog entry or isReady=true '
      'path is exposed.';
}
