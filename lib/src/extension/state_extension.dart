import 'package:flutter/widgets.dart';

extension StateExtension on State {
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }
}
