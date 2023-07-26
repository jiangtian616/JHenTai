import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/setting/preference_setting.dart';

import '../setting/favorite_setting.dart';
import '../utils/route_util.dart';

class EHFavoriteDialog extends StatefulWidget {
  final int? selectedIndex;

  const EHFavoriteDialog({Key? key, this.selectedIndex}) : super(key: key);

  @override
  State<EHFavoriteDialog> createState() => _EHFavoriteDialogState();
}

class _EHFavoriteDialogState extends State<EHFavoriteDialog> {
  bool remember = false;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Center(child: Text('chooseFavorite'.tr)),
      children: [
        Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...FavoriteSetting.favoriteTagNames
                  .mapIndexed(
                    (index, tagName) => ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      selected: widget.selectedIndex == index,
                      selectedTileColor: UIConfig.favoriteDialogTileColor(context),
                      visualDensity: const VisualDensity(vertical: -2, horizontal: -4),
                      leading: Text(
                        tagName,
                        style: const TextStyle(fontSize: UIConfig.favoriteDialogLeadingTextSize),
                      ),
                      trailing: Text(
                        FavoriteSetting.favoriteCounts[index].toString(),
                        style: TextStyle(fontSize: UIConfig.favoriteDialogTrailingTextSize, color: UIConfig.favoriteDialogCountTextColor(context)),
                      ),
                      onTap: () => backRoute(result: (favIndex: index, remember: remember)),
                    ),
                  )
                  .toList(),
              if (PreferenceSetting.enableDefaultFavorite.isTrue)
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  visualDensity: const VisualDensity(vertical: -2, horizontal: -4),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('asYourDefault'.tr), Checkbox(value: remember, onChanged: (value) => setState(() => remember = value!))],
                  ),
                )
            ],
          ),
        ),
        TextButton(child: Text('cancel'.tr), onPressed: backRoute).marginOnly(top: 12),
      ],
      contentPadding: const EdgeInsets.only(top: 18, left: 12, right: 12, bottom: 12),
    );
  }
}
