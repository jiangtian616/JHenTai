import 'dart:async';

import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../../../../consts/color_consts.dart';
import '../../../../consts/locale_consts.dart';
import '../../../../database/database.dart';
import '../../../../model/gallery_image.dart';
import '../../../../utils/date_util.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/eh_tag.dart';
import '../../../../widget/gallery_category_tag.dart';

typedef TapCardCallback = FutureOr<void> Function(Gallery gallery);

class GalleryCard extends StatelessWidget {
  final Gallery gallery;
  final TapCardCallback handleTapCard;
  final bool keepAlive;

  const GalleryCard({
    Key? key,
    required this.gallery,
    required this.handleTapCard,
    this.keepAlive = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /// 1. in order to keep position for each TabBarView after changing to another TabBarView,
    /// we should make the sliver widget in CustomScrollView mixin with [AutomaticKeepAliveClientMixin].
    /// 2. we use a handy class [KeepAliveWrapper] to avoid write with AutomaticKeepAliveClientMixin,
    /// they are equal in fact.
    return KeepAliveWrapper(
      keepAlive: keepAlive,
      child: GestureDetector(
        onTap: () => handleTapCard(gallery),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                spreadRadius: 1,
                offset: const Offset(0.5, 3),
              )
            ],
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(top: 5, bottom: 10, left: 10, right: 10),
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
    return EHImage(
      containerHeight: 200,
      containerWidth: 140,
      adaptive: true,
      galleryImage: image,
      fit: BoxFit.cover,
    );
  }

  Widget _buildInfo(Gallery gallery) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleAndUploader(gallery.title, gallery.uploader),
          if (gallery.tags.isNotEmpty) _buildTagWaterFlow(gallery.tags),
          _buildFooter(gallery),
        ],
      ).paddingOnly(left: 6, right: 10, top: 5, bottom: 5),
    );
  }

  Widget _buildTitleAndUploader(String title, String uploader) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, height: 1.2),
        ),
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

  Widget _buildTagWaterFlow(Map<String, List<TagData>> tags) {
    List<MapEntry<String, TagData>> mergedList = [];
    tags.forEach((namespace, tagDatas) {
      for (TagData tagData in tagDatas) {
        mergedList.add(MapEntry(namespace, tagData));
      }
    });

    return SizedBox(
      height: 70,
      child: WaterfallFlow.builder(
        key: Key(gallery.gid.toString()),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: mergedList.length,
        itemBuilder: (BuildContext context, int index) => EHTag(
          tagData: mergedList[index].value,
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
            GalleryCategoryTag(category: gallery.category),
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
                LocaleConsts.languageCode[gallery.language] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ).marginOnly(right: 4),
            if (gallery.pageCount > 0)
              Icon(
                Icons.panorama,
                size: 12,
                color: Colors.grey.shade600,
              ).marginOnly(right: 2),
            if (gallery.pageCount > 0)
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
