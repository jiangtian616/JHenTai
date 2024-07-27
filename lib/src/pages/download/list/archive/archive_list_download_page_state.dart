import 'dart:async';

import 'package:jhentai/src/pages/download/mixin/basic/multi_select/multi_select_download_page_state_mixin.dart';

import '../../../../database/database.dart';
import '../../../../mixin/scroll_to_top_state_mixin.dart';
import '../../../../widget/grouped_list.dart';
import '../../mixin/archive/archive_download_page_state_mixin.dart';

class ArchiveListDownloadPageState with Scroll2TopStateMixin, MultiSelectDownloadPageStateMixin, ArchiveDownloadPageStateMixin {
  Set<String> displayGroups = {};
  Completer<void> displayGroupsCompleter = Completer<void>();

  final GroupedListController<String, ArchiveDownloadedData> groupedListController = GroupedListController<String, ArchiveDownloadedData>();
}
