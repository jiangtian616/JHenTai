import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';

/// 自定义的 GestureDetector，自动应用配置的长按时间
/// 注意：右键点击功能暂时不支持自定义长按时间
class EHGestureDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final HitTestBehavior? behavior;

  const EHGestureDetector({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    this.behavior,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd: onLongPressEnd,
      behavior: behavior,
      child: child,
    );
  }
}
