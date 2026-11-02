import 'package:flutter/material.dart';

/// Align the vertical scroll indicator with its viewport instead of applying
/// the window's lateral safe area a second time. Restore the original media
/// data around the content, so its own safe areas and controls stay protected.
class ViewportScrollbar extends StatelessWidget {
  final ScrollController? controller;
  final Widget child;
  final bool? thumbVisibility;
  final ScrollbarOrientation? scrollbarOrientation;

  const ViewportScrollbar({super.key, required this.controller, required this.child, this.thumbVisibility, this.scrollbarOrientation});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(padding: media.padding.copyWith(left: 0, right: 0)),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: thumbVisibility,
        scrollbarOrientation: scrollbarOrientation,
        child: MediaQuery(data: media, child: child),
      ),
    );
  }
}
