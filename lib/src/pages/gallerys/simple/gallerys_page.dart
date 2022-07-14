import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_state.dart';
import '../../base/base_page.dart';
import 'gallerys_page_state.dart';

class GallerysPage extends BasePage {
  const GallerysPage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState() => GallerysPageFlutterState();
}

class GallerysPageFlutterState extends BasePageFlutterState {
  @override
  final GallerysPageLogic logic = Get.put(GallerysPageLogic(), permanent: true);
  @override
  final GallerysPageState state = Get.find<GallerysPageLogic>().state;

  @override
  bool get showFilterButton => true;
}
