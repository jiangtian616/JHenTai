import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/ui_config.dart';

void main() {
  test('macOS sidebar keeps the native material visibly transparent', () {
    expect(
      UIConfig.desktopMacOSSideBarAlpha(Brightness.dark),
      lessThan(UIConfig.desktopMacOSSideBarAlpha(Brightness.light)),
    );
    expect(UIConfig.desktopMacOSSideBarAlpha(Brightness.light), 0.18);
    expect(UIConfig.desktopMacOSSideBarAlpha(Brightness.dark), 0.08);
    expect(UIConfig.desktopMacOSVisualEffectAlpha(Brightness.light), 0.70);
    expect(UIConfig.desktopMacOSVisualEffectAlpha(Brightness.dark), 0.65);

    final Color lightComposite = Color.alphaBlend(
      UIConfig.desktopSideBarColorLight.withValues(
        alpha: UIConfig.desktopMacOSSideBarAlpha(Brightness.light),
      ),
      Colors.black,
    );
    expect(lightComposite.computeLuminance(), lessThan(0.04));

    final Color darkComposite = Color.alphaBlend(
      UIConfig.desktopSideBarColorDark.withValues(
        alpha: UIConfig.desktopMacOSSideBarAlpha(Brightness.dark),
      ),
      Colors.white,
    );
    expect(darkComposite.computeLuminance(), greaterThan(0.7));
  });
}
