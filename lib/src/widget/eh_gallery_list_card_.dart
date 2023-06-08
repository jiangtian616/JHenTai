import 'dart:async';
import 'dart:collection';

import 'package:animate_do/animate_do.dart';
import 'package:blur/blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/eh_gallery_favorite_tag.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../consts/color_consts.dart';
import '../consts/locale_consts.dart';
import '../model/gallery_image.dart';
import '../utils/date_util.dart';
import 'eh_image.dart';
import 'eh_tag.dart';
import 'eh_gallery_category_tag.dart';

typedef CardCallback = FutureOr<void> Function(Gallery gallery);

class EHGalleryListCard extends StatelessWidget {
  final Gallery gallery;
  final ListMode listMode;
  final CardCallback handleTapCard;
  final CardCallback? handleLongPressCard;
  final CardCallback? handleSecondaryTapCard;
  final bool withTags;

  const EHGalleryListCard({
    Key? key,
    required this.gallery,
    required this.listMode,
    required this.handleTapCard,
    this.withTags = true,
    this.handleLongPressCard,
    this.handleSecondaryTapCard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GalleryCard(
      gallery: gallery,
      flat: listMode == ListMode.flat || listMode == ListMode.flatWithoutTags,
      withTags: withTags,
      handleTapCard: handleTapCard,
      handleLongPressCard: handleLongPressCard,
      handleSecondaryTapCard: handleSecondaryTapCard,
    );
  }
}

class GalleryCard extends StatelessWidget {
  final Gallery gallery;
  final bool flat;
  final bool withTags;
  final CardCallback handleTapCard;
  final CardCallback? handleLongPressCard;
  final CardCallback? handleSecondaryTapCard;

  const GalleryCard({
    Key? key,
    required this.gallery,
    required this.flat,
    required this.withTags,
    required this.handleTapCard,
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
          child: flat ? _FlatGalleryCard(gallery: gallery, withTags: withTags) : _RoundGalleryCard(gallery: gallery, withTags: withTags),
        ),
      ),
    );
  }
}

class _RoundGalleryCard extends StatelessWidget {
  final Gallery gallery;
  final bool withTags;

  const _RoundGalleryCard({Key? key, required this.gallery, required this.withTags}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        child: _FlatGalleryCard(gallery: gallery, withTags: withTags),
      ),
    );
  }
}

class _FlatGalleryCard extends StatelessWidget {
  final Gallery gallery;
  final bool withTags;

  const _FlatGalleryCard({Key? key, required this.gallery, required this.withTags}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      _GalleryCardCover(image: gallery.cover, withTags: withTags, withHeroTag: !gallery.hasLocalFilteredTag),
      Expanded(
        child: _GalleryCardInfo(gallery: gallery, withTags: withTags).paddingOnly(left: 6, right: 10, top: 6, bottom: 5),
      ),
    ];

    if (StyleSetting.moveCover2RightSide.isTrue) {
      children = children.reversed.toList();
    }

    Widget child = ColoredBox(
      color: UIConfig.backGroundColor(context),
      child: Row(children: children),
    );

    if (gallery.hasLocalFilteredTag) {
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
}

class _GalleryCardCover extends StatelessWidget {
  final GalleryImage image;
  final bool withTags;
  final bool withHeroTag;

  const _GalleryCardCover({
    Key? key,
    required this.image,
    required this.withTags,
    required this.withHeroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHImage(
      galleryImage: image,
      containerColor: UIConfig.galleryCardBackGroundColor(context),
      containerHeight: withTags ? UIConfig.galleryCardHeight : UIConfig.galleryCardHeightWithoutTags,
      containerWidth: withTags ? UIConfig.galleryCardCoverWidth : UIConfig.galleryCardCoverWidthWithoutTags,
      heroTag: withHeroTag ? image : null,
      fit: BoxFit.fitWidth,
    );
  }
}

class _GalleryCardInfo extends StatelessWidget {
  final Gallery gallery;
  final bool withTags;

  const _GalleryCardInfo({Key? key, required this.gallery, required this.withTags}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GalleryCardInfoHeader(title: gallery.title, uploader: gallery.uploader),
        if (withTags && gallery.tags.isNotEmpty) GalleryCardTagWaterFlow(tags: gallery.tags),
        _GalleryInfoFooter(gallery: gallery),
      ],
    );
  }
}

class _GalleryCardInfoHeader extends StatelessWidget {
  final String title;
  final String? uploader;

  const _GalleryCardInfoHeader({Key? key, required this.title, this.uploader}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: UIConfig.galleryCardTitleSize, height: 1.2),
        ),
        if (uploader != null)
          Text(
            uploader!,
            style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)),
          ).marginOnly(top: 2),
      ],
    );
  }
}

class GalleryCardTagWaterFlow extends StatelessWidget {
  final LinkedHashMap<String, List<GalleryTag>> tags;

  const GalleryCardTagWaterFlow({Key? key, required this.tags}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<GalleryTag> mergedList = [];
    tags.forEach((namespace, galleryTags) {
      mergedList.addAll(galleryTags);
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
      ),
    );
  }
}

class _GalleryInfoFooter extends StatelessWidget {
  final Gallery gallery;

  const _GalleryInfoFooter({Key? key, required this.gallery}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EHGalleryCategoryTag(category: gallery.category),
            const Expanded(child: SizedBox()),
            if (gallery.isFavorite) EHGalleryFavoriteTag(name: gallery.favoriteTagName!, color: ColorConsts.favoriteTagColor[gallery.favoriteTagIndex!]),
            if (gallery.language != null)
              Text(
                LocaleConsts.language2Abbreviation[gallery.language] ?? '',
                style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)),
              ).marginOnly(left: 4),
            if (gallery.pageCount != null) ...[
              Icon(Icons.panorama, size: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)).marginOnly(right: 1, left: 6),
              Text(
                gallery.pageCount.toString(),
                style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context)),
              ),
            ],
          ],
        ).marginOnly(bottom: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRatingBar(context),
            Text(
              DateUtil.transform2LocalTimeString(gallery.publishTime),
              style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor(context), decoration: gallery.isExpunged ? TextDecoration.lineThrough : null),
            ),
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
}
