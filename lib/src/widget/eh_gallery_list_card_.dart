import 'dart:async';
import 'dart:collection';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_layout_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_gallery_favorite_tag.dart';
import 'package:jhentai/src/widget/focus_widget.dart';
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
  final CardCallback handleTapCard;
  final CardCallback? handleLongPressCard;
  final CardCallback? handleSecondaryTapCard;
  final bool withTags;

  const EHGalleryListCard(
      {Key? key, required this.gallery, required this.handleTapCard, this.withTags = true, this.handleLongPressCard, this.handleSecondaryTapCard})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FocusWidget(
      focusedDecoration: StyleSetting.listMode.value == ListMode.flat
          ? BoxDecoration(
              color: Get.theme.cardColor,
              border: Border(right: BorderSide(width: 3, color: Get.theme.colorScheme.onBackground)),
            )
          : const BoxDecoration(color: Colors.grey),
      handleTapArrowLeft: () => Get.find<DesktopLayoutPageLogic>().state.leftTabBarFocusScopeNode.requestFocus(),
      handleTapEnter: () => handleTapCard(gallery),
      handleTapArrowRight: () {
        if (!isRouteAtTop(Routes.details)) {
          handleTapCard(gallery);
          return;
        }

        if (rightRouting.args is Gallery && rightRouting.args.galleryUrl != gallery.galleryUrl) {
          handleTapCard(gallery);
          return;
        }

        Get.find<DesktopLayoutPageLogic>().state.rightColumnFocusScopeNode.requestFocus();
      },
      child: GalleryCard(
        gallery: gallery,
        withTags: withTags,
        handleTapCard: handleTapCard,
        handleLongPressCard: handleLongPressCard,
        handleSecondaryTapCard: handleSecondaryTapCard,
      ),
    );
  }
}

class GalleryCard extends StatelessWidget {
  final Gallery gallery;
  final bool withTags;
  final CardCallback handleTapCard;
  final CardCallback? handleLongPressCard;
  final CardCallback? handleSecondaryTapCard;

  const GalleryCard(
      {Key? key, required this.gallery, required this.withTags, required this.handleTapCard, this.handleLongPressCard, this.handleSecondaryTapCard})
      : super(key: key);

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
          child: Obx(() {
            if (StyleSetting.listMode.value == ListMode.flat) return _FlatGalleryCard(gallery: gallery, withTags: withTags);
            return _RoundGalleryCard(gallery: gallery, withTags: withTags);
          }),
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
        color: Theme.of(context).colorScheme.background,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
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
      _GalleryCardCover(image: gallery.cover, withTags: withTags),
      Expanded(
        child: _GalleryCardInfo(gallery: gallery, withTags: withTags).paddingOnly(left: 6, right: 10, top: 6, bottom: 5),
      ),
    ];

    if (StyleSetting.moveCover2RightSide.isTrue) {
      children = children.reversed.toList();
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.background,
      child: Row(children: children),
    );
  }
}

class _GalleryCardCover extends StatelessWidget {
  final GalleryImage image;
  final bool withTags;

  const _GalleryCardCover({Key? key, required this.image, required this.withTags}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHImage.network(
      containerColor: Get.theme.colorScheme.surfaceVariant,
      containerHeight: withTags ? UIConfig.galleryCardHeight : UIConfig.galleryCardHeightWithoutTags,
      containerWidth: withTags ? UIConfig.galleryCardCoverWidth : UIConfig.galleryCardCoverWidthWithoutTags,
      heroTag: image,
      fit: BoxFit.fitWidth,
      galleryImage: image,
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
        if (withTags && gallery.tags.isNotEmpty) _GalleryCardTagWaterFlow(tags: gallery.tags),
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
            style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor),
          ).marginOnly(top: 2),
      ],
    );
  }
}

class _GalleryCardTagWaterFlow extends StatelessWidget {
  final LinkedHashMap<String, List<GalleryTag>> tags;

  const _GalleryCardTagWaterFlow({Key? key, required this.tags}) : super(key: key);

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
        itemBuilder: (_, int index) => EHTag(
          tag: mergedList[index],
        ),
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
            if (gallery.isFavorite)
              EHGalleryFavoriteTag(name: gallery.favoriteTagName!, color: ColorConsts.favoriteTagColor[gallery.favoriteTagIndex!]),
            if (gallery.language != null)
              Text(
                LocaleConsts.language2Abbreviation[gallery.language] ?? '',
                style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor),
              ).marginOnly(left: 4),
            if (gallery.pageCount != null) ...[
              Icon(Icons.panorama, size: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor).marginOnly(right: 1, left: 6),
              Text(
                gallery.pageCount.toString(),
                style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor),
              ),
            ],
          ],
        ).marginOnly(bottom: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRatingBar(),
            Text(
              DateUtil.transform2LocalTimeString(gallery.publishTime),
              style: TextStyle(fontSize: UIConfig.galleryCardTextSize, color: UIConfig.galleryCardTextColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingBar() {
    return RatingBar.builder(
      unratedColor: Colors.grey.shade300,
      initialRating: gallery.rating,
      itemCount: 5,
      allowHalfRating: true,
      itemSize: 16,
      ignoreGestures: true,
      itemBuilder: (context, _) => Icon(
        Icons.star,
        color: gallery.hasRated ? UIConfig.resumeButtonColor : Colors.amber.shade800,
      ),
      onRatingUpdate: (rating) {},
    );
  }
}
