import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/popular/popular_page_logic.dart';
import 'package:jhentai/src/pages/popular/popular_page_state.dart';

import '../gallerys/base/page_base.dart';
import '../gallerys/base/page_logic_base.dart';
import '../gallerys/base/page_state_base.dart';
import '../gallerys/simple/gallerys_page_logic.dart';
import '../gallerys/simple/gallerys_page_state.dart';

class PopularPage extends PageBase {
  const PopularPage({Key? key}) : super(key: key);

  @override
  State<PageBase> createState() => PopularPageFlutterState();
}

class PopularPageFlutterState extends PageBaseState {
  @override
  final PopularPageLogic logic = Get.put(PopularPageLogic());
  @override
  final PopularPageState state = Get.find<PopularPageLogic>().state;
}
