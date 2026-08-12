import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/theme_config.dart';

void main() {
  tearDown(() {
    ThemeConfig.appleVisualStyleEnabled = false;
  });

  test('Apple theme maps Cupertino text roles to the active brightness', () {
    ThemeConfig.appleVisualStyleEnabled = true;

    final ThemeData darkTheme = ThemeConfig.theme(Colors.blue, Brightness.dark);
    final ThemeData lightTheme = ThemeConfig.theme(
      Colors.blue,
      Brightness.light,
    );
    final NoDefaultCupertinoThemeData darkCupertino =
        darkTheme.cupertinoOverrideTheme!;
    final NoDefaultCupertinoThemeData lightCupertino =
        lightTheme.cupertinoOverrideTheme!;

    expect(
      darkCupertino.textTheme!.textStyle.color,
      darkTheme.colorScheme.onSurface,
    );
    expect(
      lightCupertino.textTheme!.textStyle.color,
      lightTheme.colorScheme.onSurface,
    );
    expect(
      darkCupertino.textTheme!.tabLabelTextStyle.color,
      isNot(Colors.black),
    );
    expect(
      lightCupertino.textTheme!.tabLabelTextStyle.color,
      isNot(Colors.white),
    );
  });

  testWidgets('Apple wrapper overrides an outer light Cupertino theme', (
    tester,
  ) async {
    ThemeConfig.appleVisualStyleEnabled = true;

    await tester.pumpWidget(
      CupertinoTheme(
        data: const CupertinoThemeData(brightness: Brightness.light),
        child: MaterialApp(
          theme: ThemeConfig.theme(Colors.blue, Brightness.dark),
          builder: (context, child) =>
              ThemeConfig.wrapWithAppleCupertinoTheme(context, child!),
          home: const CupertinoListTile(title: Text('dark Apple label')),
        ),
      ),
    );

    final BuildContext labelContext = tester.element(
      find.text('dark Apple label'),
    );
    expect(
      DefaultTextStyle.of(labelContext).style.color,
      const Color(0xFFF5F5F7),
    );
  });
}
