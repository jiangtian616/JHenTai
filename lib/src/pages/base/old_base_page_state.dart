import 'package:jhentai/src/pages/base/base_page_state.dart';

/// load pages by page index, not by nextGid or prevGid, to deal with EHentai's old search rule
abstract class OldBasePageState extends BasePageState {
  int pageCount = -1;
  int? prevPageIndexToLoad;
  int? nextPageIndexToLoad = 0;
}
