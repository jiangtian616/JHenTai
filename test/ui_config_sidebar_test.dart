import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/ui_config.dart';

void main() {
  test('dark macOS sidebar suppresses the pale native material', () {
    expect(
      UIConfig.desktopMacOSSideBarAlpha(Brightness.dark),
      greaterThan(UIConfig.desktopMacOSSideBarAlpha(Brightness.light)),
    );
    expect(
      UIConfig.desktopMacOSVisualEffectAlpha(Brightness.dark),
      lessThan(UIConfig.desktopMacOSVisualEffectAlpha(Brightness.light)),
    );

    final Color darkComposite = Color.alphaBlend(
      UIConfig.desktopSideBarColorDark.withValues(
        alpha: UIConfig.desktopMacOSSideBarAlpha(Brightness.dark),
      ),
      Colors.white,
    );
    expect(darkComposite.computeLuminance(), lessThan(0.08));
  });
}
