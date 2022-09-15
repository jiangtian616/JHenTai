import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Listen to keydown event on desktop platform
class EHKeyboardListener extends StatelessWidget {
  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? handlePageUp;
  final VoidCallback? handlePageDown;
  final VoidCallback? handleArrowUp;
  final VoidCallback? handleArrowDown;
  final VoidCallback? handleArrowLeft;
  final VoidCallback? handleArrowRight;
  final VoidCallback? handleEsc;
  final VoidCallback? handleSpace;
  final VoidCallback? handleLCtrl;
  final VoidCallback? handleRCtrl;
  final VoidCallback? handleEnd;
  final VoidCallback? handleVolumeUp;
  final VoidCallback? handleVolumeDown;

  const EHKeyboardListener({
    Key? key,
    required this.child,
    this.focusNode,
    this.handlePageUp,
    this.handlePageDown,
    this.handleArrowUp,
    this.handleArrowDown,
    this.handleArrowLeft,
    this.handleArrowRight,
    this.handleEsc,
    this.handleSpace,
    this.handleLCtrl,
    this.handleRCtrl,
    this.handleEnd,
    this.handleVolumeUp,
    this.handleVolumeDown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.pageUp && handlePageUp != null) {
          handlePageUp?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.pageDown && handlePageDown != null) {
          handlePageDown?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && handleArrowUp != null) {
          handleArrowUp?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && handleArrowDown != null) {
          handleArrowDown?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && handleArrowLeft != null) {
          handleArrowLeft?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && handleArrowRight != null) {
          handleArrowRight?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape && handleEsc != null) {
          handleEsc?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.space && handleSpace != null) {
          handleSpace?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.controlLeft && handleLCtrl != null) {
          handleLCtrl?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.controlRight && handleRCtrl != null) {
          handleRCtrl?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.end && handleEnd != null) {
          handleEnd?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp && handleVolumeUp != null) {
          handleVolumeUp?.call();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown && handleVolumeDown != null) {
          handleVolumeDown?.call();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
