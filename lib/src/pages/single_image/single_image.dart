import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_keyboard_listener.dart';

import '../../utils/route_util.dart';

class SingleImagePage extends StatelessWidget {
  const SingleImagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHKeyboardListener(
      handleEsc: () => back(currentRoute: Routes.singleImagePage),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => back(currentRoute: Routes.singleImagePage, closeOverlays: true)),
        ),
        body: Container(
          constraints: const BoxConstraints.expand(),
          color: Colors.white,
          child: EHImage.network(
            galleryImage: Get.arguments,
            adaptive: true,
            fit: BoxFit.contain,
            mode: ExtendedImageMode.gesture,
            initGestureConfigHandler: (ExtendedImageState state) {
              return GestureConfig();
            },
          ),
        ),
      ),
    );
  }
}
