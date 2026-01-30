import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../consts/locale_consts.dart';
import '../utils/date_util.dart';
import 'eh_image.dart';
import 'eh_tag.dart';
import 'eh_gallery_category_tag.dart';
import '../service/read_progress_service.dart';

typedef CardCallback = FutureOr<void> Function(Gallery gallery);

class EHGalleryListCard extends StatelessWidget {
  final Gallery gallery;
  final bool downloaded;
  final ListMode listMode;
  final CardCallback handleTapCard;
  final CardCallback? handleLongPressCard;
  final CardCallback? handleSecondaryTapCard;
  final bool withTags;

  const EHGalleryListCard({
    Key? key,
    required this.gallery,
    required this.downloaded,
    required this.listMode,
    required this.handleTapCard,
    this.withTags = true,
    this.handleLongPressCard,
    this.handleSecondaryTapCard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => handleTapCard(gallery),
      onLongPress: handleLongPressCard == null ? null : () => handleLongPressCard!(gallery),
      onSecondaryTap: handleSecondaryTapCard == null ? null : () => handleSecondaryTapCard!(gallery),
      child: FadeIn(
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          height: withTags ? UIConfig.galleryCardHeight : UIConfig.galleryCardHeightWithoutTags,
          child: listMode == ListMode.flat || listMode == ListMode.flatWithoutTags ? buildFlatGalleryCard(context) : buildRoundGalleryCard(context),
        ),
      ),
    );
  }

  Widget buildRoundGalleryCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UIConfig.backGroundColor(context),
        boxShadow: [
          BoxShadow(
            color: UIConfig.galleryCardShadowColor(context),
            blurRadius: 3,
            offset: const Offset(2, 2),
          )
        ],
        borderRadius: BorderRadius.circular(15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: buildFlatGalleryCard(context),
      ),
    );
  }

  Widget buildFlatGalleryCard(BuildContext context) {
    List<Widget> children = [
      buildGalleryCardCover(context),
      Expanded(
        child: buildGalleryCardInfo(context).paddingOnly(left: 6, right: 10, top: 6, bottom: 5),
      ),
    ];

    if (styleSetting.moveCover2RightSide.isTrue) {
      children = children.reversed.toList();
    }

    Widget child = ColoredBox(
      color: UIConfig.backGroundColor(context),
      child: Row(children: children),
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

  Widget buildGalleryCardCover(BuildContext context) {
    return EHImage(
      galleryImage: gallery.cover,
      containerColor: UIConfig.galleryCardBackGroundColor(context),
      containerHeight: withTags ? UIConfig.galleryCardHeight : UIConfig.galleryCardHeightWithoutTags,
      containerWidth: withTags ? UIConfig.galleryCardCoverWidth : UIConfig.galleryCardCoverWidthWithoutTags,
      heroTag: gallery.blockedByLocalRules ? null : gallery.cover,
      fit: BoxFit.fitWidth,
    );
  }

  Widget buildGalleryCardInfo(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildGalleryCardInfoHeader(context),
        if (withTags && gallery.tags.isNotEmpty) buildGalleryCardTagWaterFlow(context),
        buildGalleryInfoFooter(context),
      ],
    );
  }

  Widget buildGalleryCardInfoHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gallery.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: UIConfig.galleryCardTitleSize, height: 1.2),
        ),
        if (gallery.uploader != null)
          Text(
            gallery.uploader!,
            style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)),
          ).marginOnly(top: 2),
      ],
    );
  }

  Widget buildGalleryCardTagWaterFlow(BuildContext context) {
    List<GalleryTag> mergedList = [];
    gallery.tags.forEach((namespace, galleryTags) {
      mergedList.addAll(galleryTags);
    });
    mergedList.sort((a, b) {
      bool aWatched = a.backgroundColor != null;
      bool bWatched = b.backgroundColor != null;
      if (aWatched && !bWatched) {
        return -1;
      } else if (!aWatched && bWatched) {
        return 1;
      } else {
        return 0;
      }
    });

    return SizedBox(
      height: UIConfig.galleryCardTagsHeight,
      child: WaterfallFlow.builder(
        scrollDirection: Axis.horizontal,

        /// disable keepScrollOffset because we used [PageStorageKey], which leads to a conflict with this WaterfallFlow
        controller: ScrollController(keepScrollOffset: false),
        gridDelegate: const SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: mergedList.length,
        itemBuilder: (_, int index) => EHTag(tag: mergedList[index]),
      ).enableMouseDrag(withScrollBar: false),
    );
  }

  Widget buildGalleryInfoFooter(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EHGalleryCategoryTag(category: gallery.category),
            const Expanded(child: SizedBox()),
            if (gallery.pageCount != null) _buildReadingProgress(context).marginOnly(right: 8),
            if (downloaded) _buildDownloadIcon(context).marginOnly(right: 4),
            if (gallery.isFavorite) _buildFavoriteIcon().marginOnly(right: 4),
            if (gallery.language != null) _buildLanguage(context).marginOnly(right: 4),
            if (gallery.pageCount != null) _buildPageCount(context),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRatingBar(context),
            _buildTime(context),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingBar(BuildContext context) {
    return RatingBar.builder(
      unratedColor: UIConfig.galleryRatingStarUnRatedColor(context),
      initialRating: gallery.rating,
      itemCount: 5,
      allowHalfRating: true,
      itemSize: 16,
      ignoreGestures: true,
      itemBuilder: (context, _) => Icon(
        Icons.star,
        color: gallery.hasRated ? UIConfig.galleryRatingStarRatedColor(context) : UIConfig.galleryRatingStarColor,
      ),
      onRatingUpdate: (rating) {},
    );
  }

  Widget _buildReadingProgress(BuildContext context) {
    return GetBuilder<ReadProgressService>(
      init: Get.find<ReadProgressService>(),
      id: '${ReadProgressService.readProgressUpdateId}::${gallery.gid}',
      builder: (_) {
        return FutureBuilder<int>(
          future: readProgressService.getReadProgress(gallery.gid),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }

            final readIndex = snapshot.data ?? 0;

            double progress = gallery.pageCount != null && gallery.pageCount! > 0 ? ((readIndex + 1) / gallery.pageCount!).clamp(0.0, 1.0) : 0.0;

            // Don't show indicator if no progress
            if (readIndex == 0.0) {
              return const SizedBox.shrink();
            }

            return SizedBox(
              width: UIConfig.galleryCardReadProgressIndicatorSize,
              height: UIConfig.galleryCardReadProgressIndicatorSize,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                backgroundColor: UIConfig.galleryCardTextColor(context).withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(UIConfig.galleryCardTextColor(context)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadIcon(BuildContext context) => Icon(Icons.downloading, size: 11, color: UIConfig.galleryCardTextColor(context));

  Widget _buildFavoriteIcon() => Icon(Icons.favorite, size: 11, color: UIConfig.favoriteTagColor[gallery.favoriteTagIndex!]);

  Text _buildPageCount(BuildContext context) =>
      Text(gallery.pageCount.toString() + 'P', style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)));

  Text _buildLanguage(BuildContext context) {
    return Text(
      LocaleConsts.language2Abbreviation[gallery.language] ?? '',
      style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)),
    );
  }

  Text _buildTime(BuildContext context) {
    return Text(
      preferenceSetting.showUtcTime.isTrue ? gallery.publishTime : DateUtil.transformUtc2LocalTimeString(gallery.publishTime),
      style: TextStyle(
          fontSize: UIConfig.galleryCardTextSize,
          color: UIConfig.galleryCardTextColor(context),
          decoration: gallery.isExpunged ? TextDecoration.lineThrough : null),
    );
  }
}
