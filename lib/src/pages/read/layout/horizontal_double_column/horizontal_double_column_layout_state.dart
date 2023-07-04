import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/setting/read_setting.dart';

class HorizontalDoubleColumnLayoutState {
  late PageController pageController;
  
  bool displayFirstPageAlone = ReadSetting.displayFirstPageAlone.value;

  late int pageCount;
  late List<bool> isSpreadPage;
}
