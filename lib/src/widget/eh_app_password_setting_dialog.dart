import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';

import '../config/ui_config.dart';

class EHAppPasswordSettingDialog extends StatefulWidget {
  const EHAppPasswordSettingDialog({Key? key}) : super(key: key);

  @override
  State<EHAppPasswordSettingDialog> createState() => _EHAppPasswordSettingDialogState();
}

class _EHAppPasswordSettingDialogState extends State<EHAppPasswordSettingDialog> {
  String? firstPassword;
  late String hintText;

  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    hintText = 'setPasswordHint'.tr;
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      children: [
        SizedBox(
          height: UIConfig.authDialogPinHeight,
          width: UIConfig.authDialogPinWidth,
          child: Pinput(
            length: 4,
            controller: controller,
            pinAnimationType: PinAnimationType.fade,
            obscureText: true,
            autofocus: true,
            preFilledWidget: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: UIConfig.authDialogPinCodeRegionWidth,
                  height: UIConfig.authDialogCursorHeight,
                  color: UIConfig.lockPageFilledDashColor(context),
                )
              ],
            ),
            cursor: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: UIConfig.authDialogPinCodeRegionWidth,
                  height: UIConfig.authDialogCursorHeight,
                  color: UIConfig.lockPageUnfilledDashColor(context),
                )
              ],
            ),
            defaultPinTheme: const PinTheme(
              width: UIConfig.authDialogPinCodeRegionWidth,
              height: UIConfig.authDialogPinCodeRegionWidth,
              textStyle: TextStyle(fontSize: 24),
            ),
            onCompleted: (String value) {
              if (firstPassword == null) {
                setState(() {
                  firstPassword = value;
                  hintText = 'confirmPasswordHint'.tr;
                  controller.clear();
                });
              } else {
                if (firstPassword == value) {
                  Get.back(result: value);
                } else {
                  setState(() {
                    firstPassword = null;
                    hintText = 'passwordNotMatchHint'.tr;
                    controller.clear();
                  });
                }
              }
            },
            closeKeyboardWhenCompleted: false,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(bottom: 4),
          alignment: Alignment.center,
          child: Text(hintText),
        ),
      ],
    );
  }
}
