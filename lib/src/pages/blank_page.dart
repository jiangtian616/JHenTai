import 'package:flutter/material.dart';
import 'package:jhentai/src/config/ui_config.dart';

class BlankPage extends StatelessWidget {
  const BlankPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UIConfig.backGroundColor(context),
      child: Center(
        child: Text(
          'J',
          style: TextStyle(color: UIConfig.jHentaiIconColor(context), fontSize: 120, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
