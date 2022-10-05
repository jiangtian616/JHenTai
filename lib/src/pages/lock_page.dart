import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:local_auth/auth_strings.dart';
import 'package:local_auth/local_auth.dart';

class LockPage extends StatefulWidget {
  const LockPage({Key? key}) : super(key: key);

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      auth();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: auth,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.background,
        child: Center(
          child: Text('tap2Auth'.tr, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }

  Future<void> auth() async {
    bool success = await LocalAuthentication().authenticate(
      localizedReason: ' ',
      androidAuthStrings: AndroidAuthMessages(
        signInTitle: 'localizedReason'.tr,
        biometricHint: '',
        cancelButton: 'cancel'.tr,
      ),
      iOSAuthStrings: IOSAuthMessages(
        localizedFallbackTitle: 'localizedReason'.tr,
        cancelButton: 'cancel'.tr,
      ),
      stickyAuth: true,
      biometricOnly: true,
    );

    if (!success) {
      return;
    }

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
