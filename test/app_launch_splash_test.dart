import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/widget/app_launch_splash.dart';

void main() {
  testWidgets('splash shows the JHenTai wordmark centered on an adaptive '
      'background', (WidgetTester tester) async {
    await tester.pumpWidget(const AppLaunchSplash());

    // The wordmark is present and centered in the window.
    final Finder wordmark = find.text('JHenTai');
    expect(wordmark, findsOneWidget);
    expect(
      tester.getCenter(wordmark).dx,
      moreOrLessEquals(400, epsilon: 1),
    );
    expect(
      tester.getCenter(wordmark).dy,
      moreOrLessEquals(300, epsilon: 1),
    );

    // The host test surface reports light brightness, so the scaffold is
    // white and the wordmark black (inverted for the opposite theme).
    final BuildContext context = tester.element(wordmark);
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      Colors.white,
    );
    final Text text = tester.widget<Text>(wordmark);
    expect(text.style?.color, Colors.black);
  });
}
