import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/widget/reader_thumbnail_layout.dart';

void main() {
  test(
    'keeps a common height and preserves portrait, landscape and wide ratios',
    () {
      expect(
        ReaderThumbnailLayout.sizeFor(
          height: 120,
          imageWidth: 600,
          imageHeight: 1200,
        ),
        const Size(60, 120),
      );
      expect(
        ReaderThumbnailLayout.sizeFor(
          height: 120,
          imageWidth: 1600,
          imageHeight: 900,
        ),
        const Size(213.33333333333334, 120),
      );
      expect(
        ReaderThumbnailLayout.sizeFor(
          height: 120,
          imageWidth: 2400,
          imageHeight: 600,
        ),
        const Size(480, 120),
      );
    },
  );

  testWidgets('ReaderThumbnailFrame exposes the calculated slot size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReaderThumbnailFrame(
            height: 120,
            imageWidth: 1600,
            imageHeight: 900,
            image: ColoredBox(color: Colors.red),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ReaderThumbnailFrame)),
      const Size(213.33333333333334, 120),
    );
  });
}
