/// Evidence-only record for the external manga-OCR TFLite repository.
///
/// This is intentionally not a downloadable model catalog entry. The
/// official repository exposes the two large LFS files with exact size/SHA,
/// but the required vocabulary/config files were only confirmed by size in
/// this run. Until every required file has a SHA-256, registering a downloader
/// would make an apparently installable model that cannot be integrity checked.
class MangaOcrModelArtifactEvidence {
  const MangaOcrModelArtifactEvidence({
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
  });

  final String fileName;
  final int sizeBytes;
  final String? sha256;
  final String url;

  bool get integrityConfirmed => sha256?.length == 64;
}

class MangaOcrModelEvidence {
  const MangaOcrModelEvidence._();

  static const String repositoryUrl =
      'https://huggingface.co/jgalamba/manga-ocr-kvcache-tflite';
  static const String licenseUrl =
      'https://huggingface.co/jgalamba/manga-ocr-kvcache-tflite/blob/main/LICENSE';
  static const String licenseName = 'Apache-2.0';
  static const String mirrorUrl =
      'https://hf-mirror.com/jgalamba/manga-ocr-kvcache-tflite';

  static const List<MangaOcrModelArtifactEvidence>
  artifacts = <MangaOcrModelArtifactEvidence>[
    MangaOcrModelArtifactEvidence(
      fileName: 'encoder_int8.tflite',
      sizeBytes: 87858976,
      sha256:
          'bf858e9189b66d2da915df36c1a3fa056a0795b9a7948461085dc06216747b9a',
      url:
          'https://huggingface.co/jgalamba/manga-ocr-kvcache-tflite/resolve/main/encoder_int8.tflite?download=true',
    ),
    MangaOcrModelArtifactEvidence(
      fileName: 'decoder_cache_fp16.tflite',
      sizeBytes: 49616592,
      sha256:
          '4695855693df18652a3b896fe97c492b943cd1128ed461fddd17155320e30025',
      url:
          'https://huggingface.co/jgalamba/manga-ocr-kvcache-tflite/resolve/main/decoder_cache_fp16.tflite?download=true',
    ),
    MangaOcrModelArtifactEvidence(
      fileName: 'mocr2025_vocab.csv',
      sizeBytes: 48468,
      sha256: null,
      url:
          'https://huggingface.co/jgalamba/manga-ocr-kvcache-tflite/resolve/main/mocr2025_vocab.csv?download=true',
    ),
    MangaOcrModelArtifactEvidence(
      fileName: 'config.json',
      sizeBytes: 2426,
      sha256: null,
      url:
          'https://huggingface.co/jgalamba/manga-ocr-kvcache-tflite/resolve/main/config.json?download=true',
    ),
  ];

  static bool get allRequiredHashesConfirmed => artifacts.every(
    (MangaOcrModelArtifactEvidence item) => item.integrityConfirmed,
  );

  static List<String> get missingHashes => artifacts
      .where((MangaOcrModelArtifactEvidence item) => !item.integrityConfirmed)
      .map((MangaOcrModelArtifactEvidence item) => item.fileName)
      .toList(growable: false);

  static const String blocker =
      'The official page confirms Apache-2.0 and the two TFLite LFS artifacts, '
      'but the vocabulary/config SHA-256 values were not independently '
      'retrieved in this run. The hf-mirror URL redirected to huggingface.co '
      'and the TLS connection failed. No downloader/catalog entry is exposed.';
}
