import 'package:flutter/material.dart';

import '../config/ui_config.dart';

/// Keep a page out of the left and right system insets, e.g. a display cutout in landscape, or the vertical status bar on the
/// right side of iPhone Duo's inner screen. The insets are painted with the page background so the page still looks edge-to-edge.
///
/// [AppBar] and [ListTile] avoid these insets by themselves, but custom page bodies don't, so this is applied to every non-fullscreen
/// page in [EHPage] instead of patching each page. Top and bottom insets are still handled by each page, so that lists can keep
/// scrolling under the home indicator.
class HorizontalSafeArea extends StatelessWidget {
  final Widget child;

  const HorizontalSafeArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: UIConfig.backGroundColor(context),
      child: SafeArea(top: false, bottom: false, child: child),
    );
  }
}
