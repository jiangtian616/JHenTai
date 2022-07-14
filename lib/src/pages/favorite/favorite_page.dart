import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../base/base_page.dart';
import 'favorite_page_logic.dart';
import 'favorite_page_state.dart';

class FavoritePage extends BasePage {
  const FavoritePage({Key? key}) : super(key: key);

  @override
  State<BasePage> createState() => FavoritePageFlutterState();
}

class FavoritePageFlutterState extends BasePageFlutterState {
  @override
  final FavoritePageLogic logic = Get.put(FavoritePageLogic(), permanent: true);
  @override
  final FavoritePageState state = Get.find<FavoritePageLogic>().state;

  @override
  bool get showFilterButton => true;
}
