import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jhentai/src/mixin/scroll_status_listener_state.dart';

mixin ScrollStatusListener {
  ScrollStatusListerState get scrollStatusListerState;

  Timer? timer;

  Widget wrapScrollListener(Widget child) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          timer?.cancel();
          scrollStatusListerState.isScrolling = true;
        }
        if (notification is ScrollEndNotification) {
          timer = Timer(const Duration(milliseconds: 100), () {
            scrollStatusListerState.isScrolling = false;
          });
        }
        return false;
      },
      child: child,
    );
  }
}
