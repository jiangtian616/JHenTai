import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/native_window_geometry.dart';
import 'adaptive_split_view.dart';

/// Opt app-bar pages into the native horizontal status band without changing
/// unrelated pages, dialogs or readers. Content consumes outer right clearance
/// once, so pages without their own SafeArea cannot enter the native status rail.
class NativeWindowScaffold extends StatelessWidget {
  /// Device-specific optical calibration confirmed on iPhone Duo.
  static const double _duoInnerHeaderDownshift = 7;

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Color? backgroundColor;
  final PreferredSizeWidget? appBar;
  final Widget? body;

  /// Embedded drawers keep their local header instead of sharing the window band.
  final bool adaptHeader;

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
      this.adaptHeader = true,
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
    return AdaptivePaneRouteVisibility(child: LayoutBuilder(builder: (context, constraints) {
      final trailing = NativeWindowPane.isTrailing(context);
      final reserve = geometry != null && trailing ? geometry.headerTrailingWidth : 0.0;
      final inline = adaptHeader && geometry?.hasInlineHeader == true && appBar is AppBar && constraints.maxWidth >= reserve + 144;
      final downshift = geometry?.isDuoDevice == true ? _duoInnerHeaderDownshift : 0.0;
      final media = MediaQuery.of(context);
      final nativeRight = trailing ? math.max(geometry?.safeArea.right ?? 0.0, geometry?.rightRail?.width ?? 0.0) : 0.0;
      final rightInset = math.max(media.padding.right, nativeRight);
      final protectedMedia = media.copyWith(padding: media.padding.copyWith(right: rightInset, top: inline ? 0 : media.padding.top));
      final bar = inline
          ? PreferredSize(
              preferredSize: Size.fromHeight(geometry!.headerHeight + downshift + ((appBar as AppBar).bottom?.preferredSize.height ?? 0)),
              child: Padding(
                  padding: EdgeInsets.only(top: geometry.headerTopInset + downshift, right: math.max(0.0, reserve - rightInset)),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                        appBarTheme: Theme.of(context).appBarTheme.copyWith(toolbarHeight: geometry.headerHeight - geometry.headerTopInset)),
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
            floatingActionButtonLocation: floatingActionButtonLocation ??
                (geometry != null && (constraints.maxHeight - geometry.size.height).abs() < 1
                    ? _NativeWindowFabLocation(geometry, allowRail: trailing && (constraints.maxWidth - geometry.size.width).abs() < 1)
                    : null),
            endDrawer: endDrawer,
            drawerEdgeDragWidth: drawerEdgeDragWidth,
            endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            bottomNavigationBar: bottomNavigationBar),
      );
    }));
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

/// Use the same native rail as the root scroll action without changing the
/// button callback, size or page transition. Explicit page locations win.
class _NativeWindowFabLocation extends FloatingActionButtonLocation {
  final NativeWindowGeometry geometry;
  final bool allowRail;
  const _NativeWindowFabLocation(this.geometry, {required this.allowRail});
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffold) {
    final normal = FloatingActionButtonLocation.endFloat.getOffset(scaffold);
    final safeY = scaffold.scaffoldSize.height - geometry.safeArea.bottom - 16 - scaffold.floatingActionButtonSize.height;
    final protected = Offset(normal.dx, safeY >= 0 ? math.min(normal.dy, safeY) : normal.dy);
    if (!allowRail) {
      return protected;
    }
    final clearance = math.max(0.0, scaffold.scaffoldSize.height - protected.dy - scaffold.floatingActionButtonSize.height - 16);
    return geometry
            .railActionRect(scaffold.floatingActionButtonSize, bottomInset: clearance, availableHeight: scaffold.scaffoldSize.height)
            ?.topLeft ??
        protected;
  }
}
