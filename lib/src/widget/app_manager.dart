import 'dart:ui';

import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';

import '../config/theme_config.dart';
import '../config/ui_config.dart';
import '../main.dart' show disposeAllBeans;
import '../routes/routes.dart';
import '../setting/security_setting.dart';
import '../setting/style_setting.dart';
import '../service/log.dart';
import '../utils/route_util.dart';

typedef DidChangePlatformBrightnessCallback = void Function();
typedef DidChangeAppLifecycleStateCallback = void Function(AppLifecycleState state);
typedef DidHaveMemoryPressureCallback = void Function();
typedef AppLaunchCallback = void Function(BuildContext context);

class AppManager extends StatefulWidget {
  static final List<DidChangePlatformBrightnessCallback> _didChangePlatformBrightnessCallbacks = [];
  static final List<DidChangeAppLifecycleStateCallback> _didChangeAppLifecycleStateCallbacks = [];
  static final List<DidHaveMemoryPressureCallback> _didHaveMemoryPressureCallbacks = [];

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

  static void registerDidHaveMemoryPressureCallback(DidHaveMemoryPressureCallback callback) {
    _didHaveMemoryPressureCallbacks.add(callback);
  }

  static void unRegisterDidHaveMemoryPressureCallback(DidHaveMemoryPressureCallback callback) {
    _didHaveMemoryPressureCallbacks.remove(callback);
  }

  static void registerAppLaunchCallback(AppLaunchCallback callback) {
    _appLaunchCallbacks.add(callback);
  }

  static void unRegisterAppLaunchCallback(AppLaunchCallback callback) {
    _appLaunchCallbacks.remove(callback);
  }
}

class _AppManagerState extends State<AppManager> with WidgetsBindingObserver {
  late final AppLifecycleListener _listener;
  DateTime? lastInactiveTime;
  bool inBlur = false;

  late AppLifecycleState _currentState;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _listener = AppLifecycleListener(
      onInactive: _onInactive,
      onResume: _onResume,
      onStateChange: (AppLifecycleState state) => _currentState = state,
    );

    AppManager.registerAppLaunchCallback(_addSecureFlagForAndroid);
    AppManager.registerDidChangePlatformBrightnessCallback(_changeTheme);
    AppManager.registerDidHaveMemoryPressureCallback(_logMemoryPressure);

    for (var callback in AppManager._appLaunchCallbacks) {
      callback.call(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listener.dispose();
    AppManager.unRegisterAppLaunchCallback(_addSecureFlagForAndroid);
    AppManager.unRegisterDidChangePlatformBrightnessCallback(_changeTheme);
    AppManager.unRegisterDidHaveMemoryPressureCallback(_logMemoryPressure);
    // Dispose all beans when app is terminated
    disposeAllBeans();
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
  void didHaveMemoryPressure() {
    if (_currentState == AppLifecycleState.resumed) {
      for (DidHaveMemoryPressureCallback callback in AppManager._didHaveMemoryPressureCallbacks) {
        callback.call();
      }
    }
    super.didHaveMemoryPressure();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.scrollBehaviourWithScrollBar,
      child: inBlur
          ? Blur(
              blur: 100,
              blurColor: GetPlatform.isAndroid ? Colors.white : Colors.grey.shade600,
              colorOpacity: 1,
              child: widget.child,
            )
          : widget.child,
    );
  }

  void _changeTheme() {
    if (styleSetting.themeMode.value != ThemeMode.system) {
      return;
    }
    if (PlatformDispatcher.instance.platformBrightness == Brightness.light) {
      Get.rootController.theme = ThemeConfig.theme(styleSetting.lightThemeColor.value, Brightness.light);
    } else {
      Get.rootController.darkTheme = ThemeConfig.theme(styleSetting.darkThemeColor.value, Brightness.dark);
    }

    Get.rootController.updateSafely();
  }

  void _logMemoryPressure() {
    log.warning('Memory pressure');
  }

  void _onInactive() {
    log.debug('App is hidden');

    if (securitySetting.enableAuthOnResume.isTrue) {
      lastInactiveTime ??= DateTime.now();
    }

    if ((securitySetting.enableAuthOnResume.isTrue || securitySetting.enableBlur.isTrue) && !inBlur && !isRouteAtTop(Routes.lock)) {
      setState(() => inBlur = true);
    }
  }

  void _onResume() {
    log.debug('App is shown');

    if (!inBlur) {
      return;
    }

    if (securitySetting.enableBlur.isFalse) {
      return;
    }

    if (securitySetting.enableAuthOnResume.isFalse) {
      setState(() => inBlur = false);
      return;
    }

    if ((securitySetting.enablePasswordAuth.isTrue || securitySetting.enableBiometricAuth.isTrue) &&
        DateTime.now().difference(lastInactiveTime!).inSeconds >= 3) {
      toRoute(Routes.lock);
      Future.delayed(const Duration(milliseconds: 300), () => setState(() => inBlur = false));
      lastInactiveTime = null;
    } else {
      setState(() => inBlur = false);
      return;
    }
  }

  /// for Android, blur is invalid when switch app to background(app is still clearly visible in switcher),
  /// so i choose to set FLAG_SECURE to do the same effect.
  void _addSecureFlagForAndroid(BuildContext context) {
    if (GetPlatform.isAndroid && (securitySetting.enableAuthOnResume.isTrue || securitySetting.enableBlur.isTrue)) {
      FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
  }
}
