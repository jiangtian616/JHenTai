import 'package:flutter/cupertino.dart';

typedef EHSliverHeaderBuilder = Widget Function(BuildContext context, double shrinkOffset, bool overlapsContent);

class EHSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  Object? otherCondition;

  EHSliverHeaderDelegate({
    required this.maxHeight,
    this.minHeight = 0,
    this.otherCondition,
    required Widget child,
  })  : builder = ((a, b, c) => child),
        assert(minHeight <= maxHeight && minHeight >= 0);

  EHSliverHeaderDelegate.fixedHeight({
    required double height,
    required Widget child,
    this.otherCondition,
  })  : builder = ((a, b, c) => child),
        maxHeight = height,
        minHeight = height;

  EHSliverHeaderDelegate.builder({
    required this.maxHeight,
    this.minHeight = 0,
    this.otherCondition,
    required this.builder,
  });

  final double maxHeight;
  final double minHeight;
  final EHSliverHeaderBuilder builder;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    Widget child = builder(context, shrinkOffset, overlapsContent);
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(EHSliverHeaderDelegate old) {
    return old.maxExtent != maxExtent || old.minExtent != minExtent || old.otherCondition != otherCondition;
  }
}
