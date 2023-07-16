import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/widget/eh_image.dart';
import '../config/ui_config.dart';

import '../consts/locale_consts.dart';
import '../model/gallery_image.dart';
import '../model/gallery_tag.dart';
import '../routes/routes.dart';
import '../service/tag_translation_service.dart';
import '../utils/route_util.dart';

class EHDashboardCard extends StatefulWidget {
  final Gallery gallery;
  final String? badge;

  const EHDashboardCard({Key? key, required this.gallery, this.badge}) : super(key: key);

  @override
  State<EHDashboardCard> createState() => _EHDashboardCardState();
}

class _EHDashboardCardState extends State<EHDashboardCard> {
  bool loadSuccess = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => toRoute(
          Routes.details,
          arguments: {
            'gid': widget.gallery.gid,
            'galleryUrl': widget.gallery.galleryUrl,
            'gallery': widget.gallery,
          },
        ),

        /// show info after image load success
        child: Stack(
          children: [
            _buildCover(widget.gallery.cover),
            if (loadSuccess) Positioned(child: _buildShade(), height: 60, width: UIConfig.dashboardCardSize, bottom: 0),
            if (loadSuccess) Positioned(child: _buildGalleryDesc(), width: UIConfig.dashboardCardSize, bottom: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(GalleryImage image) {
    return EHImage(
      containerHeight: UIConfig.dashboardCardSize,
      containerWidth: UIConfig.dashboardCardSize,
      galleryImage: image,
      fit: BoxFit.cover,
      completedWidgetBuilder: (_) {
        Get.engine.addPostFrameCallback((_) {
          if (mounted && !loadSuccess) {
            setState(() => loadSuccess = true);
          }
        });
        return null;
      },
    );
  }

  Widget _buildShade() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, UIConfig.dashboardCardShadeColor],
        ),
      ),
    );
  }

  Widget _buildGalleryDesc() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.gallery.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: UIConfig.dashboardCardTextColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.account_circle, color: UIConfig.dashboardCardTextColor, size: 12),
            Text(
              widget.gallery.uploader ?? 'unknownUser'.tr,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: UIConfig.dashboardCardFooterTextColor, fontSize: 10),
            ).marginOnly(left: 2),
            const Expanded(child: SizedBox()),
            Text(
              '${widget.badge ?? ''} ${LocaleConsts.language2Abbreviation[widget.gallery.language] ?? ''}',
              style: TextStyle(color: UIConfig.dashboardCardFooterTextColor, fontSize: 10),
            ),
          ],
        )
      ],
    ).paddingSymmetric(horizontal: 8);
  }

  String? _getArtistName() {
    String namespace = Get.find<TagTranslationService>().isReady ? LocaleConsts.tagNamespace['artist']! : 'artist';

    List<GalleryTag>? artistTags = widget.gallery.tags[namespace];

    if (artistTags?.isEmpty ?? true) {
      return null;
    }

    if (artistTags!.length == 1) {
      return artistTags.first.tagData.tagName;
    }

    return '${artistTags.first.tagData.tagName}...+${artistTags.length - 1}';
  }
}
