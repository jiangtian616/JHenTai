import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import '../utils/adaptive_pane_navigation.dart';

/// Relayout panes in place instead of replacing their Navigators on resize.
class AdaptiveSplitView extends StatefulWidget {
  final bool compact;
  final bool showRight;
  final Animation<double>? rightTransition;
  final PageRoute<dynamic>? rightRoute;
  final ValueListenable<bool>? rightGestureInProgress;
  final bool rightParallax;
  final Widget left;
  final Widget right;
  final double initialRatio;
  final Color dividerColor;
  final ValueChanged<double> onRatioChanged;

  const AdaptiveSplitView({
    super.key,
    required this.compact,
    required this.showRight,
    this.rightTransition,
    this.rightRoute,
    this.rightGestureInProgress,
    this.rightParallax = false,
    required this.left,
    required this.right,
    required this.initialRatio,
    required this.dividerColor,
    required this.onRatioChanged,
  });

  /// Depend on the actual pane layout so retained children rebuild on a fold.
  static bool? compactOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_AdaptivePaneViewport>()?.compact;

  @override
  State<AdaptiveSplitView> createState() => _AdaptiveSplitViewState();
}

class _AdaptiveSplitViewState extends State<AdaptiveSplitView> {
  late double _ratio = widget.initialRatio;

  @override
  Widget build(BuildContext context) {
    return _AdaptivePaneViewport(
      compact: widget.compact,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.rightTransition, widget.rightGestureInProgress]),
        builder: (context, _) => _buildPanes(context),
      ),
    );
  }

  Widget _buildPanes(BuildContext context) {
    final animation = widget.rightTransition;
    final transitioning = animation?.status == AnimationStatus.forward || animation?.status == AnimationStatus.reverse;
    // HeroController briefly lays out the destination offstage at its final
    // position. Keep the actual source visible during that preparation frame.
    final preparingHero = widget.rightRoute?.offstage ?? false;
    final showBoth = widget.compact && (transitioning || preparingHero);
    final showRight = widget.showRight && animation?.status != AnimationStatus.dismissed;
    final hideLeft = widget.compact && showRight && !showBoth;
    final hideRight = widget.compact && !showRight && !showBoth;
    final left = CupertinoPageTransition(
      primaryRouteAnimation: const AlwaysStoppedAnimation(1),
      secondaryRouteAnimation:
          widget.compact && widget.rightParallax && animation != null && (showRight || showBoth) ? animation : const AlwaysStoppedAnimation(0),
      linearTransition: widget.rightGestureInProgress?.value ?? false,
      child: widget.left,
    );
    return LayoutBuilder(builder: (context, constraints) {
      final available = math.max(0.0, constraints.maxWidth - 7.5);
      final minimum = math.min(100.0, available / 2);
      final leftWidth = (available * _ratio).clamp(minimum, available - minimum).toDouble();
      return CustomMultiChildLayout(
        delegate: _PaneLayout(widget.compact, leftWidth),
        children: [
          LayoutId(
            id: 0,
            child: Offstage(
              offstage: hideLeft,
              child: HeroMode(
                enabled: !widget.compact || !showRight,
                child: TickerMode(enabled: !hideLeft, child: IgnorePointer(ignoring: widget.compact && (showRight || showBoth), child: left)),
              ),
            ),
          ),
          LayoutId(
            id: 1,
            child: Offstage(
              offstage: hideRight,
              child: HeroMode(
                enabled: !widget.compact || showRight,
                child: TickerMode(enabled: !hideRight, child: widget.right),
              ),
            ),
          ),
          LayoutId(
            id: 2,
            child: Offstage(
              offstage: widget.compact,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    if (available <= 0) {
                      return;
                    }
                    setState(() {
                      _ratio = (_ratio + details.delta.dx / available).clamp(minimum / available, 1 - minimum / available).toDouble();
                    });
                    widget.onRatioChanged(_ratio);
                  },
                  child: Center(child: Container(width: 1.5, color: widget.dividerColor)),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _PaneLayout extends MultiChildLayoutDelegate {
  final bool compact;
  final double leftWidth;
  _PaneLayout(this.compact, this.leftWidth);

  @override
  void performLayout(Size size) {
    layoutChild(0, BoxConstraints.tight(Size(compact ? size.width : leftWidth, size.height)));
    positionChild(0, Offset.zero);
    layoutChild(1, BoxConstraints.tight(Size(compact ? size.width : math.max(0.0, size.width - leftWidth - 7.5), size.height)));
    positionChild(1, Offset(compact ? 0 : leftWidth + 7.5, 0));
    layoutChild(2, BoxConstraints.tight(Size(compact ? 0 : 7.5, size.height)));
    positionChild(2, Offset(compact ? 0 : leftWidth, 0));
  }

  @override
  bool shouldRelayout(_PaneLayout oldDelegate) => compact != oldDelegate.compact || leftWidth != oldDelegate.leftWidth;
}

/// The right stack's base must reveal the retained list during a compact
/// cross-pane transition. On the inner display it keeps its normal placeholder.
class AdaptivePanePlaceholder extends StatelessWidget {
  final Widget wideChild;
  const AdaptivePanePlaceholder({super.key, required this.wideChild});
  @override
  Widget build(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AdaptivePaneViewport>()?.compact == true ? const SizedBox.expand() : wideChild;
}

class _AdaptivePaneViewport extends InheritedWidget {
  final bool compact;
  const _AdaptivePaneViewport({required this.compact, required super.child});
  @override
  bool updateShouldNotify(_AdaptivePaneViewport oldWidget) => compact != oldWidget.compact;
}

/// Suppress stale pages underneath a cross-pane transition without disposing
/// their scroll state or changing ModalRoute's Hero preparation/offstage flag.
class AdaptivePaneRouteVisibility extends StatelessWidget {
  final Widget child;
  const AdaptivePaneRouteVisibility({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final compact = AdaptiveSplitView.compactOf(context) == true;
    final route = ModalRoute.of(context);
    return AnimatedBuilder(
        animation: adaptivePaneNavigation,
        child: child,
        builder: (context, child) {
          final hidden = compact && adaptivePaneNavigation.hidesRightRoute(route);
          return Offstage(offstage: hidden, child: HeroMode(enabled: !hidden, child: TickerMode(enabled: !hidden, child: child!)));
        });
  }
}
