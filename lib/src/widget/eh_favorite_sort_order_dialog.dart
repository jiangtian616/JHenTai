import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../model/gallery_page.dart';
import '../utils/route_util.dart';

class EHFavoriteSortOrderDialog extends StatefulWidget {
  final FavoriteSortOrder? init;

  const EHFavoriteSortOrderDialog({super.key, this.init});

  @override
  State<EHFavoriteSortOrderDialog> createState() => _EHFavoriteSortOrderDialogState();
}

class _EHFavoriteSortOrderDialogState extends State<EHFavoriteSortOrderDialog> {
  FavoriteSortOrder? _sortOrder;

  @override
  void initState() {
    super.initState();
    _sortOrder = widget.init;
  }

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassDialog(
        settings: UIConfig.glassDialogSettings(context),
        title: 'orderBy'.tr,
        content: RadioGroup<FavoriteSortOrder>(
          groupValue: _sortOrder,
          onChanged: (value) => setState(() => _sortOrder = value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile(
                title: Text('favoritedTime'.tr),
                value: FavoriteSortOrder.favoritedTime,
              ),
              RadioListTile(
                title: Text('publishedTime'.tr),
                value: FavoriteSortOrder.publishedTime,
              ),
            ],
          ),
        ),
        actions: [
          GlassDialogAction(label: 'cancel'.tr, onPressed: backRoute),
          GlassDialogAction(
            label: 'OK'.tr,
            onPressed: () => backRoute(result: _sortOrder),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text('orderBy'.tr),
      content: RadioGroup<FavoriteSortOrder>(
        groupValue: _sortOrder,
        onChanged: (value) => setState(() => _sortOrder = value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: Text('favoritedTime'.tr),
              value: FavoriteSortOrder.favoritedTime,
            ),
            RadioListTile(
              title: Text('publishedTime'.tr),
              value: FavoriteSortOrder.publishedTime,
            ),
          ],
        ),
      ),
      actions: [
        EHAppleTextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        EHAppleTextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: _sortOrder)),
      ],
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }
}
