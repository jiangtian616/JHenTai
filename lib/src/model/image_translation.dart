/// Lifecycle of one page in the translation pipeline.
///
/// [failed] is retained for compatibility with callers that only know about a
/// generic translation failure. Download and OCR failures are deliberately
/// represented separately so a batch cannot mistake an OCR exception for a
/// completed page.
enum ImageTranslationStatus {
  idle,
  queued,
  downloading,
  downloadError,
  recognizing,
  ocrError,
  noText,
  translating,
  success,
  canceled,
  failed,
}

enum ImageTranslationStage {
  idle,
  downloading,
  recognizing,
  translating,
  masking,
  embedding,
  done,
}

class RecognizedTextBlock {
  final String text;
  final double confidence;
  final double left;
  final double top;
  final double width;
  final double height;

  const RecognizedTextBlock({
    required this.text,
    required this.confidence,
    this.left = 0,
    this.top = 0,
    this.width = 0,
    this.height = 0,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'confidence': confidence,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  factory RecognizedTextBlock.fromJson(Map<String, dynamic> json) =>
      RecognizedTextBlock(
        text: json['text'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        left: (json['left'] as num?)?.toDouble() ?? 0,
        top: (json['top'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
      );
}

/// A detected text container (speech bubble, caption box, or similar) in the
/// source image's upright pixel coordinates. Its block indices point back to
/// the OCR lines that belong to the container.
class RecognizedTextContainer {
  const RecognizedTextContainer({
    required this.blockIndices,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.confidence = 0,
  });

  final List<int> blockIndices;
  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'blockIndices': blockIndices,
    'left': left,
    'top': top,
    'width': width,
    'height': height,
    'confidence': confidence,
  };

  factory RecognizedTextContainer.fromJson(Map<String, dynamic> json) =>
      RecognizedTextContainer(
        blockIndices: (json['blockIndices'] as List? ?? const [])
            .whereType<num>()
            .map((num index) => index.toInt())
            .toList(growable: false),
        left: (json['left'] as num?)?.toDouble() ?? 0,
        top: (json['top'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

class ImageTranslationResult {
  final ImageTranslationStatus status;
  final String sourceText;
  final String translatedText;
  final List<String> translatedGroups;
  final bool mergeTextBlocks;
  final List<RecognizedTextBlock> blocks;
  final List<RecognizedTextContainer> containers;
  final String? errorMessage;
  final bool needsConfiguration;
  final int? imageWidth;
  final int? imageHeight;
  final bool fromCache;

  const ImageTranslationResult({
    required this.status,
    this.sourceText = '',
    this.translatedText = '',
    this.translatedGroups = const <String>[],
    this.mergeTextBlocks = true,
    this.blocks = const [],
    this.containers = const [],
    this.errorMessage,
    this.needsConfiguration = false,
    this.imageWidth,
    this.imageHeight,
    this.fromCache = false,
  });

  const ImageTranslationResult.idle()
    : this(status: ImageTranslationStatus.idle);

  bool get isTerminal =>
      status == ImageTranslationStatus.success ||
      status == ImageTranslationStatus.downloadError ||
      status == ImageTranslationStatus.ocrError ||
      status == ImageTranslationStatus.noText ||
      status == ImageTranslationStatus.canceled ||
      status == ImageTranslationStatus.failed;

  bool get isFailure =>
      status == ImageTranslationStatus.downloadError ||
      status == ImageTranslationStatus.ocrError ||
      status == ImageTranslationStatus.failed;

  ImageTranslationResult copyWith({
    ImageTranslationStatus? status,
    String? sourceText,
    String? translatedText,
    List<String>? translatedGroups,
    bool? mergeTextBlocks,
    List<RecognizedTextBlock>? blocks,
    List<RecognizedTextContainer>? containers,
    String? errorMessage,
    bool? needsConfiguration,
    int? imageWidth,
    int? imageHeight,
    bool? fromCache,
  }) {
    return ImageTranslationResult(
      status: status ?? this.status,
      sourceText: sourceText ?? this.sourceText,
      translatedText: translatedText ?? this.translatedText,
      translatedGroups: translatedGroups ?? this.translatedGroups,
      mergeTextBlocks: mergeTextBlocks ?? this.mergeTextBlocks,
      blocks: blocks ?? this.blocks,
      containers: containers ?? this.containers,
      errorMessage: errorMessage,
      needsConfiguration: needsConfiguration ?? this.needsConfiguration,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  Map<String, dynamic> toJson() => {
    'sourceText': sourceText,
    'translatedText': translatedText,
    if (translatedGroups.isNotEmpty) 'translatedGroups': translatedGroups,
    'mergeTextBlocks': mergeTextBlocks,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    if (containers.isNotEmpty)
      'containers': containers.map((container) => container.toJson()).toList(),
    if (imageWidth != null) 'imageWidth': imageWidth,
    if (imageHeight != null) 'imageHeight': imageHeight,
  };

  factory ImageTranslationResult.successFromJson(Map<String, dynamic> json) =>
      ImageTranslationResult(
        status: ImageTranslationStatus.success,
        sourceText: json['sourceText'] as String? ?? '',
        translatedText: json['translatedText'] as String? ?? '',
        translatedGroups: (json['translatedGroups'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        mergeTextBlocks: json['mergeTextBlocks'] as bool? ?? true,
        blocks:
            (json['blocks'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (block) => RecognizedTextBlock.fromJson(
                    Map<String, dynamic>.from(block),
                  ),
                )
                .toList(),
        containers: (json['containers'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (container) => RecognizedTextContainer.fromJson(
                Map<String, dynamic>.from(container),
              ),
            )
            .toList(growable: false),
        imageWidth: (json['imageWidth'] as num?)?.toInt(),
        imageHeight: (json['imageHeight'] as num?)?.toInt(),
      );
}

class ImageTranslationRequest {
  final String cacheKey;
  final String? imagePath;
  final String? sourceUrl;

  /// A request is a durable description of where the source image lives. It
  /// must not own a page-sized byte buffer because read-page state outlives an
  /// OCR/translation attempt and may keep hundreds of requests alive. Online
  /// pages may know only the logical cache key at first; [imagePath] is filled
  /// once the shared disk cache has the actual image file.
  const ImageTranslationRequest({
    required this.cacheKey,
    this.imagePath,
    this.sourceUrl,
  });

  ImageTranslationRequest copyWith({
    String? cacheKey,
    String? imagePath,
    String? sourceUrl,
  }) {
    return ImageTranslationRequest(
      cacheKey: cacheKey ?? this.cacheKey,
      imagePath: imagePath ?? this.imagePath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }
}
