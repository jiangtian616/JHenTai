import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../widget/eh_scrollable_positioned_list.dart';
import '../base/base_layout_state.dart';

class HorizontalListLayoutState extends BaseLayoutState {
  final EHItemScrollController itemScrollController = EHItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
}
