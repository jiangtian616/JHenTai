enum ImageTranslationStatus { idle, recognizing, translating, success, failed }

enum ImageTranslationStage {
  idle,
  recognizing,
  translating,
  masking,
  embedding,
  done
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
          height: (json['height'] as num?)?.toDouble() ?? 0);
}

class ImageTranslationResult {
  final ImageTranslationStatus status;
  final String sourceText;
  final String translatedText;
  final List<RecognizedTextBlock> blocks;
  final String? errorMessage;
  final bool needsConfiguration;
  final int? imageWidth;
  final int? imageHeight;
  final bool fromCache;

  const ImageTranslationResult({
    required this.status,
    this.sourceText = '',
    this.translatedText = '',
    this.blocks = const [],
    this.errorMessage,
    this.needsConfiguration = false,
    this.imageWidth,
    this.imageHeight,
    this.fromCache = false,
  });

  const ImageTranslationResult.idle()
      : this(status: ImageTranslationStatus.idle);

  ImageTranslationResult copyWith({
    ImageTranslationStatus? status,
    String? sourceText,
    String? translatedText,
    List<RecognizedTextBlock>? blocks,
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
      blocks: blocks ?? this.blocks,
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
        'blocks': blocks.map((block) => block.toJson()).toList(),
        if (imageWidth != null) 'imageWidth': imageWidth,
        if (imageHeight != null) 'imageHeight': imageHeight,
      };

  factory ImageTranslationResult.successFromJson(Map<String, dynamic> json) =>
      ImageTranslationResult(
          status: ImageTranslationStatus.success,
          sourceText: json['sourceText'] as String? ?? '',
          translatedText: json['translatedText'] as String? ?? '',
          blocks: (json['blocks'] as List? ?? const [])
              .whereType<Map>()
              .map((block) => RecognizedTextBlock.fromJson(
                  Map<String, dynamic>.from(block)))
              .toList(),
          imageWidth: (json['imageWidth'] as num?)?.toInt(),
          imageHeight: (json['imageHeight'] as num?)?.toInt());
}

class ImageTranslationRequest {
  final String cacheKey;
  final String? imagePath;
  final List<int>? imageBytes;

  const ImageTranslationRequest(
      {required this.cacheKey, this.imagePath, this.imageBytes})
      : assert(imagePath != null || imageBytes != null);
}
