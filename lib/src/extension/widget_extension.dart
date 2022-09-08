import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

extension WidgetExtension on Widget {
  Widget center([Key? key]) {
    return Center(key: key, child: this);
  }

  Widget fadeIn([Key? key]) {
    return FadeIn(key: key, child: this);
  }

  Widget fadeOut([Key? key]) {
    return FadeOut(key: key, child: this, animate: true);
  }
}
