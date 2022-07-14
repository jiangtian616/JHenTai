import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../base/base_page.dart';
import 'history_page_logic.dart';
import 'history_page_state.dart';

class HistoryPage extends BasePage {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState() => HistoryPageFlutterState();
}

class HistoryPageFlutterState extends BasePageFlutterState {
  @override
  final HistoryPageLogic logic = Get.put(HistoryPageLogic(), permanent: true);
  @override
  final HistoryPageState state = Get.find<HistoryPageLogic>().state;

  @override
  bool get showJumpButton => false;
}
