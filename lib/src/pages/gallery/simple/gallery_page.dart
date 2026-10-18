import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallery/simple/gallery_page_logic.dart';
import 'package:jhentai/src/pages/gallery/simple/gallery_page_state.dart';
import '../../base/base_page.dart';

/// For desktop layout
class GalleryPage extends BasePage {
  const GalleryPage({Key? key}) : super(key: key, showFilterButton: true, showScroll2TopButton: true);

  @override
  GalleryPageLogic get logic => Get.put<GalleryPageLogic>(GalleryPageLogic(), permanent: true);

  @override
  GalleryPageState get state => Get.find<GalleryPageLogic>().state;
}
