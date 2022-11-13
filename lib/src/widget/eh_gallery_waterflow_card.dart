import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/focus_widget.dart';

import '../config/ui_config.dart';
import '../consts/color_consts.dart';
import '../consts/locale_consts.dart';
import '../model/gallery.dart';
import 'eh_gallery_category_tag.dart';
import 'eh_gallery_list_card_.dart';
import 'eh_image.dart';

class EHGalleryWaterFlowCard extends StatelessWidget {
  final Gallery gallery;
  final ListMode listMode;
  final CardCallback handleTapCard;

  const EHGalleryWaterFlowCard({
    Key? key,
    required this.gallery,
    required this.listMode,
    required this.handleTapCard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FocusWidget(
      focusedDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(width: 3, color: Get.theme.colorScheme.onBackground),
      ),
      handleTapEnter: () => handleTapCard(gallery),
      child: GestureDetector(
        onTap: () => handleTapCard(gallery),
        child: FadeIn(
          child: Card(
            child: _buildGallery(),
          ),
        ),
      ),
    );
  }

  Widget _buildGallery() {
    return Column(
      children: [
        listMode == ListMode.waterfallFlowWithImageAndInfo
            ? _buildCover()
            : Stack(
                children: [
                  _buildCover(),
                  Positioned(child: _buildLanguageChip(), bottom: 4, right: 4),
                ],
              ),
        if (listMode == ListMode.waterfallFlowWithImageAndInfo) _buildInfo(),
      ],
    );
  }

  Widget _buildCover() {
    return LayoutBuilder(
      builder: (_, constraints) {
        FittedSizes fittedSizes = applyBoxFit(
          BoxFit.contain,
          Size(gallery.cover.width, gallery.cover.height),
          Size(constraints.maxWidth, constraints.maxHeight),
        );

        return EHImage.network(
          galleryImage: gallery.cover,
          containerHeight: fittedSizes.destination.height,
          containerWidth: fittedSizes.destination.width,
          containerColor: Get.theme.colorScheme.onPrimaryContainer.withOpacity(0.05),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(listMode == ListMode.waterfallFlowWithImageAndInfo ? 12 : 8),
            topRight: Radius.circular(listMode == ListMode.waterfallFlowWithImageAndInfo ? 12 : 8),
            bottomLeft: Radius.circular(listMode == ListMode.waterfallFlowWithImageAndInfo ? 0 : 8),
            bottomRight: Radius.circular(listMode == ListMode.waterfallFlowWithImageAndInfo ? 0 : 8),
          ),
        );
      },
    );
  }

  Widget _buildLanguageChip() {
    return Container(
      decoration: BoxDecoration(color: ColorConsts.galleryCategoryColor[gallery.category]!, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 12),
      child: Center(
        child: Text(LocaleConsts.language2Abbreviation[gallery.language] ?? '', style: const TextStyle(fontSize: 9, color: Colors.white)),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildRatingBar(),
            const Expanded(child: SizedBox()),
            EHGalleryCategoryTag(
              category: gallery.category,
              textStyle: const TextStyle(height: 1, fontSize: 9, color: Colors.white),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ).marginOnly(right: 4),
            if (gallery.language != null)
              Text(LocaleConsts.language2Abbreviation[gallery.language] ?? '', style: const TextStyle(fontSize: 9)).marginOnly(right: 4),
            if (gallery.pageCount != null) Text(gallery.pageCount.toString() + 'P', style: const TextStyle(fontSize: 9)),
          ],
        ),
        _buildTitle().marginOnly(top: 4, left: 2),
      ],
    ).paddingOnly(top: 6, bottom: 6, left: 6, right: 6);
  }

  Widget _buildRatingBar() {
    return RatingBar.builder(
      unratedColor: Colors.grey.shade300,
      initialRating: gallery.rating,
      itemCount: 5,
      allowHalfRating: true,
      itemSize: 12,
      ignoreGestures: true,
      itemBuilder: (context, _) => Icon(Icons.star, color: gallery.hasRated ? UIConfig.resumeButtonColor : Colors.amber.shade800),
      onRatingUpdate: (_) {},
    );
  }

  Widget _buildTitle() {
    return Text(
      gallery.title.breakWord,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: UIConfig.waterFallFlowCardTitleSize, height: 1.2),
    );
  }
}
