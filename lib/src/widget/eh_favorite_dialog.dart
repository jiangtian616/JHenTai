import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';

import '../setting/favorite_setting.dart';
import '../utils/route_util.dart';

class EHFavoriteDialog extends StatelessWidget {
  final int? selectedIndex;

  const EHFavoriteDialog({Key? key, this.selectedIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Center(child: Text('chooseFavorite'.tr)),
      children: [
        Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: FavoriteSetting.favoriteTagNames
                .mapIndexed(
                  (index, tagName) => ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    selected: selectedIndex == index,
                    selectedTileColor: GlobalConfig.favoriteDialogTileColor,
                    visualDensity: const VisualDensity(vertical: -2, horizontal: -4),
                    leading: Text(tagName),
                    trailing: Text(
                      FavoriteSetting.favoriteCounts[index].toString(),
                      style: TextStyle(fontSize: GlobalConfig.favoriteDialogCountTextSize, color: GlobalConfig.favoriteDialogCountTextColor),
                    ),
                    onTap: () => backRoute(result: index),
                  ),
                )
                .toList(),
          ),
        ),
        TextButton(child: Text('cancel'.tr), onPressed: backRoute).marginOnly(top: 12),
      ],
      contentPadding: const EdgeInsets.only(top: 18, left: 12, right: 12, bottom: 12),
    );
  }
}
