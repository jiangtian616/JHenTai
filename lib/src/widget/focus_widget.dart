import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jhentai/src/setting/style_setting.dart';

class FocusWidget extends StatefulWidget {
  final bool enableFocus;
  final Widget child;
  final BoxDecoration? decoration;
  final BoxDecoration? foregroundDecoration;
  final VoidCallback? handleTapEnter;
  final VoidCallback? handleTapArrowLeft;
  final VoidCallback? handleTapArrowRight;

  const FocusWidget({
    Key? key,
    this.enableFocus = true,
    this.decoration,
    this.foregroundDecoration,
    required this.child,
    this.handleTapEnter,
    this.handleTapArrowLeft,
    this.handleTapArrowRight,
  }) : super(key: key);

  @override
  State<FocusWidget> createState() => _FocusWidgetState();
}

class _FocusWidgetState extends State<FocusWidget> {
  bool isFocused = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enableFocus || StyleSetting.actualLayoutMode.value != LayoutMode.desktop) {
      return widget.child;
    }

    return Focus(
      onFocusChange: (v) => setState(() => isFocused = v),
      onKeyEvent: (_, KeyEvent event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter && widget.handleTapEnter != null) {
          widget.handleTapEnter?.call();
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.arrowLeft && widget.handleTapArrowLeft != null) {
          widget.handleTapArrowLeft?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && widget.handleTapArrowRight != null) {
          widget.handleTapArrowRight?.call();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Container(
        foregroundDecoration: widget.foregroundDecoration,
        decoration: isFocused ? widget.decoration : null,
        child: widget.child,
      ),
    );
  }
}
