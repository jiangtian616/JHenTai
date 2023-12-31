import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../config/ui_config.dart';
import '../model/gallery.dart';
import '../routes/routes.dart';

class EHGalleryHistoryDialog extends StatelessWidget {
  final GalleryUrl? parentUrl;
  final Gallery gallery;
  final List<({GalleryUrl galleryUrl, String title, String updateTime})>? childrenGallerys;

  const EHGalleryHistoryDialog({
    super.key,
    this.parentUrl,
    required this.gallery,
    this.childrenGallerys,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.scrollBehaviourWithScrollBar,
      child: EHWheelSpeedController(
        controller: null,
        child: SimpleDialog(
          title: Center(child: Text('history'.tr)),
          contentPadding: const EdgeInsets.only(top: 18, left: 12, right: 12, bottom: 12),
          children: [
            ...?childrenGallerys?.reversed.map(
              (e) => ListTile(
                dense: true,
                title: Text(
                  e.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: UIConfig.galleryHistoryTitleSize),
                ),
                trailing: Text(e.updateTime, style: const TextStyle(fontSize: UIConfig.galleryHistoryDialogTrailingTextSize)),
                onTap: () {
                  backRoute();
                  toRoute(
                    Routes.details,
                    arguments: {'gid': e.galleryUrl.gid, 'galleryUrl': e.galleryUrl.url},
                    offAllBefore: false,
                    preventDuplicates: false,
                  );
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
            ListTile(
              dense: true,
              title: Text(
                gallery.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: UIConfig.galleryHistoryTitleSize),
              ),
              trailing: Text('current'.tr, style: const TextStyle(fontSize: UIConfig.galleryHistoryDialogTrailingTextSize)),
              selected: true,
              selectedTileColor: UIConfig.galleryHistoryDialogTileColor(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            if (parentUrl != null)
              ListTile(
                dense: true,
                title: Text('parentGallery'.tr, style: const TextStyle(fontSize: UIConfig.galleryHistoryTitleSize)),
                trailing: const Icon(Icons.exit_to_app, size: UIConfig.galleryHistoryDialogSubtitleIconSize),
                onTap: () {
                  backRoute();
                  toRoute(
                    Routes.details,
                    arguments: {'gid': parentUrl!.gid, 'galleryUrl': parentUrl!.url},
                    offAllBefore: false,
                    preventDuplicates: false,
                  );
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
          ],
        ),
      ),
    );
  }
}
