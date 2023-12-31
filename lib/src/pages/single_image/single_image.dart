import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/widget/eh_image.dart';

class SingleImagePage extends StatelessWidget {
  const SingleImagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExtendedImageSlidePage(
      resetPageDuration: const Duration(milliseconds: 200),
      slidePageBackgroundHandler: (Offset offset, Size pageSize) => UIConfig.backGroundColor(context),
      child: EHImage(
        galleryImage: Get.arguments,
        enableSlideOutPage: true,
        heroTag: Get.arguments,
      ),
    );
  }
}
