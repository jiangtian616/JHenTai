import 'dart:async';

import 'package:flutter/cupertino.dart';

class HorizontalDoubleColumnLayoutState {
  late PageController pageController;

  /// whether current image is zoomed in, swipe to turn page is ignored while zoomed
  bool isZoomed = false;

  late int pageCount;
  
  late List<bool> isSpreadPage;
  Completer<void> isSpreadPageCompleter = Completer();
}
