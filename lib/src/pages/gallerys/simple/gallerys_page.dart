import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_state.dart';
import '../../base/base_page.dart';

/// For desktop layout
class GallerysPage extends BasePage {
  const GallerysPage({Key? key}) : super(key: key, showFilterButton: true);

  @override
  GallerysPageLogic get logic => Get.find<GallerysPageLogic>();

  @override
  GallerysPageState get state => Get.find<GallerysPageLogic>().state;
}
