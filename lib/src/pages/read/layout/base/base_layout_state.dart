import 'package:flutter/cupertino.dart';
import 'package:photo_view/photo_view.dart';

class BaseLayoutState {
  Alignment scalePosition = Alignment.center;
  final PhotoViewController photoViewController = PhotoViewController();
  final PhotoViewScaleStateController photoViewScaleStateController = PhotoViewScaleStateController();
}
