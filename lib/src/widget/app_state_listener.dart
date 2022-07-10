import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';

import '../setting/security_setting.dart';
import '../setting/style_setting.dart';
import '../utils/toast_util.dart';

typedef DidChangePlatformBrightnessCallback = void Function();
typedef DidChangeAppLifecycleStateCallback = void Function(AppLifecycleState state);
typedef AppLaunchCallback = void Function(BuildContext context);

class AppStateListener extends StatefulWidget {
  static final List<DidChangePlatformBrightnessCallback> _didChangePlatformBrightnessCallbacks = [];
  static final List<DidChangeAppLifecycleStateCallback> _didChangeAppLifecycleStateCallbacks = [];
  static final List<AppLaunchCallback> _appLaunchCallbacks = [];

  final Widget child;

  const AppStateListener({Key? key, required this.child}) : super(key: key);

  @override
  State<AppStateListener> createState() => _AppStateListenerState();

  static void registerDidChangePlatformBrightnessCallback(DidChangePlatformBrightnessCallback callback) {
    _didChangePlatformBrightnessCallbacks.add(callback);
  }

  static void unRegisterDidChangePlatformBrightnessCallback(DidChangePlatformBrightnessCallback callback) {
    _didChangePlatformBrightnessCallbacks.remove(callback);
  }

  static void registerDidChangeAppLifecycleStateCallback(DidChangeAppLifecycleStateCallback callback) {
    _didChangeAppLifecycleStateCallbacks.add(callback);
  }

  static void unRegisterDidChangeAppLifecycleStateCallback(DidChangeAppLifecycleStateCallback callback) {
    _didChangeAppLifecycleStateCallbacks.remove(callback);
  }

  static void registerAppLaunchCallback(AppLaunchCallback callback) {
    _appLaunchCallbacks.add(callback);
  }

  static void unRegisterAppLaunchCallback(AppLaunchCallback callback) {
    _appLaunchCallbacks.remove(callback);
  }
}

class _AppStateListenerState extends State<AppStateListener> with WidgetsBindingObserver {
  AppLifecycleState _state = AppLifecycleState.resumed;

  DateTime? _lastPopTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    AppStateListener.registerDidChangePlatformBrightnessCallback(_changeTheme);
    AppStateListener.registerDidChangeAppLifecycleStateCallback(_blurAppPage);
    AppStateListener.registerAppLaunchCallback(_addSecureFlagForAndroid);

    AppStateListener._appLaunchCallbacks.forEach((callback) => callback.call(context));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    for (DidChangePlatformBrightnessCallback callback in AppStateListener._didChangePlatformBrightnessCallbacks) {
      callback.call();
    }
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (DidChangeAppLifecycleStateCallback callback in AppStateListener._didChangeAppLifecycleStateCallbacks) {
      callback.call(state);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handlePopApp(),

      /// Use LayoutBuilder to listen to resize of window.
      child: (GetPlatform.isAndroid || _state == AppLifecycleState.resumed) ? widget.child : Blur(blur: 100, child: widget.child),
    );
  }

  /// double tap back button to exit app
  Future<bool> _handlePopApp() {
    if (_lastPopTime == null) {
      _lastPopTime = DateTime.now();
      return Future.value(false);
    }

    if (DateTime.now().difference(_lastPopTime!).inMilliseconds <= 400) {
      return Future.value(true);
    }

    _lastPopTime = DateTime.now();
    toast('TapAgainToExit'.tr, isCenter: false);
    return Future.value(false);
  }

  void _changeTheme() {
    if (StyleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    Get.changeThemeMode(
      WidgetsBinding.instance.window.platformBrightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void _blurAppPage(AppLifecycleState state) {
    if (SecuritySetting.enableBlur.isFalse) {
      return;
    }

    /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
    /// so i choose to set FLAG_SECURE to do the same effect.
    if (GetPlatform.isAndroid) {
      return;
    }

    setState(() {
      _state = state;
    });
  }

  void _addSecureFlagForAndroid(BuildContext context) {
    if (SecuritySetting.enableBlur.isTrue && GetPlatform.isAndroid) {
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }
}
