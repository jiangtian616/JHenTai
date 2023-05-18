import 'dart:ui';

import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';

import '../config/theme_config.dart';
import '../config/ui_config.dart';
import '../routes/routes.dart';
import '../setting/security_setting.dart';
import '../setting/style_setting.dart';
import '../utils/log.dart';
import '../utils/route_util.dart';

typedef DidChangePlatformBrightnessCallback = void Function();
typedef DidChangeAppLifecycleStateCallback = void Function(AppLifecycleState state);
typedef AppLaunchCallback = void Function(BuildContext context);

class AppManager extends StatefulWidget {
  static final List<DidChangePlatformBrightnessCallback> _didChangePlatformBrightnessCallbacks = [];
  static final List<DidChangeAppLifecycleStateCallback> _didChangeAppLifecycleStateCallbacks = [];
  static final List<AppLaunchCallback> _appLaunchCallbacks = [];

  final Widget child;

  const AppManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AppManager> createState() => _AppManagerState();

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

class _AppManagerState extends State<AppManager> with WidgetsBindingObserver {
  DateTime? lastInactiveTime;
  bool inBlur = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    AppManager.registerAppLaunchCallback(_addSecureFlagForAndroid);
    AppManager.registerDidChangePlatformBrightnessCallback(_changeTheme);
    AppManager.registerDidChangeAppLifecycleStateCallback(_lockAfterResume);

    for (var callback in AppManager._appLaunchCallbacks) {
      callback.call(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    for (DidChangePlatformBrightnessCallback callback in AppManager._didChangePlatformBrightnessCallbacks) {
      callback.call();
    }
    super.didChangePlatformBrightness();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    for (DidChangeAppLifecycleStateCallback callback in AppManager._didChangeAppLifecycleStateCallbacks) {
      callback.call(state);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.scrollBehaviourWithScrollBar,
      child: inBlur ? Blur(blur: 100, colorOpacity: 1, child: widget.child) : widget.child,
    );
  }

  /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
  /// so i choose to set FLAG_SECURE to do the same effect.
  void _addSecureFlagForAndroid(BuildContext context) {
    if (GetPlatform.isAndroid && (SecuritySetting.enableAuthOnResume.isTrue || SecuritySetting.enableBlur.isTrue)) {
      FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }

  void _changeTheme() {
    if (StyleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    if (PlatformDispatcher.instance.platformBrightness == Brightness.light) {
      Get.rootController.theme = ThemeConfig.generateThemeData(StyleSetting.lightThemeColor.value, Brightness.light);
    } else {
      Get.rootController.darkTheme = ThemeConfig.generateThemeData(StyleSetting.darkThemeColor.value, Brightness.dark);
    }

    Get.rootController.updateSafely();
  }

  void _lockAfterResume(AppLifecycleState state) {
    Log.debug("App state change: -> $state");

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (SecuritySetting.enableAuthOnResume.isTrue) {
        lastInactiveTime ??= DateTime.now();
      }

      if ((SecuritySetting.enableAuthOnResume.isTrue || SecuritySetting.enableBlur.isTrue) && !inBlur && !isRouteAtTop(Routes.lock)) {
        setState(() => inBlur = true);
      }
    }

    if (state == AppLifecycleState.resumed) {
      if (!inBlur) {
        return;
      }

      if (SecuritySetting.enableBlur.isFalse) {
        return;
      }

      if (SecuritySetting.enableAuthOnResume.isFalse) {
        setState(() => inBlur = false);
        return;
      }

      if ((SecuritySetting.enablePasswordAuth.isTrue || SecuritySetting.enableBiometricAuth.isTrue) &&
          DateTime.now().difference(lastInactiveTime!).inSeconds >= 3) {
        toRoute(Routes.lock);
        Future.delayed(const Duration(milliseconds: 300), () => setState(() => inBlur = false));
        lastInactiveTime = null;
      } else {
        setState(() => inBlur = false);
        return;
      }
    }
  }
}
