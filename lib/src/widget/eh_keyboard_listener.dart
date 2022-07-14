import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Listen to keydown event on desktop platform
class EHKeyboardListener extends StatelessWidget {
  final Widget child;
  final FocusNode? focusNode;
  final Function? handlePageUp;
  final Function? handlePageDown;
  final Function? handleArrowUp;
  final Function? handleArrowDown;
  final Function? handleArrowLeft;
  final Function? handleArrowRight;
  final Function? handleEsc;
  final Function? handleSpace;
  final Function? handleLCtrl;

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

        if (event.logicalKey == LogicalKeyboardKey.pageUp) {
          handlePageUp?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
          handlePageDown?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          handleArrowUp?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          handleArrowDown?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          handleArrowLeft?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          handleArrowRight?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          handleEsc?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.space) {
          handleSpace?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.controlLeft) {
          handleLCtrl?.call();
        }
        return KeyEventResult.skipRemainingHandlers;
      },
      child: child,
    );
  }
}
