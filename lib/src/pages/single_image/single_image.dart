import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import 'package:jhentai/src/widget/eh_keyboard_listener.dart';
import 'package:jhentai/src/widget/eh_mouse_button_listener.dart';

import '../../utils/route_util.dart';

class SingleImagePage extends StatelessWidget {
  const SingleImagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHMouseButtonListener(
      onFifthButtonTapDown: (_) => backRoute(currentRoute: Routes.singleImagePage),
      child: EHKeyboardListener(
        handleEsc: () => backRoute(currentRoute: Routes.singleImagePage),
        child: ExtendedImageSlidePage(
          resetPageDuration: const Duration(milliseconds: 200),
          slidePageBackgroundHandler: (Offset offset, Size pageSize) => UIConfig.backGroundColor(context),
          child: EHImage(
            galleryImage: Get.arguments,
            enableSlideOutPage: true,
            heroTag: Get.arguments,
          ),
        ),
      ),
    );
  }
}
