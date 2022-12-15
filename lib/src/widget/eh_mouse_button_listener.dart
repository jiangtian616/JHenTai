import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class EHMouseButtonListener extends StatelessWidget {
  final Widget child;
  final HitTestBehavior? behavior;
  final GestureTapDownCallback? onForthButtonTapDown;
  final GestureTapDownCallback? onFifthButtonTapDown;

  const EHMouseButtonListener({
    Key? key,
    required this.child,
    this.behavior,
    this.onForthButtonTapDown,
    this.onFifthButtonTapDown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    final DeviceGestureSettings? gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;

    if (onForthButtonTapDown != null || onFifthButtonTapDown != null) {
      gestures[ForthAndFifthButtonTapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<ForthAndFifthButtonTapGestureRecognizer>(
        () => ForthAndFifthButtonTapGestureRecognizer(),
        (ForthAndFifthButtonTapGestureRecognizer instance) {
          instance
            ..onForthTapDown = onForthButtonTapDown
            ..onFifthTapDown = onFifthButtonTapDown
            ..gestureSettings = gestureSettings;
        },
      );
    }

    return RawGestureDetector(
      gestures: gestures,
      behavior: behavior,
      child: child,
    );
  }
}

class ForthAndFifthButtonTapGestureRecognizer extends BaseTapGestureRecognizer {
  GestureTapDownCallback? onForthTapDown;

  GestureTapUpCallback? onForthTapUp;

  GestureTapCancelCallback? onForthTapCancel;

  GestureTapDownCallback? onFifthTapDown;

  GestureTapUpCallback? onFifthTapUp;

  GestureTapCancelCallback? onFifthTapCancel;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    switch (event.buttons) {
      case kForwardMouseButton:
        if (onForthTapDown == null && onForthTapUp == null && onForthTapCancel == null) {
          return false;
        }
        break;
      case kBackMouseButton:
        if (onFifthTapDown == null && onFifthTapUp == null && onFifthTapCancel == null) {
          return false;
        }
        break;
      default:
        return false;
    }
    return super.isPointerAllowed(event);
  }

  @override
  void handleTapCancel({required PointerDownEvent down, PointerCancelEvent? cancel, required String reason}) {
    final String note = reason == '' ? reason : '$reason ';
    switch (down.buttons) {
      case kForwardMouseButton:
        if (onForthTapCancel != null) {
          invokeCallback<void>('${note}onForthTapCancel', onForthTapCancel!);
        }
        break;
      case kBackMouseButton:
        if (onFifthTapCancel != null) {
          invokeCallback<void>('${note}onFifthTapCancel', onFifthTapCancel!);
        }
        break;
      default:
    }
  }

  @override
  void handleTapDown({required PointerDownEvent down}) {
    final TapDownDetails details = TapDownDetails(
      globalPosition: down.position,
      localPosition: down.localPosition,
      kind: getKindForPointer(down.pointer),
    );
    switch (down.buttons) {
      case kForwardMouseButton:
        if (onForthTapDown != null) {
          invokeCallback<void>('onForthTapDown', () => onForthTapDown!(details));
        }
        break;
      case kBackMouseButton:
        if (onFifthTapDown != null) {
          invokeCallback<void>('onFifthTapDown', () => onFifthTapDown!(details));
        }
        break;
      default:
    }
  }

  @override
  void handleTapUp({required PointerDownEvent down, required PointerUpEvent up}) {
    final TapUpDetails details = TapUpDetails(
      kind: up.kind,
      globalPosition: up.position,
      localPosition: up.localPosition,
    );
    switch (down.buttons) {
      case kForwardMouseButton:
        if (onForthTapUp != null) {
          invokeCallback<void>('onForthTapUp', () => onForthTapUp!(details));
        }
        break;
      case kBackMouseButton:
        if (onFifthTapUp != null) {
          invokeCallback<void>('onFifthTapUp', () => onFifthTapUp!(details));
        }
        break;
      default:
    }
  }
}
