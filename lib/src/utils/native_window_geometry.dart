import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// All rectangles arrive in the Flutter UIView's coordinate space, in points.
class NativeWindowGeometry {
  final Size size;
  final Rect statusBar;
  final EdgeInsets safeArea;
  final bool horizontalBars;
  final bool statusBarHidden;

  const NativeWindowGeometry(
      {required this.size,
      required this.statusBar,
      required this.safeArea,
      required this.horizontalBars,
      this.statusBarHidden = false});

  factory NativeWindowGeometry.fromMap(Map<dynamic, dynamic> data) {
    double number(Map<dynamic, dynamic> map, String key) =>
        (map[key] as num?)?.toDouble() ?? 0;
    final status = data['statusBar'] as Map<dynamic, dynamic>? ?? {};
    final safe = data['safeArea'] as Map<dynamic, dynamic>? ?? {};
    return NativeWindowGeometry(
      size: Size(number(data, 'width'), number(data, 'height')),
      statusBar: Rect.fromLTWH(number(status, 'x'), number(status, 'y'),
          number(status, 'width'), number(status, 'height')),
      safeArea: EdgeInsets.fromLTRB(number(safe, 'left'), number(safe, 'top'),
          number(safe, 'right'), number(safe, 'bottom')),
      horizontalBars: data['horizontalBars'] == true,
      statusBarHidden: data['statusBarHidden'] == true,
    );
  }

  /// Reject the old display's packet while native and Flutter are resizing.
  NativeWindowGeometry? forViewport(Size viewport) {
    if (size.isEmpty ||
        viewport.isEmpty ||
        (size.aspectRatio - viewport.aspectRatio).abs() > .03) {
      return null;
    }
    final x = viewport.width / size.width, y = viewport.height / size.height;
    return NativeWindowGeometry(
        size: viewport,
        horizontalBars: horizontalBars,
        statusBarHidden: statusBarHidden,
        statusBar: Rect.fromLTRB(statusBar.left * x, statusBar.top * y,
            statusBar.right * x, statusBar.bottom * y),
        safeArea: EdgeInsets.fromLTRB(safeArea.left * x, safeArea.top * y,
            safeArea.right * x, safeArea.bottom * y));
  }

  bool get hasInlineHeader =>
      horizontalBars &&
      !statusBarHidden &&
      !statusBar.isEmpty &&
      statusBar.height < size.height / 3 &&
      size.shortestSide >= 600;

  double get headerHeight =>
      math.max(56, math.max(safeArea.top, statusBar.bottom));

  /// Moving the AppBar down by this padding and reducing its toolbar by the
  /// same amount shifts the controls' center by half the padding. The native
  /// status frame's origin matters; centering in the whole band loses it.
  /// UIKit's public frame describes the status region, not glyph ink bounds.
  /// A twelve-point optical correction handles the remaining observed difference.
  /// Preserve at least 48 logical pixels for interactive toolbar controls.
  double get headerTopInset => (2 * (statusBar.center.dy + 12) - headerHeight)
      .clamp(0.0, math.max(0.0, headerHeight - 48))
      .toDouble();

  /// Public UIKit APIs may describe a full-width status band, not individual
  /// icons. In that case reserve a conservative trailing group, not the band.
  double get headerTrailingWidth => statusBar.width < size.width / 2
      ? math.max(0, size.width - statusBar.left + 12)
      : math.min(size.width * .4, math.max(176, headerHeight * 2.5));

  Rect? get rightRail {
    if (horizontalBars || statusBarHidden || statusBar.isEmpty) {
      return null;
    }
    // Use native geometry, never a child Scaffold's already-consumed padding.
    final verticalStatus = statusBar.height > statusBar.width &&
        statusBar.center.dx > size.width / 2;
    // Some OS builds report the whole top band even with a side status group.
    // A wide asymmetric native right inset still identifies that rail; ordinary
    // landscape camera insets are symmetric and stay protected.
    final asymmetricRail = safeArea.right >= 44 &&
        safeArea.right > safeArea.left + 16 &&
        safeArea.top < 44;
    if (!verticalStatus && !asymmetricRail) {
      return null;
    }
    final width = verticalStatus
        ? math.max(safeArea.right, size.width - statusBar.left)
        : safeArea.right;
    if (width < 44 || width > size.width / 3) {
      return null;
    }
    return Rect.fromLTWH(size.width - width, 0, width, size.height);
  }
}

class NativeWindowGeometryController
    extends ValueNotifier<NativeWindowGeometry?> {
  static const channel = MethodChannel('top.jtmonster.jhentai/window_geometry');
  final ValueChanged<Map<dynamic, dynamic>>? onDiagnostic;
  bool _started = false;
  final Map<Object, bool> _readers = {};
  bool get _readerImmersive => _readers.values.any((immersive) => immersive);
  bool _supportsReaderEdgeChrome = false;
  bool get supportsReaderEdgeChrome => _supportsReaderEdgeChrome;

  void retainReader(Object owner, {required bool immersive}) {
    final wasActive = _readers.isNotEmpty;
    final wasImmersive = _readerImmersive;
    _readers[owner] = immersive;
    if (wasActive != _readers.isNotEmpty || wasImmersive != _readerImmersive) {
      _syncReaderMode();
    }
  }

  void releaseReader(Object owner) {
    final wasActive = _readers.isNotEmpty;
    final wasImmersive = _readerImmersive;
    _readers.remove(owner);
    if (wasActive != _readers.isNotEmpty || wasImmersive != _readerImmersive) {
      _syncReaderMode();
    }
  }

  Future<void> _syncReaderMode() async {
    if (!_started || _disposed) {
      return;
    }
    try {
      await channel.invokeMethod<void>('setReaderState',
          {'active': _readers.isNotEmpty, 'immersive': _readerImmersive});
    } on MissingPluginException {
      // Older/non-iOS hosts retain their normal status bar configuration.
    } on PlatformException {
      // A disappearing scene may no longer accept window configuration.
    }
  }

  bool _disposed = false;
  NativeWindowGeometryController({this.onDiagnostic}) : super(null);

  void start() {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _started = true;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'geometryChanged' && call.arguments is Map) {
        accept(call.arguments as Map);
      }
    });
    refresh();
    if (_readers.isNotEmpty) {
      _syncReaderMode();
    }
  }

  void accept(Map<dynamic, dynamic> data) {
    if (_disposed) {
      return;
    }
    final next = NativeWindowGeometry.fromMap(data);
    if (next.size.isEmpty) {
      return;
    }
    _supportsReaderEdgeChrome = _supportsReaderEdgeChrome ||
        next.rightRail != null ||
        next.size.shortestSide >= 600;
    value = next;
    onDiagnostic?.call(data);
  }

  Future<void> refresh() async {
    if (!_started || _disposed) {
      return;
    }
    try {
      final packet =
          await channel.invokeMapMethod<dynamic, dynamic>('getGeometry');
      if (packet != null) {
        accept(packet);
      }
    } on MissingPluginException {
      // Older builds and non-iOS test hosts retain normal Flutter placement.
    } on PlatformException {
      // During scene restoration the first layout notification retries this.
    }
  }

  @override
  void dispose() {
    if (_readers.isNotEmpty) {
      _readers.clear();
      _syncReaderMode();
    }
    _disposed = true;
    if (_started) {
      channel.setMethodCallHandler(null);
    }
    super.dispose();
  }
}

class NativeWindowGeometryScope
    extends InheritedNotifier<NativeWindowGeometryController> {
  final Size viewport;
  const NativeWindowGeometryScope(
      {super.key,
      required this.viewport,
      required NativeWindowGeometryController controller,
      required super.child})
      : super(notifier: controller);
  @override
  bool updateShouldNotify(covariant NativeWindowGeometryScope oldWidget) =>
      viewport != oldWidget.viewport || super.updateShouldNotify(oldWidget);

  static NativeWindowGeometryController? controllerOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NativeWindowGeometryScope>()
          ?.notifier;

  static NativeWindowGeometry? geometryOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NativeWindowGeometryScope>();
    return scope?.notifier?.value?.forViewport(scope.viewport);
  }
}

/// Only the pane touching the window's trailing edge reserves status icons.
class NativeWindowPane extends InheritedWidget {
  final bool trailing;
  const NativeWindowPane(
      {super.key, required this.trailing, required super.child});
  static bool isTrailing(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NativeWindowPane>()
          ?.trailing ??
      true;
  @override
  bool updateShouldNotify(NativeWindowPane oldWidget) =>
      oldWidget.trailing != trailing;
}
