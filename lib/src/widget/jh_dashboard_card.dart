import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import '../config/global_config.dart';

import '../consts/locale_consts.dart';
import '../model/gallery_image.dart';
import '../model/gallery_tag.dart';
import '../routes/routes.dart';
import '../service/tag_translation_service.dart';
import '../utils/route_util.dart';
import 'loading_state_indicator.dart';

class JHDashboardCard extends StatelessWidget {
  final Gallery gallery;
  final String? badge;

  const JHDashboardCard({Key? key, required this.gallery, this.badge}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => toRoute(Routes.details, arguments: {
          'galleryUrl': gallery.galleryUrl,
          'gallery': gallery,
        }),
        child: Stack(
          children: [
            _buildCover(gallery.cover),
            Positioned(child: _buildShade(), height: 60, width: GlobalConfig.dashboardCardSize, bottom: 0),
            Positioned(child: _buildGalleryDesc(), width: GlobalConfig.dashboardCardSize, bottom: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(GalleryImage image) {
    return EHImage.network(
      containerHeight: GlobalConfig.dashboardCardSize,
      containerWidth: GlobalConfig.dashboardCardSize,
      galleryImage: image,
      fit: BoxFit.cover,
    );
  }

  Widget _buildGalleryDesc() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gallery.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.account_circle, color: Colors.white, size: 12),
            Text(
              gallery.uploader ?? 'unknownUser'.tr,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 10),
            ).marginOnly(left: 2),
            const Expanded(child: SizedBox()),
            Text(
              '${badge ?? ''} ${LocaleConsts.language2Abbreviation[gallery.language] ?? ''}',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 10),
            ),
          ],
        )
      ],
    ).paddingSymmetric(horizontal: 8);
  }

  Widget _buildShade() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
    );
  }

  String? _getArtistName() {
    String namespace = StyleSetting.enableTagZHTranslation.isTrue && Get.find<TagTranslationService>().loadingState.value == LoadingState.success
        ? LocaleConsts.tagNamespace['artist']!
        : 'artist';

    List<GalleryTag>? artistTags = gallery.tags[namespace];

    if (artistTags?.isEmpty ?? true) {
      return null;
    }

    if (artistTags!.length == 1) {
      return artistTags.first.tagData.tagName;
    }

    return '${artistTags.first.tagData.tagName}...+${artistTags.length - 1}';
  }
}
