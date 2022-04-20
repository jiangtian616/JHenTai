import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';

import '../setting/security_setting.dart';
import '../setting/style_setting.dart';

typedef DidChangePlatformBrightnessCallback = void Function();
typedef DidChangeAppLifecycleStateCallback = void Function(AppLifecycleState state);
typedef AppLaunchCallback = void Function(BuildContext context);

class AppListener extends StatefulWidget {
  static final List<DidChangePlatformBrightnessCallback> _didChangePlatformBrightnessCallbacks = [];
  static final List<DidChangeAppLifecycleStateCallback> _didChangeAppLifecycleStateCallbacks = [];
  static final List<AppLaunchCallback> _appLaunchCallbacks = [];

  final Widget child;

  const AppListener({Key? key, required this.child}) : super(key: key);

  @override
  State<AppListener> createState() => _AppListenerState();

  static void registerDidChangePlatformBrightnessCallback(DidChangePlatformBrightnessCallback callback) {
    _didChangePlatformBrightnessCallbacks.add(callback);
  }

  static void registerDidChangeAppLifecycleStateCallback(DidChangeAppLifecycleStateCallback callback) {
    _didChangeAppLifecycleStateCallbacks.add(callback);
  }

  static void registerAppLaunchCallback(AppLaunchCallback callback) {
    _appLaunchCallbacks.add(callback);
  }
}

class _AppListenerState extends State<AppListener> with WidgetsBindingObserver {
  AppLifecycleState _state = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    AppListener.registerDidChangePlatformBrightnessCallback(_changeTheme);
    AppListener.registerDidChangeAppLifecycleStateCallback(_blurAppPage);
    AppListener._appLaunchCallbacks.forEach((callback) => callback.call(context));
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    for (DidChangePlatformBrightnessCallback callback in AppListener._didChangePlatformBrightnessCallbacks) {
      callback.call();
    }
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (DidChangeAppLifecycleStateCallback callback in AppListener._didChangeAppLifecycleStateCallbacks) {
      callback.call(state);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    if (GetPlatform.isAndroid || _state == AppLifecycleState.resumed) {
      return widget.child;
    }
    return Blur(blur: 100, child: widget.child);
  }

  void _changeTheme() {
    if (StyleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    Get.changeThemeMode(
      WidgetsBinding.instance?.window.platformBrightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void _blurAppPage(AppLifecycleState state) {
    if (SecuritySetting.enableBlur.isFalse) {
      return;
    }

    /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
    /// so i choose to set FLAG_SECURE to do the same effect.
    if (state == AppLifecycleState.inactive) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        setState(() {
          _state = state;
        });
      }
    }
    if (state == AppLifecycleState.resumed) {
      if (GetPlatform.isAndroid) {
        FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);

        /// resume appbar color
        SystemChrome.setSystemUIOverlayStyle(
            Get.theme.appBarTheme.systemOverlayStyle!.copyWith(systemStatusBarContrastEnforced: true));
      } else {
        setState(() {
          _state = state;
        });
      }
    }
  }
}
