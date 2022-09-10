import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_state.dart';
import '../../base/base_page.dart';

/// For desktop layout
class GallerysPage extends BasePage {
  const GallerysPage({Key? key}) : super(key: key, showFilterButton: true, showScroll2TopButton: true);

  @override
  GallerysPageLogic get logic => Get.put<GallerysPageLogic>(GallerysPageLogic(), permanent: true);

  @override
  GallerysPageState get state => Get.find<GallerysPageLogic>().state;
}
