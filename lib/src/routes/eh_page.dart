import 'package:get/get.dart';

import '../widget/horizontal_safe_area.dart';

enum Side {
  left,
  right,
  fullScreen,
}

class EHPage extends GetPage {
  /// in tablet layout, the side this page on.
  final Side side;

  /// used when pushing a new route to right screen
  final bool offAllBefore;

  EHPage({
    required super.name,
    required GetPageBuilder page,
    this.side = Side.right,
    this.offAllBefore = true,
    super.transition,
    super.popGesture,
  }) : super(
          /// Both the root navigator and the nested navigators of tablet & desktop layout build pages from here, so every page
          /// avoids the left and right system insets in all layouts. Full screen pages like read page handle insets by themselves.
          page: side == Side.fullScreen ? page : () => HorizontalSafeArea(child: page()),
        );
}
