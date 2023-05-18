import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/security_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:jhentai/src/widget/window_widget.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';
import 'package:local_auth_windows/local_auth_windows.dart';
import 'package:pinput/pinput.dart';

import '../config/ui_config.dart';

class LockPage extends StatefulWidget {
  const LockPage({Key? key}) : super(key: key);

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  String hintText = 'localizedReason'.tr;

  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    if (SecuritySetting.enableBiometricAuth.isTrue) {
      SchedulerBinding.instance.addPostFrameCallback((_) => biometricAuth());
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WindowWidget(
      child: Material(
        child: ColoredBox(
          color: UIConfig.backGroundColor(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (SecuritySetting.enablePasswordAuth.isTrue)
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
                    if (keyToMd5(value) != SecuritySetting.encryptedPassword.value) {
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
              if (SecuritySetting.enableBiometricAuth.isTrue) IconButton(onPressed: biometricAuth, icon: const Icon(Icons.fingerprint, size: 40)).marginOnly(top: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> biometricAuth() async {
    bool success = await LocalAuthentication().authenticate(
      localizedReason: ' ',
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
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
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
