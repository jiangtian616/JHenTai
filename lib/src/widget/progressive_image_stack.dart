import 'package:flutter/widgets.dart';

/// Keeps a low-resolution thumbnail behind an image only until the full image
/// reports that it has loaded. Removing the thumbnail afterwards releases its
/// decoded image and avoids retaining two image layers for every reader page.
class ProgressiveImageStack extends StatefulWidget {
  const ProgressiveImageStack({
    super.key,
    required this.image,
    required this.thumbnail,
    required this.showThumbnail,
    required this.width,
    required this.height,
    this.onDispose,
  });

  final Widget image;
  final Widget thumbnail;
  final bool showThumbnail;
  final double width;
  final double height;
  final VoidCallback? onDispose;

  @override
  State<ProgressiveImageStack> createState() => _ProgressiveImageStackState();
}

class _ProgressiveImageStackState extends State<ProgressiveImageStack> {
  static const Key _thumbnailKey = ValueKey('progressive-thumbnail');
  static const Key _imageKey = ValueKey('progressive-full-image');

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.showThumbnail)
            KeyedSubtree(
              key: _thumbnailKey,
              child: widget.thumbnail,
            ),
          KeyedSubtree(
            key: _imageKey,
            child: widget.image,
          ),
        ],
      ),
    );
  }
}
