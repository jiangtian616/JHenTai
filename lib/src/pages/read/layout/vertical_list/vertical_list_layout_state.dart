import 'package:jhentai/src/pages/read/widget/eh_scrollable_positioned_list.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class VerticalListLayoutState {
  final PhotoViewController photoViewController = PhotoViewController();

  final EHItemScrollController itemScrollController = EHItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
}
