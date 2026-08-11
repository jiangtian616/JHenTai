import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/l18n/locale_text.dart';
import 'package:jhentai/src/pages/setting/network/lan/lan_gallery_list_page.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations(LocaleText().keys);
    Get.locale = const Locale('zh', 'CN');
  });

  test('cover failure is retryable without blocking the gallery list', () {
    final LanGalleryCoverController controller = LanGalleryCoverController();

    controller.markFailed();
    expect(controller.failed, isTrue);
    expect(controller.attempt, 0);

    controller.retry();
    expect(controller.failed, isFalse);
    expect(controller.attempt, 1);
  });

  test('LAN page count uses the GetX @count replacement syntax', () {
    expect('lanGalleryPageCount'.trParams({'count': '12'}), '12 页');
  });

  testWidgets(
    'missing cover renders a placeholder while the list remains usable',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [LanGalleryCover(coverUrl: null), Text('gallery item')],
          ),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.text('gallery item'), findsOneWidget);
    },
  );
}
