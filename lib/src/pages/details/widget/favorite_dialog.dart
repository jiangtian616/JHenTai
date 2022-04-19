import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../setting/favorite_setting.dart';
import '../../../utils/route_util.dart';
import '../../home/tab_view/gallerys/gallerys_view_logic.dart';
import '../details_page_logic.dart';
import '../details_page_state.dart';

class FavoriteDialog extends StatelessWidget {
  final GallerysViewLogic gallerysViewLogic = Get.find<GallerysViewLogic>();
  final DetailsPageLogic detailsPageLogic = DetailsPageLogic.current!;
  final DetailsPageState detailsPageState = DetailsPageLogic.current!.state;

  FavoriteDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: Text('chooseFavorite'.tr),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: SizedBox(
        height: 400,
        child: Column(
          children: FavoriteSetting.favoriteTagNames
              .mapIndexed(
                (index, tagName) => ListTile(
                  dense: true,
                  selected: detailsPageState.gallery?.favoriteTagIndex == index,
                  visualDensity: const VisualDensity(vertical: -2, horizontal: -4),
                  leading: Text(tagName),
                  trailing: Text(
                    FavoriteSetting.favoriteCounts[index].toString(),
                    style: Theme.of(context).textTheme.caption?.copyWith(fontSize: 12),
                  ),
                  onTap: () => back(result: index),
                ),
              )
              .toList(),
        ),
      ),
      contentPadding: const EdgeInsets.only(top: 18, left: 12, right: 12),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        TextButton(
          child: Text('cancel'.tr, style: const TextStyle(fontSize: 16)),
          onPressed: () => back(),
        ),
      ],
    );
  }
}
