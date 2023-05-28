import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import 'package:jhentai/src/pages/download/mixin/gallery/gallery_download_page_state_mixin.dart';

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
      IconButton(icon: const Icon(Icons.done_all), onPressed: galleryDownloadPageLogic.selectAllItem),
      IconButton(icon: const Icon(Icons.play_arrow), onPressed: galleryDownloadPageLogic.handleMultiResumeTasks),
      IconButton(icon: const Icon(Icons.pause), onPressed: galleryDownloadPageLogic.handleMultiPauseTasks),
      IconButton(icon: const Icon(Icons.refresh), onPressed: galleryDownloadPageLogic.handleMultiReDownloadItems),
      IconButton(icon: const Icon(Icons.bookmark), onPressed: galleryDownloadPageLogic.handleMultiChangeGroup),
      IconButton(icon: const Icon(Icons.delete), onPressed: galleryDownloadPageLogic.handleMultiDelete),
      const Expanded(child: SizedBox()),
      IconButton(icon: const Icon(Icons.close), onPressed: multiSelectDownloadPageLogic.exitSelectMode),
    ];
  }
}
