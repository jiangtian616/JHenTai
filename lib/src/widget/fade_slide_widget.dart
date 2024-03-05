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

  final bool enableSlideTransition;
  final double slideFrom;
  final double slideTo;
  final Axis sizeAxis;

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
    this.slideFrom = 0,
    this.slideTo = 1,
    this.sizeAxis = Axis.vertical,
    this.afterDisappear,
  }) : super(key: key);

  @override
  State<FadeSlideWidget> createState() => _FadeSlideWidgetState();
}

class _FadeSlideWidgetState extends State<FadeSlideWidget> with AnimationMixin {
  bool show = false;

  late Animation<double> fadeAnimation =
      Tween<double>(begin: widget.opacityFrom, end: widget.opacityTo).animate(CurvedAnimation(parent: controller, curve: Curves.ease));
  late Animation<double> slideAnimation = Tween<double>(begin: widget.slideFrom, end: widget.slideTo).animate(controller);

  @override
  void initState() {
    super.initState();

    show = widget.show;
    if (!show) {
      return;
    }

    if (widget.animateWhenInitialization) {
      controller.play(duration: widget.duration);
    } else {
      controller.forward(from: 1);
    }
  }

  @override
  void didUpdateWidget(covariant FadeSlideWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.show == widget.show) {
      return;
    }

    show = widget.show;
    if (show) {
      controller.play(duration: widget.duration);
    } else {
      controller.playReverse(duration: widget.duration).then((_) {
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
      child = Align(
        widthFactor: widget.sizeAxis == Axis.horizontal ? slideAnimation.value : 1,
        heightFactor: widget.sizeAxis == Axis.vertical ? slideAnimation.value : 1,
        child: child,
      );
    }

    return child;
  }
}
