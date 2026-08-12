import 'dart:convert';

import 'engine_contract.dart';

/// The only context sizes exposed by the reader. Keeping this an enum prevents
/// an arbitrary page count from silently changing the prompt/cache contract.
enum ContextBatchSize {
  one(1),
  two(2),
  four(4),
  eight(8);

  const ContextBatchSize(this.pageCount);

  final int pageCount;
}

class ContextTranslationLineRequest {
  const ContextTranslationLineRequest({
    required this.pageId,
    required this.lineId,
    required this.sourceText,
  });

  final String pageId;
  final String lineId;
  final String sourceText;

  Map<String, String> toJson() => <String, String>{
    'pageId': pageId,
    'lineId': lineId,
    'text': sourceText,
  };
}

class ContextTranslationPageRequest {
  const ContextTranslationPageRequest({
    required this.pageId,
    required this.pageHash,
    required this.lines,
  });

  final String pageId;
  final String pageHash;
  final List<ContextTranslationLineRequest> lines;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageId': pageId,
    'pageHash': pageHash,
    'lines': lines.map((line) => line.toJson()).toList(growable: false),
  };
}

/// Structured input for one context call. Implementations must send [pages]
/// in one model request and return stable IDs, not positional lines.
class ContextTranslationEngineRequest {
  const ContextTranslationEngineRequest({
    required this.pages,
    required this.batchSize,
    required this.targetPageIds,
    required this.modelVersion,
    required this.promptVersion,
    required this.targetLanguage,
    required this.ocrConfiguration,
    this.sourceLanguage,
    this.configuration = const <String, dynamic>{},
  });

  final List<ContextTranslationPageRequest> pages;
  final ContextBatchSize batchSize;
  final List<String> targetPageIds;
  final String modelVersion;
  final int promptVersion;
  final String targetLanguage;
  final String? sourceLanguage;
  final Map<String, dynamic> ocrConfiguration;
  final Map<String, dynamic> configuration;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'batchSize': batchSize.pageCount,
    'targetPageIds': targetPageIds,
    'modelVersion': modelVersion,
    'promptVersion': promptVersion,
    'targetLanguage': targetLanguage,
    'sourceLanguage': sourceLanguage,
    'ocrConfiguration': ocrConfiguration,
    'configuration': configuration,
    'pages': pages.map((page) => page.toJson()).toList(growable: false),
  };
}

class ContextTranslationLineResult {
  const ContextTranslationLineResult({
    required this.pageId,
    required this.lineId,
    required this.translatedText,
    this.errorCode,
  });

  final String pageId;
  final String lineId;
  final String translatedText;
  final String? errorCode;

  factory ContextTranslationLineResult.fromJson(Map<String, dynamic> json) =>
      ContextTranslationLineResult(
        pageId: json['pageId'] as String? ?? '',
        lineId: json['lineId'] as String? ?? '',
        translatedText:
            (json['text'] ?? json['translatedText']) as String? ?? '',
        errorCode: json['error'] as String? ?? json['errorCode'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageId': pageId,
    'lineId': lineId,
    'text': translatedText,
    if (errorCode != null) 'error': errorCode,
  };
}

class ContextTranslationResult {
  const ContextTranslationResult({required this.lines});

  final List<ContextTranslationLineResult> lines;

  factory ContextTranslationResult.fromJson(dynamic value) {
    final dynamic rawLines = value is Map ? value['translations'] : null;
    if (rawLines is! List) {
      throw const FormatException(
        'Context translation response must contain translations[].',
      );
    }
    return ContextTranslationResult(
      lines: rawLines
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> raw) =>
                ContextTranslationLineResult.fromJson(
                  Map<String, dynamic>.from(raw),
                ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'translations': lines.map((line) => line.toJson()).toList(growable: false),
  };

  String get json => jsonEncode(toJson());
}

/// Optional capability. Existing single-page engines do not implement this
/// interface until their structured-ID request/response contract is verified.
/// That deliberate absence is surfaced as a user-visible blocker by the
/// context service instead of being emulated with concatenated strings.
abstract class ContextTranslationEngine {
  EngineDescriptor get descriptor;
  bool get isReady;
  EngineTask<ContextTranslationResult> translateContext(
    ContextTranslationEngineRequest request,
  );
}

/// Optional asynchronous readiness for context-capable native adapters.
extension ContextTranslationEngineReadiness on ContextTranslationEngine {
  Future<bool> ensureReady() async {
    final ContextTranslationEngine engine = this;
    return engine is EngineReadiness ? engine.ensureReady() : engine.isReady;
  }
}
