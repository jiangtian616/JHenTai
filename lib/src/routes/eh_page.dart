import 'package:get/get.dart';

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
    required String name,
    required GetPageBuilder page,
    this.side = Side.right,
    this.offAllBefore = true,
    Transition? transition,
  }) : super(name: name, page: page, transition: transition);
}
