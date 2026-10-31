import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Relayout panes in place instead of replacing their Navigators on resize.
class AdaptiveSplitView extends StatefulWidget {
  final bool compact;
  final bool showRight;
  final Widget left;
  final Widget right;
  final double initialRatio;
  final Color dividerColor;
  final ValueChanged<double> onRatioChanged;

  const AdaptiveSplitView({
    super.key,
    required this.compact,
    required this.showRight,
    required this.left,
    required this.right,
    required this.initialRatio,
    required this.dividerColor,
    required this.onRatioChanged,
  });

  @override
  State<AdaptiveSplitView> createState() => _AdaptiveSplitViewState();
}

class _AdaptiveSplitViewState extends State<AdaptiveSplitView> {
  late double _ratio = widget.initialRatio;

  @override
  Widget build(BuildContext context) {
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
                offstage: widget.compact && widget.showRight, child: TickerMode(enabled: !widget.compact || !widget.showRight, child: widget.left)),
          ),
          LayoutId(
            id: 1,
            child: Offstage(
                offstage: widget.compact && !widget.showRight, child: TickerMode(enabled: !widget.compact || widget.showRight, child: widget.right)),
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
