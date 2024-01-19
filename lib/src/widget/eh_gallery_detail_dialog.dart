import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/utils/string_uril.dart';

import '../model/gallery.dart';
import '../utils/toast_util.dart';

class EHGalleryDetailDialog extends StatelessWidget {
  final Gallery gallery;
  final GalleryDetail galleryDetail;

  const EHGalleryDetailDialog({Key? key, required this.gallery, required this.galleryDetail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.scrollBehaviourWithoutScrollBarWithMouse,
      child: SimpleDialog(
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        children: [
          _Item(name: 'gid'.tr, value: gallery.gid.toString()),
          _Item(name: 'token'.tr, value: (gallery.token)),
          _Item(name: ('galleryUrl'.tr), value: (gallery.galleryUrl.url)),
          _Item(name: ('title'.tr), value: (galleryDetail.rawTitle)),
          _Item(name: ('japaneseTitle'.tr), value: (galleryDetail.japaneseTitle)),
          _Item(name: ('category'.tr), value: (gallery.category)),
          _Item(name: ('uploader'.tr), value: (gallery.uploader)),
          _Item(name: ('publishTime'.tr), value: (gallery.publishTime.toString())),
          _Item(name: ('language'.tr), value: (gallery.language)),
          _Item(name: ('pageCount'.tr), value: (gallery.pageCount?.toString())),
          _Item(name: ('favoriteCount'.tr), value: (galleryDetail.favoriteCount.toString())),
          _Item(name: ('ratingCount'.tr), value: (galleryDetail.ratingCount.toString())),
          _Item(name: ('rating'.tr), value: (galleryDetail.realRating.toString())),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String name;
  final String? value;

  const _Item({Key? key, required this.name, this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: UIConfig.galleryDetailDialogItemBorderRadius,
      onTap: () {
        if (!isEmptyOrNull(value)) {
          FlutterClipboard.copy(value!).then((value) => toast('hasCopiedToClipboard'.tr));
        }
      },
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Text(name, style: UIConfig.galleryDetailDialogItemNameTextStyle),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: UIConfig.galleryDetailDialogItemValueMaxWidth),
                    child: Text(value?.breakWord ?? '', style: UIConfig.galleryDetailDialogItemValueTextStyle),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
