import 'package:flutter/material.dart';

/// iOS scrolling content paints down to the bottom edge on both displays.
/// The final sliver supplies clearance for the last item; buttons retain their
/// own safe placement. Do not cache this decision from the current layout mode.
class ScrollBodySafeArea extends StatelessWidget {
  final bool extendToBottom;
  final Widget child;

  const ScrollBodySafeArea(
      {super.key, required this.extendToBottom, required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom:
            Theme.of(context).platform != TargetPlatform.iOS && !extendToBottom,
        child: child,
      );
}
