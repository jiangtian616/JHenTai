import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/mixin/window_widget_mixin.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:pinput/pinput.dart';
import 'package:window_manager/window_manager.dart';

import '../config/ui_config.dart';

class LockPage extends StatefulWidget {
  const LockPage({Key? key}) : super(key: key);

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> with WindowListener, WindowWidgetMixin {
  String hintText = 'localizedReason'.tr;

  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    if (securitySetting.enableBiometricAuth.isTrue) {
      SchedulerBinding.instance.addPostFrameCallback((_) => biometricAuth());
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return buildWindow(
      child: PopScope(
        canPop: false,
        child: Material(
          child: ColoredBox(
            color: UIConfig.backGroundColor(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (securitySetting.enablePasswordAuth.isTrue)
                  Pinput(
                    length: 4,
                    controller: controller,
                    pinAnimationType: PinAnimationType.fade,
                    obscureText: true,
                    preFilledWidget: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: UIConfig.lockPagePinCodeRegionWidth,
                          height: UIConfig.lockPageCursorHeight,
                          color: UIConfig.lockPageFilledDashColor(context),
                        )
                      ],
                    ),
                    cursor: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: UIConfig.lockPagePinCodeRegionWidth,
                          height: UIConfig.lockPageCursorHeight,
                          color: UIConfig.lockPageUnfilledDashColor(context),
                        )
                      ],
                    ),
                    defaultPinTheme: const PinTheme(
                      width: UIConfig.lockPagePinCodeRegionWidth,
                      height: UIConfig.lockPagePinCodeRegionWidth,
                      textStyle: TextStyle(fontSize: 24),
                    ),
                    onCompleted: (String value) {
                      if (keyToMd5(value) != securitySetting.encryptedPassword.value) {
                        setState(() {
                          controller.clear();
                          hintText = 'passwordErrorHint'.tr;
                        });
                        return;
                      }

                      unlock();
                    },
                    closeKeyboardWhenCompleted: false,
                  ),
                Container(
                  padding: const EdgeInsets.only(top: 32),
                  alignment: Alignment.center,
                  child: Text(hintText),
                ),
                if (securitySetting.enableBiometricAuth.isTrue)
                  IconButton(onPressed: biometricAuth, icon: const Icon(Icons.fingerprint, size: 40)).marginOnly(top: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> biometricAuth() async {
    bool success = await LocalAuthentication().authenticate(
      /**
       * @see [local_auth_windows example](https://github.com/flutter/packages/blob/main/packages/local_auth/local_auth_windows/example/lib/main.dart)
       */
      localizedReason: GetPlatform.isWindows ? 'localizedReason'.tr : ' ',
      authMessages: [
        AndroidAuthMessages(
          signInTitle: 'localizedReason'.tr,
          biometricHint: '',
          cancelButton: 'cancel'.tr,
        ),
        IOSAuthMessages(
          localizedFallbackTitle: 'localizedReason'.tr,
          cancelButton: 'cancel'.tr,
        ),
        const WindowsAuthMessages(),
      ],
      options: AuthenticationOptions(
        stickyAuth: true,
        /**
         * @see [local_auth_windows](https://github.com/flutter/packages/blob/733869c981a3d0c649d904febc486b47ddb5f672/packages/local_auth/local_auth_windows/lib/local_auth_windows.dart#L54)
         */
        biometricOnly: !GetPlatform.isWindows,
      ),
    );

    if (!success) {
      return;
    }

    unlock();
  }

  void unlock() {
    /// on launch
    if (isEmptyOrNull(Get.routing.previous)) {
      offRoute(Routes.home);
    }

    /// on resume
    else {
      backRoute();
    }
  }
}
