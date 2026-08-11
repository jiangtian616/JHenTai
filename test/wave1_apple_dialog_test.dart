import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/model/jh_layout.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_context_menu.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  setUpAll(() async {
    await LiquidGlassWidgets.initialize();
  });

  tearDown(() {
    ThemeConfig.appleVisualStyleEnabled = false;
    preferenceSetting.hideBottomBar.value = false;
    styleSetting.actualLayout = LayoutMode.mobileV2;
  });

  test('Apple visual style is opt-in without a platform gate', () {
    ThemeConfig.appleVisualStyleEnabled = true;
    expect(ThemeConfig.isApple, isTrue);

    ThemeConfig.appleVisualStyleEnabled = false;
    expect(ThemeConfig.isApple, isFalse);
  });

  test('Apple layout always exposes the bottom navigation bar', () {
    preferenceSetting.hideBottomBar.value = true;

    ThemeConfig.appleVisualStyleEnabled = false;
    expect(preferenceSetting.effectiveHideBottomBar, isTrue);

    ThemeConfig.appleVisualStyleEnabled = true;
    expect(preferenceSetting.effectiveHideBottomBar, isFalse);
  });

  testWidgets('Apple hide-bottom-bar switch is disabled and visually off', (
    tester,
  ) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    preferenceSetting.hideBottomBar.value = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EHAppleSwitchListTile(
            title: const Text('hide'),
            value: preferenceSetting.effectiveHideBottomBar,
            onChanged: preferenceSetting.saveHideBottomBar,
            enabled: !ThemeConfig.isApple,
          ),
        ),
      ),
    );

    expect(find.byType(GlassSwitch), findsOneWidget);
    final Finder switchOpacity = find.ancestor(
      of: find.byType(GlassSwitch),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(switchOpacity), isNotNull);
    expect(tester.widget<Opacity>(switchOpacity).opacity, 0.45);
    expect(preferenceSetting.effectiveHideBottomBar, isFalse);
  });

  testWidgets('EHDialog uses a monochrome non-primary glass action', (
    tester,
  ) async {
    ThemeConfig.appleVisualStyleEnabled = true;

    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: const MaterialApp(
          home: Scaffold(body: EHDialog(title: 'Delete?', content: 'Confirm')),
        ),
      ),
    );

    final GlassDialog dialog = tester.widget<GlassDialog>(
      find.byType(GlassDialog),
    );
    expect(dialog.actions, hasLength(2));
    expect(dialog.actions.last.isPrimary, isFalse);
  });

  testWidgets('Apple context menu uses the glass action sheet', (tester) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    styleSetting.actualLayout = LayoutMode.mobileV2;

    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => showEHContextMenu(
                          context,
                          actions: [const EHContextMenuAction(text: 'Delete')],
                        ),
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);
  });
}
