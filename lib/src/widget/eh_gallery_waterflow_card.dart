import 'dart:collection';
import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../config/ui_config.dart';
import '../consts/locale_consts.dart';
import '../model/gallery.dart';
import '../model/gallery_tag.dart';
import 'eh_gallery_category_tag.dart';
import 'eh_gallery_list_card_.dart';
import 'eh_image.dart';

class EHGalleryWaterFlowCard extends StatelessWidget {
  final Gallery gallery;
  final bool downloaded;
  final ListMode listMode;
  final CardCallback handleTapCard;
  final CardCallback? handleLongPressCard;
  final CardCallback? handleSecondaryTapCard;

  const EHGalleryWaterFlowCard({
    Key? key,
    required this.gallery,
    required this.downloaded,
    required this.listMode,
    required this.handleTapCard,
    this.handleLongPressCard,
    this.handleSecondaryTapCard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => handleTapCard(gallery),
        onLongPress: handleLongPressCard == null ? null : () => handleLongPressCard!(gallery),
        onSecondaryTap: handleSecondaryTapCard == null ? null : () => handleSecondaryTapCard!(gallery),
        child: FadeIn(child: _buildCard(context)),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    Widget child = Card(
      child: listMode == ListMode.waterfallFlowSmall
          ? _buildSmallCard(context)
          : listMode == ListMode.waterfallFlowMedium
              ? _buildMediumCard(context)
              : _buildBigCard(context),
    );

    if (gallery.blockedByLocalRules) {
      child = Blur(
        blur: 8,
        blurColor: UIConfig.backGroundColor(context),
        colorOpacity: 0.7,
        child: child,
        overlay: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_outlined, size: UIConfig.galleryCardFilteredIconSize, color: UIConfig.onBackGroundColor(context)),
            Text('filtered'.tr, style: TextStyle(color: UIConfig.onBackGroundColor(context))),
          ],
        ),
      );
    }

    return child;
  }

  Widget _buildSmallCard(BuildContext context) {
    return Stack(
      children: [
        _buildCover(context),
        Positioned(bottom: 4, right: 4, child: _buildLanguageChip()),
      ],
    );
  }

  Widget _buildMediumCard(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            _buildCover(context),
            Positioned(bottom: 4, right: 4, child: _buildLanguageChip()),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRatingBar(context),
                const Expanded(child: SizedBox()),
                if (downloaded) _buildDownloadIcon().marginOnly(right: 2),
                if (gallery.isFavorite) _buildFavoriteIcon().marginOnly(right: 2),
                if (gallery.pageCount != null) _buildPageCount(),
              ],
            ),
          ],
        ).paddingOnly(top: 2, bottom: 2, left: 6, right: 6),
      ],
    );
  }

  Widget _buildBigCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCover(context),
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRatingBar(context),
                const Expanded(child: SizedBox()),
                if (downloaded) _buildDownloadIcon(),
                if (gallery.isFavorite) _buildFavoriteIcon().marginOnly(left: 2),
                _buildCategory().marginOnly(left: 4, right: 4),
                if (gallery.language != null) _buildLanguage().marginOnly(right: 2),
                if (gallery.pageCount != null) _buildPageCount(),
              ],
            ),
            _buildTitle().marginOnly(top: 4, left: 2),
            if (gallery.tags.isNotEmpty) _buildTags().marginOnly(top: 4),
          ],
        ).paddingOnly(bottom: 6, left: 6, right: 6)
      ],
    );
  }

  Widget _buildCover(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        FittedSizes fittedSizes = applyBoxFit(
          BoxFit.fitWidth,
          Size(gallery.cover.width ?? 150.0, gallery.cover.height ?? 200.0),
          Size(
            constraints.maxWidth,
            min(
              constraints.maxHeight,
              listMode == ListMode.waterfallFlowBig ? UIConfig.waterFallFlowCardMaxHeightBig : UIConfig.waterFallFlowCardMaxHeightSmall,
            ),
          ),
        );

        return EHImage(
          galleryImage: gallery.cover,
          clearMemoryCacheWhenDispose: false,
          containerHeight: fittedSizes.destination.height,
          containerWidth: fittedSizes.destination.width,
          containerColor: UIConfig.waterFallFlowCardBackGroundColor(context),
          heroTag: gallery.blockedByLocalRules ? null : gallery.cover,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(listMode == ListMode.waterfallFlowBig ? 12 : 8),
            topRight: Radius.circular(listMode == ListMode.waterfallFlowBig ? 12 : 8),
            bottomLeft: Radius.circular(listMode == ListMode.waterfallFlowBig || listMode == ListMode.waterfallFlowMedium ? 0 : 8),
            bottomRight: Radius.circular(listMode == ListMode.waterfallFlowBig || listMode == ListMode.waterfallFlowMedium ? 0 : 8),
          ),
        );
      },
    );
  }

  Widget _buildLanguageChip() {
    return Container(
      decoration: BoxDecoration(color: UIConfig.galleryCategoryColor[gallery.category]!, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 12),
      child: Center(
        child: Text(
          LocaleConsts.language2Abbreviation[gallery.language] ?? '',
          style: TextStyle(fontSize: 9, color: UIConfig.waterFallFlowCardLanguageChipTextColor(UIConfig.galleryCategoryColor[gallery.category]!)),
        ),
      ),
    );
  }

  Widget _buildDownloadIcon() => const Icon(Icons.download, size: 10);

  Widget _buildFavoriteIcon() => Icon(Icons.favorite, size: 10, color: UIConfig.favoriteTagColor[gallery.favoriteTagIndex!]);

  Widget _buildPageCount() => Text(gallery.pageCount.toString() + 'P', style: const TextStyle(fontSize: 9));

  Widget _buildLanguage() => Text(LocaleConsts.language2Abbreviation[gallery.language] ?? '', style: const TextStyle(fontSize: 9));

  Widget _buildRatingBar(BuildContext context) {
    return RatingBar.builder(
      unratedColor: UIConfig.galleryRatingStarUnRatedColor(context),
      initialRating: gallery.rating,
      itemCount: 5,
      allowHalfRating: true,
      itemSize: 11,
      ignoreGestures: true,
      itemBuilder: (context, _) => Icon(Icons.star, color: gallery.hasRated ? UIConfig.galleryRatingStarRatedColor(context) : UIConfig.galleryRatingStarColor),
      onRatingUpdate: (_) {},
    );
  }

  Widget _buildCategory() {
    return EHGalleryCategoryTag(
      category: gallery.category,
      textStyle: const TextStyle(fontSize: 8, color: UIConfig.galleryCategoryTagTextColor),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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

  Widget _buildTags() {
    return WaterFallFlowCardTagWaterFlow(tags: gallery.tags);
  }
}

class WaterFallFlowCardTagWaterFlow extends StatelessWidget {
  final LinkedHashMap<String, List<GalleryTag>> tags;

  const WaterFallFlowCardTagWaterFlow({Key? key, required this.tags}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<GalleryTag> mergedList = [];
    tags.forEach((_, galleryTags) {
      mergedList.addAll(galleryTags);
    });

    return LayoutBuilder(builder: (_, constraints) {
      int computeRows = _computeRows(mergedList, constraints.maxWidth);
      return SizedBox(
        height: UIConfig.waterFallFlowCardTagsMaxHeight * computeRows,
        child: WaterfallFlow.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
            crossAxisCount: computeRows,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: mergedList.length,
          itemBuilder: (_, int index) => WaterFallFlowTag(galleryTag: mergedList[index]),
        ).enableMouseDrag(withScrollBar: false),
      );
    });
  }

  int _computeRows(List<GalleryTag> mergedList, double maxWidth) {
    return min((mergedList.length / (maxWidth / 32)).ceil(), 3);
  }
}

class WaterFallFlowTag extends StatelessWidget {
  const WaterFallFlowTag({Key? key, required this.galleryTag}) : super(key: key);

  final GalleryTag galleryTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: galleryTag.backgroundColor ?? UIConfig.ehTagBackGroundColor(context),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        galleryTag.tagData.tagName ?? galleryTag.tagData.key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: UIConfig.waterFallFlowCardTagTextSize,
          height: 1,
          color: galleryTag.color ?? UIConfig.ehTagTextColor(context),
        ),
      ),
    );
  }
}
