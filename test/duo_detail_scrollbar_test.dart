// Inspect painter geometry directly, independent of transient opacity/hit testing.
// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/jh_layout.dart';
import 'package:jhentai/src/pages/details/details_page.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/native_window_geometry.dart';
import 'package:jhentai/src/widget/native_window_chrome.dart';
import 'package:jhentai/src/widget/viewport_scrollbar.dart';

class _ProbeLogic extends DetailsPageLogic {
  _ProbeLogic() : super.preview();
  @override
  // Isolate network initialization while retaining the production scroll container.
  // ignore: must_call_super
  void onInit() {}
  @override
  void onReady() {}
  @override
  void onClose() {
    state.scrollController.dispose();
  }
}

// Production page/scaffold/scroll behavior; only network content is replaced.
class _DetailProbe extends DetailsPage {
  final observedMedia = <String, MediaQueryData>{};
  _DetailProbe() : super.preview() {
    logic = _ProbeLogic();
    state = logic.state;
  }
  @override
  AppBar buildAppBar(BuildContext context) => AppBar(title: const Text('gallery'));
  @override
  Widget buildDetail(BuildContext context) => SliverToBoxAdapter(
    child: Builder(
      builder: (context) {
        observedMedia['content'] = MediaQuery.of(context);
        return const SizedBox(height: 3000, key: ValueKey('full-width-content'));
      },
    ),
  );
  @override
  Widget buildActions(BuildContext context) => const SliverToBoxAdapter();
  @override
  Widget buildFloatingActionButton() => const SizedBox();
}

NativeWindowGeometry geometry({bool wide = false, bool duo = true}) => NativeWindowGeometry(
  size: wide ? const Size(960, 700) : const Size(430, 800),
  statusBar: wide ? const Rect.fromLTWH(0, 0, 960, 80) : const Rect.fromLTWH(362, 14, 68, 180),
  safeArea: wide ? const EdgeInsets.only(top: 80, bottom: 34) : const EdgeInsets.only(right: 68, bottom: 34),
  horizontalBars: wide,
  isDuoDevice: duo,
);
Widget frame(NativeWindowGeometryController c, Widget child, {double right = 68, TargetPlatform platform = TargetPlatform.iOS}) => GetMaterialApp(
  theme: ThemeData(platform: platform),
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: EdgeInsets.only(right: right, bottom: 34),
      viewPadding: EdgeInsets.only(right: right, bottom: 34),
    ),
    child: NativeWindowChrome(controller: c, child: page!),
  ),
  home: child,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LayoutMode previousLayout;
  late bool previousTitles;
  setUp(() {
    Get.testMode = true;
    previousLayout = styleSetting.actualLayout;
    previousTitles = preferenceSetting.showAllGalleryTitles.value;
    preferenceSetting.showAllGalleryTitles.value = false;
  });
  tearDown(() {
    Get.reset();
    styleSetting.actualLayout = previousLayout;
    preferenceSetting.showAllGalleryTitles.value = previousTitles;
  });
  Future<void> finish(WidgetTester t, NativeWindowGeometryController c) async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    c.dispose();
  }

  for (final sample in [
    (
      name: 'Duo outer with inherited right inset',
      wide: false,
      duo: true,
      native: true,
      right: 68.0,
      platform: TargetPlatform.iOS,
      expected: 0.0,
      viewport: true,
    ),
    (
      name: 'Duo outer native-only inset',
      wide: false,
      duo: true,
      native: true,
      right: 0.0,
      platform: TargetPlatform.iOS,
      expected: 0.0,
      viewport: true,
    ),
    (
      name: 'ordinary iPhone retains its hardware inset',
      wide: false,
      duo: false,
      native: true,
      right: 68.0,
      platform: TargetPlatform.iOS,
      expected: 68.0,
      viewport: false,
    ),
    (
      name: 'missing native geometry retains hardware inset',
      wide: false,
      duo: false,
      native: false,
      right: 68.0,
      platform: TargetPlatform.iOS,
      expected: 68.0,
      viewport: false,
    ),
    (
      name: 'Android retains existing mobile scrollbar',
      wide: false,
      duo: true,
      native: true,
      right: 68.0,
      platform: TargetPlatform.android,
      expected: 68.0,
      viewport: false,
    ),
    (
      name: 'Duo inner retains existing viewport scrollbar',
      wide: true,
      duo: true,
      native: true,
      right: 68.0,
      platform: TargetPlatform.iOS,
      expected: 0.0,
      viewport: true,
    ),
    (
      name: 'ordinary iPad retains existing viewport scrollbar',
      wide: true,
      duo: false,
      native: true,
      right: 68.0,
      platform: TargetPlatform.iOS,
      expected: 0.0,
      viewport: true,
    ),
  ]) {
    testWidgets(sample.name, (t) async {
      final g = geometry(wide: sample.wide, duo: sample.duo);
      await t.binding.setSurfaceSize(g.size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      styleSetting.actualLayout = sample.wide ? LayoutMode.tabletV2 : LayoutMode.mobileV2;
      final c = NativeWindowGeometryController();
      if (sample.native) {
        c.value = g;
      }
      final page = _DetailProbe();
      await t.pumpWidget(frame(c, page, right: sample.right, platform: sample.platform));
      await t.pumpAndSettle();
      page.state.scrollController.jumpTo(100);
      await t.pump(const Duration(milliseconds: 50));
      final raw = find.byWidgetPredicate((w) => w is RawScrollbar);
      final bar = t.state<RawScrollbarState>(raw);
      final painter = bar.scrollbarPainter;
      expect(painter.padding.resolve(TextDirection.ltr).right, sample.expected);
      expect(find.byType(ViewportScrollbar), sample.viewport ? findsOneWidget : findsNothing);
      expect(t.getRect(find.byType(Viewport)).right, g.size.width);
      expect(t.getRect(find.byKey(const ValueKey('full-width-content'))).right, g.size.width);
      expect(page.observedMedia['content']!.padding.right, sample.right);
      expect(page.observedMedia['content']!.viewPadding.right, sample.right);
      if (!sample.wide && sample.duo && sample.native && sample.platform == TargetPlatform.iOS) {
        final rect = t.getRect(raw);
        final thumbRight = rect.right - painter.crossAxisMargin - sample.expected;
        expect(g.size.width - thumbRight, 3); // Standard Cupertino margin, no side-rail offset.
      }
      expect(t.takeException(), isNull);
      await finish(t, c);
    });
  }
  testWidgets('fold/unfold preserves actual detail scroll state and edge alignment', (t) async {
    await t.binding.setSurfaceSize(const Size(430, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    styleSetting.actualLayout = LayoutMode.mobileV2;
    final c = NativeWindowGeometryController()..value = geometry();
    final page = _DetailProbe();
    await t.pumpWidget(frame(c, page));
    await t.pumpAndSettle();
    page.state.scrollController.jumpTo(350);
    await t.pumpAndSettle();
    final scroll = t.state<ScrollableState>(find.byType(Scrollable));
    for (final wide in [true, false, true, false]) {
      styleSetting.actualLayout = wide ? LayoutMode.tabletV2 : LayoutMode.mobileV2;
      c.value = geometry(wide: wide);
      await t.binding.setSurfaceSize(c.value!.size);
      await t.pumpAndSettle();
      expect(t.state<ScrollableState>(find.byType(Scrollable)), same(scroll));
      expect(page.state.scrollController.position.pixels, 350);
      final bar = t.state<RawScrollbarState>(find.byWidgetPredicate((w) => w is RawScrollbar));
      expect(bar.scrollbarPainter.padding.resolve(TextDirection.ltr).right, 0);
      expect(page.observedMedia['content']!.padding.right, 68);
    }
    expect(t.takeException(), isNull);
    await finish(t, c);
  });
}
