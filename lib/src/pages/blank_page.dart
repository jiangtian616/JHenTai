import 'package:flutter/material.dart';
import 'package:jhentai/src/setting/style_setting.dart';

class BlankPage extends StatelessWidget {
  const BlankPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StyleSetting.layoutMode.value == LayoutMode.desktop ? Theme.of(context).appBarTheme.backgroundColor! : Theme.of(context).backgroundColor,
      child: Center(
        child: Text(
          'J',
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 120,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
