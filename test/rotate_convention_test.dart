import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  // Pins down image.copyRotate's direction convention: positive angle rotates
  // CLOCKWISE or COUNTERCLOCKWISE in image coordinates (y down)?
  test('copyRotate 90 rotates clockwise in image coords', () {
    // 11x3, a black dash on the middle row spanning x=4..6, white bg.
    final image.Image img = image.Image(width: 11, height: 3, numChannels: 3);
    for (int x = 0; x < img.width; x++) {
      for (int y = 0; y < img.height; y++) {
        img.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    for (int x = 4; x <= 6; x++) {
      img.setPixelRgb(x, 1, 0, 0, 0);
    }
    final image.Image rot = image.copyRotate(img, angle: 90);
    final List<String> rows = <String>[];
    for (int y = 0; y < rot.height; y++) {
      final StringBuffer row = StringBuffer();
      for (int x = 0; x < rot.width; x++) {
        final image.Pixel p = rot.getPixel(x, y);
        row.write(p.r < 128 && p.g < 128 && p.b < 128 ? '#' : '.');
      }
      rows.add(row.toString());
    }
    // ignore: avoid_print
    print('90deg result (${{'w': rot.width, 'h': rot.height}}):');
    for (final String r in rows) {
      // ignore: avoid_print
      print('  $r');
    }
  });
}
