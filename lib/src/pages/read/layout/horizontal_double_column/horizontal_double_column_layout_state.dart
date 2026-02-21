import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:photo_view/photo_view.dart';

class HorizontalDoubleColumnLayoutState {
  final PhotoViewController photoViewController = PhotoViewController();
  late PageController pageController;

  late int pageCount;
  
  late List<bool> isSpreadPage;
  Completer<void> isSpreadPageCompleter = Completer();
}
