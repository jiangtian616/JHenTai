import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/widget/read_page_image_translation_overlay.dart';

void main() {
  test('reader overlay follows the contained image, not the full page slot', () {
    // A portrait manga page placed into a square reader slot leaves horizontal
    // gutters. OCR coordinates must be transformed into the centered portrait
    // image, never stretched across the whole square slot.
    final Rect visible = translationOverlayVisibleImageRect(
      sourceSize: const Size(1000, 2000),
      canvasSize: const Size(1000, 1000),
    );

    expect(visible, const Rect.fromLTWH(250, 0, 500, 1000));
  });

  test(
    'reader overlay keeps an exact match when page and slot share aspect',
    () {
      final Rect visible = translationOverlayVisibleImageRect(
        sourceSize: const Size(1056, 1396),
        canvasSize: const Size(528, 698),
      );

      expect(visible, const Rect.fromLTWH(0, 0, 528, 698));
    },
  );
}
