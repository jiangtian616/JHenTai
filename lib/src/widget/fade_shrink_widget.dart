import 'package:flutter/material.dart';
import 'package:simple_animations/animation_controller_extension/animation_controller_extension.dart';
import 'package:simple_animations/animation_mixin/animation_mixin.dart';

class FadeShrinkWidget extends StatefulWidget {
  final bool show;
  final Widget child;
  final bool animateWhenInitialization;
  final Duration duration;

  final double opacityFrom;
  final double opacityTo;
  final double sizeFrom;
  final double sizeTo;

  final VoidCallback? afterDisappear;

  const FadeShrinkWidget({
    Key? key,
    required this.show,
    required this.child,
    this.animateWhenInitialization = false,
    this.duration = const Duration(milliseconds: 150),
    this.opacityFrom = 0,
    this.opacityTo = 1,
    this.sizeFrom = 0,
    this.sizeTo = 1,
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
    if (show) {
      controller.forward(from: widget.animateWhenInitialization ? 0 : 1);
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
    return FadeTransition(
      opacity: fadeAnimation,
      child: SizeTransition(
        sizeFactor: sizeAnimation,
        child: widget.child,
      ),
    );
  }
}
