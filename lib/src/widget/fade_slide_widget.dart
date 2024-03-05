import 'package:flutter/material.dart';
import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';

class FadeSlideWidget extends StatefulWidget {
  final Widget child;

  final bool show;
  final bool animateWhenInitialization;
  final Duration duration;

  final bool enableOpacityTransition;
  final double opacityFrom;
  final double opacityTo;
  final Curve opacityCurve;

  final bool enableSlideTransition;
  final double slideFrom;
  final double slideTo;
  final Curve slideCurve;
  final Axis axis;

  final VoidCallback? afterDisappear;

  const FadeSlideWidget({
    Key? key,
    required this.show,
    required this.child,
    this.animateWhenInitialization = false,
    this.duration = const Duration(milliseconds: 150),
    this.enableOpacityTransition = true,
    this.enableSlideTransition = true,
    this.opacityFrom = 0,
    this.opacityTo = 1,
    this.opacityCurve = Curves.ease,
    this.slideFrom = 0,
    this.slideTo = 1,
    this.slideCurve = Curves.linear,
    this.axis = Axis.vertical,
    this.afterDisappear,
  }) : super(key: key);

  @override
  State<FadeSlideWidget> createState() => _FadeSlideWidgetState();
}

class _FadeSlideWidgetState extends State<FadeSlideWidget> with AnimationMixin {
  bool show = false;

  late Animation<double> fadeAnimation =
      Tween<double>(begin: widget.opacityFrom, end: widget.opacityTo).animate(CurvedAnimation(parent: controller, curve: widget.opacityCurve));
  late Animation<double> slideAnimation =
      Tween<double>(begin: widget.slideFrom, end: widget.slideTo).animate(CurvedAnimation(parent: controller, curve: widget.slideCurve));

  @override
  void initState() {
    super.initState();

    show = widget.show;
    controller.duration = widget.duration;

    if (widget.animateWhenInitialization) {
      if (show) {
        controller.forward();
      } else {
        controller.reverse(from: 1).then((_) {
          widget.afterDisappear?.call();
        });
      }
    } else {
      if (show) {
        controller.value = 1;
      } else {
        controller.value = 0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant FadeSlideWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.show == widget.show) {
      return;
    }

    controller.duration = widget.duration;
    show = widget.show;

    if (show) {
      controller.forward();
    } else {
      controller.reverse().then((_) {
        widget.afterDisappear?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    if (widget.enableOpacityTransition) {
      child = FadeTransition(
        opacity: fadeAnimation,
        child: child,
      );
    }

    if (widget.enableSlideTransition) {
      child = ClipRect(
        child: Align(
          alignment: widget.axis == Axis.horizontal ? Alignment.centerLeft : Alignment.topCenter,
          widthFactor: widget.axis == Axis.horizontal ? slideAnimation.value : 1,
          heightFactor: widget.axis == Axis.vertical ? slideAnimation.value : 1,
          child: child,
        ),
      );
    }

    return child;
  }
}
