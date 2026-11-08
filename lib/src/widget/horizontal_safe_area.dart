import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/ui_config.dart';

/// Keep a page out of the left and right system insets, e.g. a display cutout in landscape, or the vertical status bar on the
/// right side of iPhone Duo's inner screen. The insets are painted with the page background so the page still looks edge-to-edge.
///
/// [AppBar] and [ListTile] avoid these insets by themselves, but custom page bodies don't, so this is applied to every non-fullscreen
/// page in [EHPage] instead of patching each page. Top and bottom insets are still handled by each page, so that lists can keep
/// scrolling under the home indicator.
///
/// With [extendIntoVerticalBar], the inset of iPhone Duo's vertical bar is left to the page, so that its content can extend under
/// the bar while its [AppBar] still avoids it.
class HorizontalSafeArea extends StatelessWidget {
  final bool extendIntoVerticalBar;
  final Widget child;

  const HorizontalSafeArea({super.key, this.extendIntoVerticalBar = false, required this.child});

  @override
  Widget build(BuildContext context) {
    /// reading MediaQuery rebuilds this when the insets change, e.g. when iPhone Duo folds, unfolds or rotates
    bool keepVerticalBarInset = extendIntoVerticalBar && MediaQuery.paddingOf(context).horizontal > 0 && hasVerticalBar(context);

    return ColoredBox(
      color: UIConfig.backGroundColor(context),
      child: SafeArea(top: false, bottom: false, left: !keepVerticalBarInset, right: !keepVerticalBarInset, child: child),
    );
  }

  /// iPhone Duo reports its vertical bar as an inset on one side only with no top inset, while a regular iPhone in landscape has
  /// insets on both sides. Read from the window instead of [MediaQuery], because the columns of tablet and desktop layout remove the
  /// insets of the edges they don't touch.
  static bool hasVerticalBar(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }

    final view = View.of(context);
    EdgeInsets padding = EdgeInsets.fromViewPadding(view.viewPadding, view.devicePixelRatio);
    return padding.top == 0 && (padding.left == 0) != (padding.right == 0);
  }
}
