import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: MaterialApp(
          home: Scaffold(body: child),
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

  testWidgets('EHAppleSwitch renders GlassSwitch when Apple style is on', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleSwitch(value: false, onChanged: (_) {}));
    expect(find.byType(GlassSwitch), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('GlassSwitch uses iOS colors: white thumb, green-on / gray-off track', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleSwitch(value: false, onChanged: (_) {}));
    final GlassSwitch switchOn = tester.widget<GlassSwitch>(find.byType(GlassSwitch));
    expect(switchOn.thumbColor, CupertinoColors.white);
    expect(switchOn.activeColor, CupertinoColors.systemGreen);
    expect(switchOn.inactiveColor, CupertinoColors.systemGrey);
  });

  testWidgets('EHAppleSwitch renders Material Switch when Apple style is off', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = false;
    await pump(tester, EHAppleSwitch(value: false, onChanged: (_) {}));
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(GlassSwitch), findsNothing);
  });

  testWidgets('EHAppleSwitchListTile renders GlassSwitch trailing when Apple style is on', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(
      tester,
      EHAppleSwitchListTile(
        title: const Text('On'),
        value: true,
        onChanged: (_) {},
      ),
    );
    expect(find.byType(GlassSwitch), findsOneWidget);
    expect(find.byType(CupertinoListTile), findsOneWidget);
  });

  testWidgets('EHAppleSwitchListTile renders Material SwitchListTile when Apple style is off', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = false;
    await pump(
      tester,
      EHAppleSwitchListTile(
        title: const Text('Off'),
        value: true,
        onChanged: (_) {},
      ),
    );
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.byType(CupertinoListTile), findsNothing);
  });

  testWidgets('EHAppleSlider renders GlassSlider when Apple style is on, Material Slider when off', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleSlider(value: 0.5, onChanged: (_) {}));
    expect(find.byType(GlassSlider), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    ThemeConfig.appleVisualStyleEnabled = false;
    await pump(tester, EHAppleSlider(value: 0.5, onChanged: (_) {}));
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(GlassSlider), findsNothing);
  });

  testWidgets('EHAppleTextField renders GlassTextField when Apple style is on, Material TextField when off', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await pump(tester, EHAppleTextField(controller: TextEditingController()));
    expect(find.byType(GlassTextField), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    ThemeConfig.appleVisualStyleEnabled = false;
    await pump(tester, EHAppleTextField(controller: TextEditingController()));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(GlassTextField), findsNothing);
  });
}
