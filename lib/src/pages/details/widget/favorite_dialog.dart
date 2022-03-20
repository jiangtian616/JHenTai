import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../setting/favorite_setting.dart';
import '../../home/tab_view/gallerys/gallerys_view_logic.dart';
import '../details_page_logic.dart';
import '../details_page_state.dart';

class FavoriteDialog extends StatelessWidget {
  final GallerysViewLogic gallerysViewLogic = Get.find<GallerysViewLogic>();
  final DetailsPageLogic detailsPageLogic = Get.find<DetailsPageLogic>();
  final DetailsPageState detailsPageState = Get.find<DetailsPageLogic>().state;

  FavoriteDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: Text('chooseFavorite'.tr),
      ),
      titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.grey.shade200.withOpacity(0.95),
      content: SizedBox(
        height: 400,
        child: Column(
          children: FavoriteSetting.favoriteTagNames2Count!.entries
              .mapIndexed(
                (index, entry) => ListTile(
                  dense: true,
                  selected: detailsPageState.gallery?.favoriteTagIndex == index,
                  visualDensity: const VisualDensity(vertical: -2, horizontal: -4),
                  leading: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: Text(
                    entry.value.toString(),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  onTap: () => Get.back(result: index),
                ),
              )
              .toList(),
        ),
      ),
      contentPadding: const EdgeInsets.only(top: 18, left: 12, right: 12),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        TextButton(
          child: Text(
            'cancel'.tr,
            style: const TextStyle(fontSize: 16),
          ),
          onPressed: () {
            Get.back();
          },
        ),
      ],
    );
  }
}
