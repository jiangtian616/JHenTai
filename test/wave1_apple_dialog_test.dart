import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/model/jh_layout.dart';
import 'package:jhentai/src/pages/setting/network/lan/setting_lan_sharing_page.dart';
import 'package:jhentai/src/service/log.dart';
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

  test(
    'enabling Apple style persistently clears the legacy hidden bar value',
    () async {
      final PreferenceSetting originalPreferenceSetting = preferenceSetting;
      final StyleSetting originalStyleSetting = styleSetting;
      final LogService originalLog = log;
      final _TestPreferenceSetting testPreferenceSetting =
          _TestPreferenceSetting()..hideBottomBar.value = true;
      final _TestStyleSetting testStyleSetting = _TestStyleSetting();
      preferenceSetting = testPreferenceSetting;
      styleSetting = testStyleSetting;
      log = _TestLogService();
      try {
        await testStyleSetting.saveAppleVisualStyle(true);

        expect(testPreferenceSetting.hideBottomBar.value, isFalse);
        expect(testPreferenceSetting.saveHideBottomBarCalls, 1);
        expect(testStyleSetting.appleVisualStyle.value, isTrue);

        await testStyleSetting.saveAppleVisualStyle(false);
        expect(testPreferenceSetting.hideBottomBar.value, isFalse);
        expect(testPreferenceSetting.saveHideBottomBarCalls, 1);
      } finally {
        preferenceSetting = originalPreferenceSetting;
        styleSetting = originalStyleSetting;
        log = originalLog;
      }
    },
  );

  test('loaded Apple config migrates the legacy hidden bar value', () async {
    final PreferenceSetting originalPreferenceSetting = preferenceSetting;
    final StyleSetting originalStyleSetting = styleSetting;
    final LogService originalLog = log;
    final _TestPreferenceSetting testPreferenceSetting =
        _TestPreferenceSetting()..hideBottomBar.value = true;
    final _TestStyleSetting testStyleSetting =
        _TestStyleSetting()..appleVisualStyle.value = true;
    preferenceSetting = testPreferenceSetting;
    styleSetting = testStyleSetting;
    log = _TestLogService();
    try {
      testStyleSetting.doAfterBeanReady();
      await Future<void>.delayed(Duration.zero);

      expect(testPreferenceSetting.hideBottomBar.value, isFalse);
      expect(testPreferenceSetting.saveHideBottomBarCalls, 1);
    } finally {
      preferenceSetting = originalPreferenceSetting;
      styleSetting = originalStyleSetting;
      log = originalLog;
    }
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

  testWidgets('Apple LAN revoke dialog returns from both actions', (
    tester,
  ) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    bool? result;

    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: MaterialApp(
          theme: ThemeConfig.theme(Colors.black, Brightness.light),
          darkTheme: ThemeConfig.theme(Colors.white, Brightness.dark),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showLanRevokeTrustConfirmationDialog(
                        context,
                        deviceName: 'Mac',
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(GlassDialog), findsNothing);
    expect(find.byType(GlassButton), findsNothing);
    expect(find.byType(GlassCard), findsOneWidget);

    final Finder titleFinder = find.byKey(
      const Key('lanRevokeDialogTitle'),
    );
    final Finder messageFinder = find.byKey(
      const Key('lanRevokeDialogMessage'),
    );
    expect(
      tester.widget<Text>(titleFinder).style?.color,
      const Color(0xFFF5F5F7),
    );
    expect(
      tester.widget<Text>(messageFinder).style?.color,
      const Color(0xFFB0B0B5),
    );
    expect(
      find.ancestor(
        of: titleFinder,
        matching: find.byType(AdaptiveLiquidGlassLayer),
      ),
      findsNothing,
    );

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(GlassDialog), findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.byType(GlassDialog), findsNothing);
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

class _TestPreferenceSetting extends PreferenceSetting {
  int saveHideBottomBarCalls = 0;

  @override
  Future<void> saveHideBottomBar(bool hideBottomBar) async {
    saveHideBottomBarCalls++;
    this.hideBottomBar.value = hideBottomBar;
  }
}

class _TestStyleSetting extends StyleSetting {
  @override
  Future<int> saveBeanConfig() async => 1;
}

class _TestLogService extends LogService {
  @override
  Future<void> debug(Object msg, [bool withStack = false]) async {}
}
