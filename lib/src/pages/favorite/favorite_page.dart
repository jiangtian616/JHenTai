import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../base/base_page.dart';
import 'favorite_page_logic.dart';
import 'favorite_page_state.dart';

class FavoritePage extends BasePage {
  const FavoritePage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
    String? name,
  }) : super(
    key: key,
    showMenuButton: showMenuButton,
    showTitle: showTitle,
    name: name,
  );

  @override
  FavoritePageLogic get logic => Get.find<FavoritePageLogic>();

  @override
  FavoritePageState get state => Get.find<FavoritePageLogic>().state;
}
