import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/model/jh_layout.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/routes/eh_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/adaptive_page_route.dart';
import 'package:jhentai/src/utils/adaptive_pane_navigation.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/adaptive_split_view.dart';

DetailsPageArgument gallery(int gid) => DetailsPageArgument(
  galleryUrl: GalleryUrl(isEH: true, gid: gid, token: '0123456789'),
);
Widget detail() => Scaffold(body: Text('gallery ${(Get.arguments as DetailsPageArgument).galleryUrl.gid}'));
Widget search() => Scaffold(
  body: Column(
    children: [
      const Text('tag results'),
      TextButton(
        onPressed: () => toRoute(Routes.details, arguments: gallery(2)),
        child: const Text('open B'),
      ),
    ],
  ),
);

class _Shell extends StatefulWidget {
  const _Shell();
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final lo = adaptivePaneNavigation.observer(AdaptivePane.left), ro = adaptivePaneNavigation.observer(AdaptivePane.right);
  @override
  void initState() {
    super.initState();
    adaptivePaneNavigation.attach();
  }

  @override
  void dispose() {
    adaptivePaneNavigation.detach();
    super.dispose();
  }

  Widget pane(bool l) => Listener(
    onPointerDown: (_) => adaptivePaneNavigation.focus(l ? AdaptivePane.left : AdaptivePane.right),
    child: Navigator(
      key: Get.nestedKey(l ? leftV2 : rightV2),
      observers: [GetObserver(null, l ? leftRouting : rightRouting), l ? lo : ro],
      onGenerateInitialRoutes: (_, __) => [
        GetPageRoute(
          settings: RouteSettings(name: l ? Routes.mobileLayoutV2 : Routes.blank),
          page: () => l ? const Scaffold(body: Text('home')) : const AdaptivePanePlaceholder(wideChild: Text('blank')),
          transition: Transition.noTransition,
        ),
      ],
      onGenerateRoute: (settings) {
        Get.routing.args = settings.arguments;
        return adaptivePageRoute(
          page: EHPage(
            name: settings.name!,
            page: settings.name == Routes.details
                ? () => Scaffold(body: Text('gallery ${(settings.arguments as DetailsPageArgument).galleryUrl.gid}'))
                : search,
          ),
          settings: settings,
          compact: adaptivePaneNavigation.compact,
          popGesture: true,
          wideTransition: Transition.fadeIn,
          wideDuration: const Duration(milliseconds: 150),
        );
      },
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final compact = c.maxWidth < 600;
      adaptivePaneNavigation.compact = compact;
      styleSetting.actualLayout = compact ? LayoutMode.mobileV2 : LayoutMode.tabletV2;
      return AnimatedBuilder(
        animation: adaptivePaneNavigation,
        builder: (_, __) => AdaptiveSplitView(
          compact: compact,
          showRight: adaptivePaneNavigation.activePane == AdaptivePane.right,
          rightTransition: adaptivePaneNavigation.rightBoundaryRoute?.animation,
          rightRoute: adaptivePaneNavigation.rightBoundaryRoute,
          rightGestureInProgress: adaptivePaneNavigation.rightBoundaryRoute?.navigator?.userGestureInProgressNotifier,
          rightParallax: usesPhoneParallax(adaptivePaneNavigation.topPageRoute(AdaptivePane.left), adaptivePaneNavigation.rightBoundaryRoute),
          initialRatio: .382,
          dividerColor: Colors.grey,
          onRatioChanged: (_) {},
          left: pane(true),
          right: pane(false),
        ),
      );
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LayoutMode oldActual, oldPreferred;
  setUp(() {
    Get.testMode = true;
    oldActual = styleSetting.actualLayout;
    oldPreferred = styleSetting.layout.value;
    leftRouting = Routing();
    rightRouting = Routing();
  });
  tearDown(() {
    Get.reset();
    styleSetting.actualLayout = oldActual;
    styleSetting.layout.value = oldPreferred;
  });
  Future<void> mount(WidgetTester t, {bool fixed = false, bool wide = false}) async {
    await t.binding.setSurfaceSize(Size(wide ? 960 : 430, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    styleSetting.layout.value = fixed ? LayoutMode.mobileV2 : LayoutMode.automatic;
    styleSetting.actualLayout = fixed
        ? LayoutMode.mobileV2
        : wide
        ? LayoutMode.tabletV2
        : LayoutMode.mobileV2;
    await t.pumpWidget(
      GetMaterialApp(
        home: fixed ? const Scaffold(body: Text('home')) : const Scaffold(body: _Shell()),
        getPages: [
          GetPage(name: Routes.details, page: detail),
          GetPage(name: Routes.mobileV2Search, page: search),
        ],
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t, int gid, {bool duplicates = true, bool? clear}) async {
    toRoute(Routes.details, arguments: gallery(gid), preventDuplicates: duplicates, offAllBefore: clear);
    await t.pumpAndSettle();
  }

  Future<void> tags(WidgetTester t) async {
    toRoute(Routes.mobileV2Search, preventDuplicates: false);
    await t.pumpAndSettle();
  }

  Future<void> back(WidgetTester t, String route) async {
    backRoute(currentRoute: route);
    await t.pumpAndSettle();
  }

  Future<void> finish(WidgetTester t) async {
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  for (final fixed in [false, true]) {
    testWidgets('A tag search B returns search A home: fixedPhone=$fixed', (t) async {
      await mount(t, fixed: fixed);
      await open(t, 1);
      await tags(t);
      await t.tap(find.text('open B'));
      await t.pumpAndSettle();
      expect(find.text('gallery 2'), findsOneWidget);
      expect(find.text('gallery 1'), findsNothing);
      await back(t, Routes.details);
      expect(find.text('tag results'), findsOneWidget);
      await back(t, Routes.mobileV2Search);
      expect(find.text('gallery 1'), findsOneWidget);
      await back(t, Routes.details);
      expect(find.text('home'), findsOneWidget);
      await finish(t);
    });
  }
  for (final fixed in [false, true]) {
    testWidgets('visible same gid is deduplicated but different gallery opens: fixedPhone=$fixed', (t) async {
      await mount(t, fixed: fixed);
      await open(t, 1);
      final before = fixed ? Get.routing.route : adaptivePaneNavigation.topPageRoute(AdaptivePane.right);
      await open(t, 1, clear: false);
      expect(fixed ? Get.routing.route : adaptivePaneNavigation.topPageRoute(AdaptivePane.right), same(before));
      await open(t, 2, clear: false);
      expect(find.text('gallery 2'), findsOneWidget);
      await back(t, Routes.details);
      expect(find.text('gallery 1'), findsOneWidget);
      await finish(t);
    });
  }
  testWidgets('opening the same gallery from a newer search keeps search in return history', (t) async {
    await mount(t);
    await open(t, 1);
    await tags(t);
    await open(t, 1);
    expect(find.text('gallery 1'), findsOneWidget);
    await back(t, Routes.details);
    expect(find.text('tag results'), findsOneWidget);
    await back(t, Routes.mobileV2Search);
    expect(find.text('gallery 1'), findsOneWidget);
    await finish(t);
  });
  testWidgets('explicit duplicate opt-out and rapid repeated taps retain expected routes', (t) async {
    await mount(t);
    await open(t, 1);
    final first = adaptivePaneNavigation.topPageRoute(AdaptivePane.right);
    await open(t, 1, duplicates: false, clear: false);
    expect(adaptivePaneNavigation.topPageRoute(AdaptivePane.right), isNot(same(first)));
    await back(t, Routes.details);
    await tags(t);
    toRoute(Routes.details, arguments: gallery(2));
    final b = adaptivePaneNavigation.topPageRoute(AdaptivePane.right);
    toRoute(Routes.details, arguments: gallery(2));
    expect(adaptivePaneNavigation.topPageRoute(AdaptivePane.right), same(b));
    await t.pumpAndSettle();
    await back(t, Routes.details);
    expect(find.text('tag results'), findsOneWidget);
    await finish(t);
  });
  testWidgets('nested tags return C search B search A without jumping to hidden older details', (t) async {
    await mount(t);
    await open(t, 1);
    await tags(t);
    await open(t, 2);
    await tags(t);
    await open(t, 3);
    expect(find.text('gallery 3'), findsOneWidget);
    await back(t, Routes.details);
    expect(find.text('tag results'), findsOneWidget);
    await back(t, Routes.mobileV2Search);
    expect(find.text('gallery 2'), findsOneWidget);
    await back(t, Routes.details);
    expect(find.text('tag results'), findsOneWidget);
    await back(t, Routes.mobileV2Search);
    expect(find.text('gallery 1'), findsOneWidget);
    await finish(t);
  });
  testWidgets('folding between tag navigation steps retains stacks and visible-route semantics', (t) async {
    await mount(t);
    await open(t, 1);
    await tags(t);
    expect(isRouteAtTop(Routes.details), isFalse);
    expect(isRouteAtTop(Routes.mobileV2Search), isTrue);
    await t.binding.setSurfaceSize(const Size(960, 800));
    await t.pumpAndSettle();
    expect(isRouteAtTop(Routes.details), isTrue);
    await t.binding.setSurfaceSize(const Size(430, 800));
    await t.pumpAndSettle();
    await open(t, 2);
    for (final width in [960.0, 430.0]) {
      await t.binding.setSurfaceSize(Size(width, 800));
      await t.pumpAndSettle();
      expect(find.text('gallery 2'), findsOneWidget);
    }
    await back(t, Routes.details);
    expect(find.text('tag results'), findsOneWidget);
    await finish(t);
  });
  testWidgets('wide layout continues to replace right details using its existing clear policy', (t) async {
    await mount(t, wide: true);
    await open(t, 1);
    await tags(t);
    await open(t, 2);
    expect(find.text('gallery 2'), findsOneWidget);
    expect(find.text('gallery 1'), findsNothing);
    await back(t, Routes.details);
    expect(find.text('blank'), findsOneWidget);
    expect(find.text('tag results'), findsOneWidget);
    await finish(t);
  });
}
