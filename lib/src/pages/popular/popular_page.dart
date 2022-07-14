import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/popular/popular_page_logic.dart';
import 'package:jhentai/src/pages/popular/popular_page_state.dart';

import '../base/base_page.dart';

class PopularPage extends BasePage {
  const PopularPage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState() => PopularPageFlutterState();
}

class PopularPageFlutterState extends BasePageFlutterState {
  @override
  final PopularPageLogic logic = Get.put(PopularPageLogic(), permanent: true);
  @override
  final PopularPageState state = Get.find<PopularPageLogic>().state;

  @override
  bool get showJumpButton => false;
}
