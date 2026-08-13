import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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
          showJumpButton: true,
          showFilterButton: true,
          showScroll2TopButton: true,
          showTitle: showTitle,
          name: name,
        );

  @override
  FavoritePageLogic get logic => Get.put<FavoritePageLogic>(FavoritePageLogic(), permanent: true);

  @override
  FavoritePageState get state => Get.find<FavoritePageLogic>().state;

  @override
  List<Widget> buildAppBarActions() {
    return [
      if (state.galleries.isNotEmpty) EHAppleIconButton(icon: Icon(Icons.send, size: 20), onPressed: logic.handleTapJumpButton),
      if (state.galleries.isNotEmpty) const SizedBox(width: 8),
      if (state.galleries.isNotEmpty)
        ThemeConfig.isApple
            ? EHGlassMenu(
                trigger: EHAppleIconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: () {},
                ),
                items: [
                  for (final order in FavoriteSortOrder.values)
                    GlassMenuItem(
                      title: order.name.tr,
                      isSelected: state.favoriteSortOrder == order,
                      onTap: () => logic.handleChangeSortOrderTo(order),
                    ),
                ],
              )
            : EHAppleIconButton(
                icon: const Icon(Icons.sort),
                onPressed: logic.handleChangeSortOrder,
              ),
      if (state.galleries.isNotEmpty) const SizedBox(width: 8),
      EHAppleIconButton(icon: const Icon(Icons.filter_alt_outlined, size: 28), onPressed: logic.handleTapFilterButton),
    ];
  }
}
