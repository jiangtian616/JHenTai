import 'package:flutter/material.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_apple_glass_toolbar.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import 'gallery_download_page_logic_mixin.dart';

mixin GalleryDownloadPageMixin on StatelessWidget implements Scroll2TopPageMixin, MultiSelectDownloadPageMixin {
  GalleryDownloadPageLogicMixin get galleryDownloadPageLogic;

  GalleryDownloadPageStateMixin get galleryDownloadPageState;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => galleryDownloadPageLogic;

  @override
  Scroll2TopStateMixin get scroll2TopState => galleryDownloadPageState;

  @override
  List<Widget> buildBottomAppBarButtons() {
    return [
      EHAppleGlassToolbar(
        items: [
          EHAppleToolbarItem(icon: const Icon(Icons.done_all), onPressed: galleryDownloadPageLogic.selectAllItem),
          EHAppleToolbarItem(icon: const Icon(Icons.play_arrow), onPressed: galleryDownloadPageLogic.handleMultiResumeTasks),
          EHAppleToolbarItem(icon: const Icon(Icons.pause), onPressed: galleryDownloadPageLogic.handleMultiPauseTasks),
          EHAppleToolbarItem(icon: const Icon(Icons.refresh), onPressed: galleryDownloadPageLogic.handleMultiReDownloadItems),
          EHAppleToolbarItem(icon: const Icon(Icons.bookmark), onPressed: galleryDownloadPageLogic.handleMultiChangeGroup),
          EHAppleToolbarItem(icon: const Icon(Icons.delete), onPressed: galleryDownloadPageLogic.handleMultiDelete),
        ],
      ),
      const Expanded(child: SizedBox()),
      EHAppleIconButton(icon: const Icon(Icons.close), onPressed: multiSelectDownloadPageLogic.exitSelectMode),
    ];
  }
}
