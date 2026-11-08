import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/utils/adaptive_pane_hero_controller.dart';
import 'package:jhentai/src/widget/native_window_scaffold.dart';
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
final flightDirections = <HeroFlightDirection>[];
Widget cover(int gid, {bool detail = false}) => Hero(
  tag: 'cover-$gid',
  flightShuttleBuilder: (_, __, direction, ___, ____) {
    flightDirections.add(direction);
    return const ColoredBox(key: ValueKey('cover-flight'), color: Colors.yellow);
  },
  child: const ColoredBox(color: Colors.yellow),
);

class _PaintedDetail extends StatefulWidget {
  final int gid;
  const _PaintedDetail(this.gid, {super.key});
  @override
  State<_PaintedDetail> createState() => _PaintedDetailState();
}

class _PaintedDetailState extends State<_PaintedDetail> {
  final retained = Object();
  @override
  Widget build(BuildContext context) => NativeWindowScaffold(
    backgroundColor: widget.gid == 1
        ? Colors.red
        : widget.gid == 2
        ? Colors.blue
        : Colors.purple,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Text('gallery ${widget.gid}', style: const TextStyle(color: Colors.white)),
        Positioned(left: 180, top: 200, width: 120, height: 160, child: cover(widget.gid, detail: true)),
      ],
    ),
  );
}

Widget detail() => _PaintedDetail(
  (Get.arguments as DetailsPageArgument).galleryUrl.gid,
  key: ValueKey('detail-${(Get.arguments as DetailsPageArgument).galleryUrl.gid}'),
);
Widget search() => Scaffold(
  backgroundColor: Colors.green,
  body: Stack(
    children: [
      const Text('tag results'),
      for (final gid in [2, 3]) Positioned(left: 20 + (gid - 2) * 110, top: 120, width: 80, height: 100, child: cover(gid)),
    ],
  ),
);

class _FrameShell extends StatefulWidget {
  const _FrameShell();
  @override
  State<_FrameShell> createState() => _FrameShellState();
}

class _FrameShellState extends State<_FrameShell> {
  late final lo = adaptivePaneNavigation.observer(AdaptivePane.left), ro = adaptivePaneNavigation.observer(AdaptivePane.right);
  late final leftHero = MaterialApp.createMaterialHeroController();
  late final rightHero = AdaptivePaneHeroController(adaptivePaneNavigation);
  @override
  void initState() {
    super.initState();
    adaptivePaneNavigation.attach();
  }

  @override
  void dispose() {
    leftHero.dispose();
    rightHero.dispose();
    adaptivePaneNavigation.detach();
    super.dispose();
  }

  Widget pane(bool l) => Listener(
    onPointerDown: (_) => adaptivePaneNavigation.focus(l ? AdaptivePane.left : AdaptivePane.right),
    child: Navigator(
      key: Get.nestedKey(l ? leftV2 : rightV2),
      observers: [GetObserver(null, l ? leftRouting : rightRouting), l ? lo : ro, l ? leftHero : rightHero],
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
                ? () => _PaintedDetail(
                    (settings.arguments as DetailsPageArgument).galleryUrl.gid,
                    key: ValueKey('detail-${(settings.arguments as DetailsPageArgument).galleryUrl.gid}'),
                  )
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

const paintKey = ValueKey('transition-pixels');
Future<({int red, int blue, int green})> pixels(WidgetTester t) async {
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(paintKey));
  final data = (await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: .2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes;
  }))!;
  var red = 0, blue = 0, green = 0;
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    final r = data.getUint8(i), g = data.getUint8(i + 1), b = data.getUint8(i + 2);
    if (r > 110 && r > g * 2 && r > b * 2) {
      red++;
    }
    if (b > 110 && b > g * 1.35 && b > r * 2) {
      blue++;
    }
    if (g > 55 && g > r * 1.4 && g > b * 1.4) {
      green++;
    }
  }
  return (red: red, blue: blue, green: green);
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
    flightDirections.clear();
  });
  tearDown(() {
    Get.reset();
    styleSetting.actualLayout = oldActual;
    styleSetting.layout.value = oldPreferred;
  });
  Future<void> mount(WidgetTester t, {Transition transition = Transition.cupertino}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(430, 800);
    await t.binding.setSurfaceSize(const Size(430, 800));
    addTearDown(() async {
      t.view.resetDevicePixelRatio();
      t.view.resetPhysicalSize();
      await t.binding.setSurfaceSize(null);
    });
    styleSetting.layout.value = LayoutMode.automatic;
    await t.pumpWidget(
      RepaintBoundary(
        key: paintKey,
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Scaffold(body: _FrameShell()),
          getPages: [
            GetPage(name: Routes.details, page: detail, transition: transition, popGesture: transition == Transition.cupertino),
            GetPage(name: Routes.mobileV2Search, page: search, transition: Transition.cupertino),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t, int gid, {bool settle = true}) async {
    toRoute(Routes.details, arguments: gallery(gid), offAllBefore: false);
    if (settle) {
      await t.pumpAndSettle();
    }
  }

  Future<void> tags(WidgetTester t) async {
    toRoute(Routes.mobileV2Search, preventDuplicates: false);
    await t.pumpAndSettle();
  }

  Future<void> back(WidgetTester t, String route, {bool settle = true}) async {
    backRoute(currentRoute: route);
    if (settle) {
      await t.pumpAndSettle();
    }
  }

  Future<void> frames(WidgetTester t, {bool rejectBlue = false}) async {
    for (var i = 0; i < 24; i++) {
      await t.pump(i < 2 ? Duration.zero : const Duration(milliseconds: 16));
      final p = await pixels(t);
      expect(p.red, 0, reason: 'old A painted at frame $i');
      if (rejectBlue) {
        expect(p.blue, 0, reason: 'old B painted at frame $i');
      }
      expect(t.takeException(), isNull);
    }
  }

  Future<void> finish(WidgetTester t) async {
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  }

  for (final transition in [Transition.cupertino, Transition.fadeIn]) {
    testWidgets('tag result transition never paints previous detail: $transition', (t) async {
      await mount(t, transition: transition);
      await open(t, 1);
      final a = t.state<_PaintedDetailState>(find.byKey(const ValueKey('detail-1')));
      await tags(t);
      flightDirections.clear();
      await open(t, 2, settle: false);
      await frames(t);
      await t.pumpAndSettle();
      expect(find.text('gallery 2'), findsOneWidget);
      expect(t.state<_PaintedDetailState>(find.byKey(const ValueKey('detail-1'), skipOffstage: false)), same(a));
      if (transition == Transition.cupertino) {
        expect(flightDirections, contains(HeroFlightDirection.push));
      }
      await back(t, Routes.details, settle: false);
      await frames(t);
      await t.pumpAndSettle();
      expect(find.text('tag results'), findsOneWidget);
      if (transition == Transition.cupertino) {
        expect(flightDirections, contains(HeroFlightDirection.pop));
      }
      await back(t, Routes.mobileV2Search);
      expect(find.text('gallery 1'), findsOneWidget);
      expect((await pixels(t)).red, greaterThan(100));
      expect(t.state<_PaintedDetailState>(find.byKey(const ValueKey('detail-1'))), same(a));
      await finish(t);
    });
  }
  testWidgets('interactive cancellation and completion reveal search without flashing old detail', (t) async {
    await mount(t);
    await open(t, 1);
    await tags(t);
    await open(t, 2);
    var gesture = await t.startGesture(const Offset(5, 400));
    await gesture.moveBy(const Offset(100, 0));
    await t.pump();
    await frames(t);
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('gallery 2'), findsOneWidget);
    gesture = await t.startGesture(const Offset(5, 400));
    await gesture.moveBy(const Offset(320, 0));
    await t.pump();
    await frames(t);
    await gesture.up();
    await frames(t);
    await t.pumpAndSettle();
    expect(find.text('tag results'), findsOneWidget);
    await finish(t);
  });
  testWidgets('folding mid-transition preserves stacks and hides stale detail when folded again', (t) async {
    await mount(t);
    await open(t, 1);
    await tags(t);
    await open(t, 2, settle: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    await t.binding.setSurfaceSize(const Size(960, 800));
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    await t.binding.setSurfaceSize(const Size(430, 800));
    await frames(t);
    await t.pumpAndSettle();
    expect(find.text('gallery 2'), findsOneWidget);
    await back(t, Routes.details);
    expect(find.text('tag results'), findsOneWidget);
    await back(t, Routes.mobileV2Search);
    expect(find.text('gallery 1'), findsOneWidget);
    await finish(t);
  });
  testWidgets('ordinary detail-to-detail animation still paints its true previous detail', (t) async {
    await mount(t);
    await open(t, 1);
    await open(t, 2, settle: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect((await pixels(t)).red, greaterThan(100));
    await t.pumpAndSettle();
    await back(t, Routes.details);
    expect(find.text('gallery 1'), findsOneWidget);
    await finish(t);
  });
  testWidgets('nested tag transition masks every older right detail', (t) async {
    await mount(t);
    await open(t, 1);
    await tags(t);
    await open(t, 2);
    await tags(t);
    await open(t, 3, settle: false);
    await frames(t, rejectBlue: true);
    await t.pumpAndSettle();
    await back(t, Routes.details, settle: false);
    await frames(t, rejectBlue: true);
    await t.pumpAndSettle();
    expect(find.text('tag results'), findsOneWidget);
    await back(t, Routes.mobileV2Search);
    expect(find.text('gallery 2'), findsOneWidget);
    await finish(t);
  });
  testWidgets('rapid push pop and remove release temporary visibility guards', (t) async {
    await mount(t);
    await open(t, 1);
    await tags(t);
    await open(t, 2, settle: false);
    await back(t, Routes.details, settle: false);
    await frames(t);
    await t.pumpAndSettle();
    expect(find.text('tag results'), findsOneWidget);
    await open(t, 2, settle: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    final route = adaptivePaneNavigation.topPageRoute(AdaptivePane.right)!;
    Get.nestedKey(rightV2)!.currentState!.removeRoute(route);
    await frames(t);
    await t.pumpAndSettle();
    expect(find.text('tag results'), findsOneWidget);
    await back(t, Routes.mobileV2Search);
    expect(find.text('gallery 1'), findsOneWidget);
    await finish(t);
  });
}
