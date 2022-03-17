import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/widget/eh_image.dart';

class SingleImagePage extends StatelessWidget {
  const SingleImagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    GalleryImage image = Get.arguments as GalleryImage;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: Get.back,
        ),
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        color: Colors.white,
        child: Hero(
          tag: image.url,
          child: EHImage(
            galleryImage: image,
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
