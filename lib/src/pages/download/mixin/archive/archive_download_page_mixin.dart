import 'package:flutter/material.dart';
import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_mixin.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

import '../../../../mixin/scroll_to_top_logic_mixin.dart';
import '../../../../mixin/scroll_to_top_page_mixin.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../basic/multi_select/multi_select_download_page_state_mixin.dart';
import 'archive_download_page_logic_mixin.dart';
import 'archive_download_page_state_mixin.dart';

mixin ArchiveDownloadPageMixin on StatelessWidget implements Scroll2TopPageMixin, MultiSelectDownloadPageMixin {
  ArchiveDownloadPageLogicMixin get archiveDownloadPageLogic;

  ArchiveDownloadPageStateMixin get archiveDownloadPageState;

  @override
  Scroll2TopLogicMixin get scroll2TopLogic => archiveDownloadPageLogic;

  @override
  Scroll2TopStateMixin get scroll2TopState => archiveDownloadPageState;

  @override
  MultiSelectDownloadPageLogicMixin get multiSelectDownloadPageLogic => archiveDownloadPageLogic;

  @override
  MultiSelectDownloadPageStateMixin get multiSelectDownloadPageState => archiveDownloadPageState;

  @override
  List<Widget> buildBottomAppBarButtons() {
    return [
      EHAppleIconButton(icon: const Icon(Icons.done_all), onPressed: archiveDownloadPageLogic.selectAllItem),
      const SizedBox(width: 8),
      EHAppleIconButton(icon: const Icon(Icons.play_arrow), onPressed: archiveDownloadPageLogic.handleMultiResumeTasks),
      const SizedBox(width: 8),
      EHAppleIconButton(icon: const Icon(Icons.pause), onPressed: archiveDownloadPageLogic.handleMultiPauseTasks),
      const SizedBox(width: 8),
      EHAppleIconButton(icon: const Icon(Icons.bookmark), onPressed: archiveDownloadPageLogic.handleMultiChangeGroup),
      const SizedBox(width: 8),
      EHAppleIconButton(icon: const Icon(Icons.delete), onPressed: archiveDownloadPageLogic.handleMultiDelete),
      const SizedBox(width: 8),
      EHAppleIconButton(icon: const Icon(Icons.smart_toy_outlined), onPressed: archiveDownloadPageLogic.handleChangeParseSource),
      const Expanded(child: SizedBox()),
      EHAppleIconButton(icon: const Icon(Icons.close), onPressed: multiSelectDownloadPageLogic.exitSelectMode),
    ];
  }
}
