import 'package:jhentai/src/pages/read/widget/eh_scrollable_positioned_list.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../base/base_layout_state.dart';

class VerticalListLayoutState extends BaseLayoutState {

  final EHItemScrollController itemScrollController = EHItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
}
