import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    return AlertDialog(
      title: Text('orderBy'.tr),
      content: RadioGroup<FavoriteSortOrder?>(
        groupValue: _sortOrder,
        onChanged: (value) => setState(() => _sortOrder = value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<FavoriteSortOrder?>(
              title: Text('favoritedTime'.tr),
              value: FavoriteSortOrder.favoritedTime,
            ),
            RadioListTile<FavoriteSortOrder?>(
              title: Text('publishedTime'.tr),
              value: FavoriteSortOrder.publishedTime,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        TextButton(child: Text('OK'.tr), onPressed: () => backRoute(result: _sortOrder)),
      ],
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }
}
