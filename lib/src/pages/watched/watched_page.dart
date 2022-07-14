import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/watched/watched_page_state.dart';

import '../base/base_page.dart';
import 'watched_page_logic.dart';

class WatchedPage extends BasePage {
  const WatchedPage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState() => WatchedPageFlutterState();
}

class WatchedPageFlutterState extends BasePageFlutterState {
  @override
  final WatchedPageLogic logic = Get.put(WatchedPageLogic(), permanent: true);
  @override
  final WatchedPageState state = Get.find<WatchedPageLogic>().state;

  @override
  bool get showFilterButton => true;
}
