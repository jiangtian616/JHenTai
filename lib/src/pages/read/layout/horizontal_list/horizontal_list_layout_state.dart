import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../widget/eh_scrollable_positioned_list.dart';

class HorizontalListLayoutState {
  final PhotoViewController photoViewController = PhotoViewController();
  
  final EHItemScrollController itemScrollController = EHItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
}
