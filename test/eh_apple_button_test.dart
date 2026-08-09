import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: MaterialApp(
          home: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  setUpAll(() async {
    await LiquidGlassWidgets.initialize();
  });

  tearDown(() {
    ThemeConfig.appleVisualStyleEnabled = false;
  });

  testWidgets('EHAppleTextButton renders GlassButton when Apple style is on', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleTextButton(onPressed: () {}, child: const Text('OK')));
    expect(find.byType(GlassButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('EHAppleTextButton renders TextButton when Apple style is off', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = false;
    await pump(tester, EHAppleTextButton(onPressed: () {}, child: const Text('OK')));
    expect(find.byType(GlassButton), findsNothing);
    expect(find.byType(TextButton), findsOneWidget);
  });

  testWidgets('EHAppleFilledButton renders GlassButton when Apple style is on', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleFilledButton(onPressed: () {}, child: const Text('Go')));
    expect(find.byType(GlassButton), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('EHAppleFilledButton.tonal renders GlassButton when Apple style is on', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleFilledButton.tonal(onPressed: () {}, child: const Text('Tonal')));
    expect(find.byType(GlassButton), findsOneWidget);
  });

  testWidgets('EHAppleOutlinedButton renders GlassButton when Apple style is on', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleOutlinedButton(onPressed: () {}, child: const Icon(Icons.add)));
    expect(find.byType(GlassButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('EHAppleTextButton.icon renders GlassButton with icon row when Apple style is on', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(
      tester,
      EHAppleTextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.send),
        label: const Text('Send'),
      ),
    );
    expect(find.byType(GlassButton), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('ButtonStyle minimumSize is translated to GlassButton width/height', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(
      tester,
      EHAppleFilledButton(
        onPressed: () {},
        style: FilledButton.styleFrom(minimumSize: const Size(56, 56)),
        child: const Text('X'),
      ),
    );
    final GlassButton button = tester.widget<GlassButton>(find.byType(GlassButton));
    expect(button.width, 56);
    expect(button.height, 56);
  });

  testWidgets('Disabled EHAppleFilledButton is disabled in GlassButton', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleFilledButton(child: const Text('X')));
    final GlassButton button = tester.widget<GlassButton>(find.byType(GlassButton));
    expect(button.enabled, isFalse);
  });
}
