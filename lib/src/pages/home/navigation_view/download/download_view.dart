import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/download_service.dart';

import '../../../../config/global_config.dart';
import '../../../../consts/color_consts.dart';
import '../../../../consts/locale_consts.dart';
import '../../../../model/download_progress.dart';
import '../../../../model/gallery.dart';
import '../../../../model/gallery_image.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/date_util.dart';
import '../../../../widget/eh_image.dart';
import '../../../../widget/gallery_category_tag.dart';

class DownloadView extends StatelessWidget {
  final DownloadService downloadService = Get.find();

  DownloadView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('download'.tr),
        toolbarHeight: GlobalConfig.appBarHeight,
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: downloadService.gid2gallery.value.values
              .map(
                (gallery) => GestureDetector(
                  onTap: () => Get.toNamed(Routes.details, arguments: gallery),
                  child: Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,

                      /// covered when in dark mode
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
                    margin: const EdgeInsets.only(top: 5, bottom: 4, left: 10, right: 10),
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
              )
              .toList(),
        );
      }),
    );
  }

  Widget _buildCover(GalleryImage image) {
    return EHImage(
      containerHeight: 130,
      containerWidth: 110,
      galleryImage: image,
      adaptive: true,
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
          _buildFooter(gallery),
          _buildProgressIndicator(gallery),
        ],
      ).paddingOnly(left: 6, right: 10, top: 8, bottom: 5),
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
        ).marginOnly(top: 5),
      ],
    );
  }

  Widget _buildFooter(Gallery gallery) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (gallery.isFavorite)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  color: ColorConsts.favoriteTagColor[gallery.favoriteTagIndex!],
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 10,
                        color: Colors.white,
                      ),
                      Text(
                        gallery.favoriteTagName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ).marginOnly(left: 2),
                    ],
                  ),
                ),
              )
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GalleryCategoryTag(category: gallery.category),
            const Expanded(child: SizedBox()),
            if (gallery.language != null)
              Text(
                LocaleConsts.languageCode[gallery.language] ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ).marginOnly(right: 4),
            Icon(
              Icons.panorama,
              size: 12,
              color: Colors.grey.shade600,
            ).marginOnly(right: 2),
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

  Widget _buildProgressIndicator(Gallery gallery) {
    DownloadProgress downloadProgress = downloadService.gid2downloadProgress.value[gallery.gid]!;
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        value: downloadProgress.curCount / downloadProgress.totalCount,
        color: Get.theme.primaryColorLight,
      ),
    );
  }
}
