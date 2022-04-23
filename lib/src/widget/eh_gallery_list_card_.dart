import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../consts/color_consts.dart';
import '../consts/locale_consts.dart';
import '../model/gallery_image.dart';
import '../utils/date_util.dart';
import 'eh_image.dart';
import 'eh_tag.dart';
import 'eh_gallery_category_tag.dart';

typedef TapCardCallback = FutureOr<void> Function(Gallery gallery);

class EHGalleryListCard extends StatelessWidget {
  final Gallery gallery;
  final TapCardCallback handleTapCard;
  final bool withTags;

  const EHGalleryListCard({
    Key? key,
    required this.gallery,
    required this.handleTapCard,
    this.withTags = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => handleTapCard(gallery),
      child: FadeIn(
        child: Container(
          height: withTags ? 200 : 125,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 5,
                spreadRadius: 1,
                offset: const Offset(3, 3),
              )
            ],
            borderRadius: BorderRadius.circular(15),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Row(
              children: [
                _buildCover(gallery.cover),
                _buildInfo(gallery),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(GalleryImage image) {
    return Obx(() {
      return EHImage.network(
        containerHeight: withTags ? 200 : 125,
        containerWidth: withTags ? 140 : 85,
        adaptive: true,
        galleryImage: image,
        fit: StyleSetting.coverMode.value == CoverMode.contain ? BoxFit.contain : BoxFit.cover,
      );
    });
  }

  Widget _buildInfo(Gallery gallery) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleAndUploader(gallery.title, gallery.uploader),
          if (gallery.tags.isNotEmpty && withTags) _buildTagWaterFlow(gallery.tags),
          _buildFooter(gallery),
        ],
      ).paddingOnly(left: 6, right: 10, top: 5, bottom: 5),
    );
  }

  Widget _buildTitleAndUploader(String title, String? uploader) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, height: 1.2),
        ),
        if (uploader != null)
          Text(
            uploader,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ).marginOnly(top: 2),
      ],
    );
  }

  Widget _buildTagWaterFlow(Map<String, List<GalleryTag>> tags) {
    List<GalleryTag> mergedList = [];
    tags.forEach((namespace, galleryTags) {
        mergedList.addAll(galleryTags);
    });

    return SizedBox(
      height: 70,
      child: WaterfallFlow.builder(
        scrollDirection: Axis.horizontal,
        /// disable keepScrollOffset because we used [PageStorageKey] in ranklist view, which leads to
        /// a conflict with this WaterfallFlow
        controller: ScrollController(keepScrollOffset: false),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: mergedList.length,
        itemBuilder: (BuildContext context, int index) => EHTag(
          tag: mergedList[index],
          fontSize: 12,
          textHeight: 1.2,
          borderRadius: 4,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        ),
      ),
    );
  }

  Widget _buildFooter(Gallery gallery) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EHGalleryCategoryTag(category: gallery.category),
            const Expanded(child: SizedBox()),
            if (gallery.isFavorite)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: ColorConsts.favoriteTagColor[gallery.favoriteTagIndex!],
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 8,
                        color: Colors.white,
                      ),
                      Text(
                        gallery.favoriteTagName!,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1,
                          color: Colors.white,
                        ),
                      ).marginOnly(left: 2),
                    ],
                  ),
                ),
              ).marginOnly(right: 4),
            if (gallery.language != null)
              Text(
                LocaleConsts.language2Abbreviation[gallery.language] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ).marginOnly(right: 4),
            if (gallery.pageCount != null)
              Icon(
                Icons.panorama,
                size: 12,
                color: Colors.grey.shade600,
              ).marginOnly(right: 2),
            if (gallery.pageCount != null)
              Text(
                gallery.pageCount.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RatingBar.builder(
              unratedColor: Colors.grey.shade300,
              initialRating: gallery.rating,
              itemCount: 5,
              allowHalfRating: true,
              itemSize: 16,
              ignoreGestures: true,
              itemBuilder: (context, _) => Icon(
                Icons.star,
                color: gallery.hasRated ? Get.theme.primaryColor : Colors.amber.shade800,
              ),
              onRatingUpdate: (rating) {},
            ),
            Text(
              DateUtil.transform2LocalTimeString(gallery.publishTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ).marginOnly(top: 2),
      ],
    );
  }
}
