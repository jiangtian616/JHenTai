import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/ui_config.dart';

void main() {
  test('dark macOS sidebar suppresses the pale native material', () {
    expect(
      UIConfig.desktopMacOSSideBarAlpha(Brightness.dark),
      greaterThan(UIConfig.desktopMacOSSideBarAlpha(Brightness.light)),
    );
    expect(UIConfig.desktopMacOSSideBarAlpha(Brightness.light), 0.55);
    expect(UIConfig.desktopMacOSVisualEffectAlpha(Brightness.light), 1.0);
    expect(UIConfig.desktopMacOSVisualEffectAlpha(Brightness.dark), 0.32);

    final Color lightComposite = Color.alphaBlend(
      UIConfig.desktopSideBarColorLight.withValues(
        alpha: UIConfig.desktopMacOSSideBarAlpha(Brightness.light),
      ),
      Colors.black,
    );
    expect(lightComposite.computeLuminance(), greaterThan(0.2));

    final Color darkComposite = Color.alphaBlend(
      UIConfig.desktopSideBarColorDark.withValues(
        alpha: UIConfig.desktopMacOSSideBarAlpha(Brightness.dark),
      ),
      Colors.white,
    );
    expect(darkComposite.computeLuminance(), lessThan(0.08));
  });
}
