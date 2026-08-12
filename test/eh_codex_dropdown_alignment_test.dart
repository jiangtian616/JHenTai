import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/widget/eh_codex_style_dropdown.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Regression: in Apple style the expanded glass menu must open toward the
/// bottom-left. The package auto-detects the side from the trigger's screen
/// position, which can pick the wrong side for the model dropdown inside a
/// right-side drawer; [EHCodexStyleDropdown] therefore forces
/// [GlassMenuAlignment.topRight] (top-right corner anchors to the trigger, so
/// the body extends downward and to the left).
void main() {
  setUpAll(() async {
    await LiquidGlassWidgets.initialize();
  });

  tearDown(() {
    ThemeConfig.appleVisualStyleEnabled = false;
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Offset triggerPosition, {
    GlassMenuAlignment? forced,
  }) async {
    ThemeConfig.appleVisualStyleEnabled = true;
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: triggerPosition.dx,
                  top: triggerPosition.dy,
                  child: EHCodexStyleDropdown<String>(
                    value: 'b',
                    menuAlignment: forced,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'a',
                        child: Text('option-a'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'b',
                        child: Text('option-b'),
                      ),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<double> menuLeftEdge(WidgetTester tester) async {
    await tester.tap(
      find.byType(EHCodexStyleDropdown<String>),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    return tester.getRect(find.byType(GlassMenuItem).first).left;
  }

  testWidgets('default Apple dropdown opens toward the bottom-left', (
    tester,
  ) async {
    // A left-half trigger is the hardest case: without the forced alignment
    // the package auto-detection would open toward the bottom-right.
    await pumpAt(tester, const Offset(100, 200));
    final double left = await menuLeftEdge(tester);
    expect(left, lessThan(100));
  });

  testWidgets('an explicit menuAlignment overrides the default', (tester) async {
    await pumpAt(
      tester,
      const Offset(100, 200),
      forced: GlassMenuAlignment.topLeft,
    );
    final double left = await menuLeftEdge(tester);
    expect(left, greaterThan(100));
  });
}
