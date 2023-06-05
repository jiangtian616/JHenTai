import 'package:flutter/material.dart';
import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';

class FadeShrinkWidget extends StatefulWidget {
  final Widget child;

  final bool show;
  final bool animateWhenInitialization;
  final Duration duration;

  final bool enableOpacityTransition;
  final double opacityFrom;
  final double opacityTo;

  final bool enableSizeTransition;
  final double sizeFrom;
  final double sizeTo;
  final Axis sizeAxis;

  final VoidCallback? afterDisappear;

  const FadeShrinkWidget({
    Key? key,
    required this.show,
    required this.child,
    this.animateWhenInitialization = false,
    this.duration = const Duration(milliseconds: 150),
    this.enableOpacityTransition = true,
    this.enableSizeTransition = true,
    this.opacityFrom = 0,
    this.opacityTo = 1,
    this.sizeFrom = 0,
    this.sizeTo = 1,
    this.sizeAxis = Axis.vertical,
    this.afterDisappear,
  }) : super(key: key);

  @override
  State<FadeShrinkWidget> createState() => _FadeShrinkWidgetState();
}

class _FadeShrinkWidgetState extends State<FadeShrinkWidget> with AnimationMixin {
  bool show = false;

  late Animation<double> fadeAnimation =
      Tween<double>(begin: widget.opacityFrom, end: widget.opacityTo).animate(CurvedAnimation(parent: controller, curve: Curves.ease));
  late Animation<double> sizeAnimation =
      Tween<double>(begin: widget.sizeFrom, end: widget.sizeTo).animate(CurvedAnimation(parent: controller, curve: Curves.ease));

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
  void didUpdateWidget(covariant FadeShrinkWidget oldWidget) {
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

    if (widget.enableSizeTransition) {
      child = SizeTransition(
        sizeFactor: sizeAnimation,
        axis: widget.sizeAxis,
        child: child,
      );
    }

    return child;
  }
}
