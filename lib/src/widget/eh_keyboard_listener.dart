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
          if (handlePageUp == null) {
            return KeyEventResult.ignored;
          }
          handlePageUp?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
          if (handlePageDown == null) {
            return KeyEventResult.ignored;
          }
          handlePageDown?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (handleArrowUp == null) {
            return KeyEventResult.ignored;
          }
          handleArrowUp?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (handleArrowDown == null) {
            return KeyEventResult.ignored;
          }
          handleArrowDown?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (handleArrowLeft == null) {
            return KeyEventResult.ignored;
          }
          handleArrowLeft?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (handleArrowRight == null) {
            return KeyEventResult.ignored;
          }
          handleArrowRight?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (handleEsc == null) {
            return KeyEventResult.ignored;
          }
          handleEsc?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.space) {
          if (handleSpace == null) {
            return KeyEventResult.ignored;
          }
          handleSpace?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.controlLeft) {
          if (handleLCtrl == null) {
            return KeyEventResult.ignored;
          }
          handleLCtrl?.call();
        }
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}
