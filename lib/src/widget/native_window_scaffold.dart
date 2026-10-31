import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/native_window_geometry.dart';

/// Opt app-bar pages into the native horizontal status band without changing
/// unrelated pages, dialogs or readers. Content consumes outer right clearance
/// once, so pages without their own SafeArea cannot enter the native status rail.
class NativeWindowScaffold extends StatelessWidget {
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget? body;

  /// Gallery details avoid the native rail in title widgets only.
  final bool avoidBodyRight;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? endDrawer;
  final double? drawerEdgeDragWidth;
  final bool endDrawerEnableOpenDragGesture;
  final bool? resizeToAvoidBottomInset;
  final Widget? bottomNavigationBar;

  const NativeWindowScaffold(
      {super.key,
      this.scaffoldKey,
      this.backgroundColor,
      this.appBar,
      this.body,
      this.avoidBodyRight = true,
      this.floatingActionButton,
      this.floatingActionButtonLocation,
      this.endDrawer,
      this.drawerEdgeDragWidth,
      this.endDrawerEnableOpenDragGesture = true,
      this.resizeToAvoidBottomInset,
      this.bottomNavigationBar});

  @override
  Widget build(BuildContext context) {
    final geometry = NativeWindowGeometryScope.geometryOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final trailing = NativeWindowPane.isTrailing(context);
      final reserve = geometry != null && trailing ? geometry.headerTrailingWidth : 0.0;
      final inline = geometry?.hasInlineHeader == true && appBar is AppBar && constraints.maxWidth >= reserve + 144;
      final media = MediaQuery.of(context);
      final nativeRight = trailing ? math.max(geometry?.safeArea.right ?? 0.0, geometry?.rightRail?.width ?? 0.0) : 0.0;
      final rightInset = math.max(media.padding.right, nativeRight);
      final protectedMedia = media.copyWith(padding: media.padding.copyWith(right: rightInset, top: inline ? 0 : media.padding.top));
      final bar = inline
          ? PreferredSize(
              preferredSize: Size.fromHeight(geometry!.headerHeight + ((appBar as AppBar).bottom?.preferredSize.height ?? 0)),
              child: Padding(
                  padding: EdgeInsets.only(top: geometry.headerTopInset, right: math.max(0.0, reserve - rightInset)),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                        appBarTheme:
                            Theme.of(context).appBarTheme.copyWith(toolbarHeight: geometry.headerHeight - geometry.headerTopInset)),
                    child: appBar!,
                  )),
            )
          : appBar;
      return MediaQuery(
        data: protectedMedia,
        child: Scaffold(
            key: scaffoldKey,
            backgroundColor: backgroundColor,
            appBar: bar,
            body: _buildBody(media),
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            endDrawer: endDrawer,
            drawerEdgeDragWidth: drawerEdgeDragWidth,
            endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            bottomNavigationBar: bottomNavigationBar),
      );
    });
  }

  Widget? _buildBody(MediaQueryData originalMedia) {
    if (body == null) {
      return null;
    }
    if (avoidBodyRight) {
      return SafeArea(left: false, top: false, bottom: false, child: body!);
    }
    // Restore the body's prior lateral media while retaining Scaffold's top and
    // bottom adjustments. Its cover, metadata and action row keep full width.
    return Builder(builder: (context) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          padding: media.padding.copyWith(right: originalMedia.padding.right),
          viewPadding: media.viewPadding.copyWith(right: originalMedia.viewPadding.right),
        ),
        child: body!,
      );
    });
  }
}
