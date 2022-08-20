import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/toast_util.dart';

class WillPopInterceptor extends StatefulWidget {
  final Widget child;

  const WillPopInterceptor({Key? key, required this.child}) : super(key: key);

  @override
  State<WillPopInterceptor> createState() => _WillPopInterceptorState();
}

class _WillPopInterceptorState extends State<WillPopInterceptor> {
  DateTime? _lastPopTime;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(child: widget.child, onWillPop: _handlePopApp);
  }

  /// double tap back button to exit app
  Future<bool> _handlePopApp() {
    if (_lastPopTime == null) {
      _lastPopTime = DateTime.now();
      toast('TapAgainToExit'.tr, isCenter: false);
      return Future.value(false);
    }

    if (DateTime.now().difference(_lastPopTime!).inMilliseconds <= 800) {
      return Future.value(true);
    }

    _lastPopTime = DateTime.now();
    toast('TapAgainToExit'.tr, isCenter: false);
    return Future.value(false);
  }
}
