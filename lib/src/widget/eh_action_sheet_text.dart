import 'package:flutter/widgets.dart';

/// CupertinoActionSheet 按钮文字。
///
/// Flutter 3.25 起按钮字体由内部动态计算放大（默认缩放下 21pt，不走 [CupertinoTheme]），
/// 这里统一还原为 17pt。
Widget ehActionSheetText(String text, {Color? color}) {
  return Text(text, style: TextStyle(fontSize: 17, color: color));
}
