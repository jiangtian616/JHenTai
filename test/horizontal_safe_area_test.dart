import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/widget/horizontal_safe_area.dart';

/// iPhone Duo's inner screen in landscape, measured on the simulator
const double devicePixelRatio = 3;
const Size windowSize = Size(951, 669);
const EdgeInsets rightVerticalBar = EdgeInsets.only(right: 84, bottom: 34);
const EdgeInsets leftVerticalBar = EdgeInsets.only(left: 84, bottom: 34);

void setWindowInsets(WidgetTester tester, EdgeInsets insets) {
  FakeViewPadding padding = FakeViewPadding(
    left: insets.left * devicePixelRatio,
    top: insets.top * devicePixelRatio,
    right: insets.right * devicePixelRatio,
    bottom: insets.bottom * devicePixelRatio,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
}

/// Same structure as details page: the body drops the side insets, the app bar and the floating button keep them.
/// [removeLeft] simulates the right column of tablet layout, which removes the inset of the edge it doesn't touch.
Future<void> pumpPage(WidgetTester tester, EdgeInsets insets, {bool extendIntoVerticalBar = true, bool removeLeft = false}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = windowSize * devicePixelRatio;
  setWindowInsets(tester, insets);

  Widget page = HorizontalSafeArea(
    extendIntoVerticalBar: extendIntoVerticalBar,
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(key: const Key('leading'), onPressed: () {}, icon: const Icon(Icons.arrow_back)),
        title: const Text('title'),
        actions: [IconButton(key: const Key('action'), onPressed: () {}, icon: const Icon(Icons.more_vert))],
      ),
      body: Builder(
        builder: (context) => MediaQuery.removePadding(
          context: context,
          removeLeft: true,
          removeRight: true,
          child: const SizedBox.expand(key: Key('body')),
        ),
      ),
      floatingActionButton: FloatingActionButton(key: const Key('fab'), onPressed: () {}),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: removeLeft ? Builder(builder: (context) => MediaQuery.removePadding(context: context, removeLeft: true, child: page)) : page,
    ),
  );
}

Rect rectOf(WidgetTester tester, String key) => tester.getRect(find.byKey(Key(key)));

void main() {
  testWidgets('vertical bar on the right: body extends under it, app bar and floating button avoid it', (tester) async {
    addTearDown(tester.view.reset);
    await pumpPage(tester, rightVerticalBar);

    expect(rectOf(tester, 'body').left, 0);
    expect(rectOf(tester, 'body').right, windowSize.width);
    expect(rectOf(tester, 'action').right, lessThanOrEqualTo(windowSize.width - 84));
    expect(rectOf(tester, 'fab').right, lessThanOrEqualTo(windowSize.width - 84));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('vertical bar moves to the left after rotating', (tester) async {
    addTearDown(tester.view.reset);
    await pumpPage(tester, rightVerticalBar);

    setWindowInsets(tester, leftVerticalBar);
    await tester.pump();

    expect(rectOf(tester, 'body').left, 0);
    expect(rectOf(tester, 'body').right, windowSize.width);
    expect(rectOf(tester, 'leading').left, greaterThanOrEqualTo(84));
    expect(rectOf(tester, 'action').right, greaterThan(windowSize.width - 84));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('pages without extendIntoVerticalBar still avoid the vertical bar', (tester) async {
    addTearDown(tester.view.reset);
    await pumpPage(tester, rightVerticalBar, extendIntoVerticalBar: false);

    expect(rectOf(tester, 'body').right, windowSize.width - 84);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('regular iPhone in landscape still avoids both side insets', (tester) async {
    addTearDown(tester.view.reset);
    await pumpPage(tester, const EdgeInsets.only(left: 59, right: 59, bottom: 21));

    expect(rectOf(tester, 'body').left, 59);
    expect(rectOf(tester, 'body').right, windowSize.width - 59);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('right column of tablet layout on a regular iPhone is not taken for a vertical bar', (tester) async {
    addTearDown(tester.view.reset);
    await pumpPage(tester, const EdgeInsets.only(left: 59, right: 59, bottom: 21), removeLeft: true);

    expect(rectOf(tester, 'body').left, 0);
    expect(rectOf(tester, 'body').right, windowSize.width - 59);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('side insets on Android are still avoided', (tester) async {
    addTearDown(tester.view.reset);
    await pumpPage(tester, const EdgeInsets.only(right: 48));

    expect(rectOf(tester, 'body').right, windowSize.width - 48);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
