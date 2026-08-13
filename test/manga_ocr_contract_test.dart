import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/inference/manga_ocr_eval_protocol.dart';
import 'package:jhentai/src/service/inference/manga_ocr_language_advisor.dart';
import 'package:jhentai/src/service/inference/manga_ocr_model_evidence.dart';
import 'package:jhentai/src/utils/oriented_rect.dart';
import 'package:jhentai/src/utils/ocr_layout_protocol.dart';

void main() {
  test('vertical layout is grouped right-to-left then top-to-bottom', () {
    final List<OcrLayoutBox> boxes = <OcrLayoutBox>[
      const OcrLayoutBox(
        sourceIndex: 3,
        left: 100,
        top: 80,
        width: 20,
        height: 100,
      ),
      const OcrLayoutBox(
        sourceIndex: 0,
        left: 220,
        top: 80,
        width: 20,
        height: 100,
      ),
      const OcrLayoutBox(
        sourceIndex: 2,
        left: 100,
        top: 10,
        width: 20,
        height: 50,
      ),
      const OcrLayoutBox(
        sourceIndex: 1,
        left: 220,
        top: 10,
        width: 20,
        height: 50,
      ),
    ];

    expect(
      sortOcrReadingOrder(boxes).map((OcrLayoutBox box) => box.sourceIndex),
      <int>[1, 0, 2, 3],
    );
  });

  test('evaluation reports recognition and reading-order errors', () {
    const List<OcrPoint> left = <OcrPoint>[(0, 0), (20, 0), (20, 60), (0, 60)];
    const List<OcrPoint> right = <OcrPoint>[
      (40, 0),
      (60, 0),
      (60, 60),
      (40, 60),
    ];
    final MangaOcrEvalReport report = evaluateMangaOcrCase(
      groundTruth: const <MangaOcrEvalRegion>[
        MangaOcrEvalRegion(id: 'right', text: '右', polygon: right),
        MangaOcrEvalRegion(id: 'left', text: '左', polygon: left),
      ],
      predictions: const <MangaOcrEvalPrediction>[
        MangaOcrEvalPrediction(text: '左', polygon: left),
        MangaOcrEvalPrediction(text: '右', polygon: right),
      ],
    );

    expect(report.detectionF1, 1);
    expect(report.recognitionAccuracy, 1);
    expect(report.orderAccuracy, 0);
  });

  test('Japanese tategaki advisor is conservative', () {
    final List<RecognizedTextBlock> blocks = <RecognizedTextBlock>[
      const RecognizedTextBlock(
        text: 'こんにちは',
        confidence: 1,
        left: 100,
        top: 0,
        width: 20,
        height: 100,
      ),
    ];
    expect(MangaOcrLanguageAdvisor.shouldSuggest(blocks), isTrue);
  });

  test('model evidence refuses incomplete integrity metadata', () {
    expect(MangaOcrModelEvidence.allRequiredHashesConfirmed, isFalse);
    expect(
      MangaOcrModelEvidence.missingHashes,
      containsAll(<String>['mocr2025_vocab.csv', 'config.json']),
    );
    expect(MangaOcrModelEvidence.repositoryUrl, startsWith('https://'));
    expect(MangaOcrModelEvidence.artifacts, isNotEmpty);
  });
}
