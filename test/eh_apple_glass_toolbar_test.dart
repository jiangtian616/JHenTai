import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/widget/eh_apple_glass_toolbar.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  setUpAll(LiquidGlassWidgets.initialize);

  tearDown(() {
    ThemeConfig.appleVisualStyleEnabled = false;
  });

  Future<void> pumpToolbar(WidgetTester tester, VoidCallback onPressed) {
    return tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: EHAppleGlassToolbar(
                items: <EHAppleToolbarItem>[
                  EHAppleToolbarItem(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: onPressed,
                    tooltip: 'Play',
                  ),
                  EHAppleToolbarItem(
                    icon: const Icon(Icons.pause),
                    onPressed: () {},
                    tooltip: 'Pause',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Apple actions share one GlassButtonGroup pill', (
    WidgetTester tester,
  ) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    var taps = 0;
    await pumpToolbar(tester, () => taps++);

    expect(find.byType(GlassButtonGroup), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    await tester.tap(find.byIcon(Icons.play_arrow));
    expect(taps, 1);
  });

  testWidgets('Material actions remain independent IconButtons', (
    WidgetTester tester,
  ) async {
    ThemeConfig.appleVisualStyleEnabled = false;
    await pumpToolbar(tester, () {});

    expect(find.byType(GlassButtonGroup), findsNothing);
    expect(find.byType(IconButton), findsNWidgets(2));
  });
}
