import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/image_translation_service.dart';

void main() {
  late Directory temporaryDirectory;
  late File sourceImage;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'jh-image-translation-persistence',
    );
    sourceImage = File('${temporaryDirectory.path}/source.img');
    await sourceImage.writeAsBytes(<int>[1, 2, 3, 4, 5, 6]);
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'persistent translation hydrates from bytes read from a real file',
    () async {
      final ImageTranslationService service = ImageTranslationService();
      service.setTranslationCacheDirectoryForTesting(temporaryDirectory);
      final ImageTranslationRequest request = ImageTranslationRequest(
        cacheKey: 'page-1',
        imagePath: sourceImage.path,
      );
      const ImageTranslationResult persisted = ImageTranslationResult(
        status: ImageTranslationStatus.success,
        sourceText: 'source',
        translatedText: 'translated',
        translatedGroups: <String>['完整的一句译文。'],
        mergeTextBlocks: false,
        blocks: <RecognizedTextBlock>[
          RecognizedTextBlock(text: 'source', confidence: 0.99),
        ],
        imageWidth: 10,
        imageHeight: 20,
      );

      await service.writePersistentResultForRequest(request, persisted);
      service.removeResult(request.cacheKey);

      expect(await service.hydrateResult(request), isTrue);
      final ImageTranslationResult hydrated = service.resultFor(
        request.cacheKey,
      );
      expect(hydrated.status, ImageTranslationStatus.success);
      expect(hydrated.translatedText, 'translated');
      expect(hydrated.translatedGroups, equals(<String>['完整的一句译文。']));
      expect(hydrated.mergeTextBlocks, isFalse);
      expect(hydrated.fromCache, isTrue);
    },
  );

  test(
    'cached recognition does not throw while releasing source bytes',
    () async {
      final ImageTranslationService service = ImageTranslationService();
      service.setTranslationCacheDirectoryForTesting(temporaryDirectory);
      final ImageTranslationRequest request = ImageTranslationRequest(
        cacheKey: 'page-2',
        imagePath: sourceImage.path,
      );
      await service.writePersistentResultForRequest(
        request,
        const ImageTranslationResult(
          status: ImageTranslationStatus.success,
          sourceText: 'cached source',
          translatedText: 'cached translation',
        ),
      );

      expect(await service.recognizeImage(request), isNull);
      final ImageTranslationResult result = service.resultFor(request.cacheKey);
      expect(result.status, ImageTranslationStatus.success);
      expect(result.fromCache, isTrue);
    },
  );
}
