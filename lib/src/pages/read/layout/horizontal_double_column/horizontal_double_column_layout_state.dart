import 'dart:async';

import 'package:flutter/cupertino.dart';

class HorizontalDoubleColumnLayoutState {
  late PageController pageController;

  late int pageCount;
  
  late List<bool> isSpreadPage;
  Completer<void> isSpreadPageCompleter = Completer();
}
