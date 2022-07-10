import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/pages/gallerys/base/page_logic_base.dart';
import 'package:jhentai/src/pages/gallerys/base/page_state_base.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_logic.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page_state.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../../config/global_config.dart';
import '../../../widget/eh_gallery_collection.dart';
import '../../../widget/loading_state_indicator.dart';
import '../base/page_base.dart';
import 'gallerys_page_state.dart';

class GallerysPage extends PageBase {
  const GallerysPage({Key? key}) : super(key: key);

  @override
  State<PageBase> createState() => GallerysPageFlutterState();
}

class GallerysPageFlutterState extends PageBaseState {
  @override
  final GallerysPageLogic logic = Get.put(GallerysPageLogic());
  @override
  final GallerysPageState state = Get.find<GallerysPageLogic>().state;
}
