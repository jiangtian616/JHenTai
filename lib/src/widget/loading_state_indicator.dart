import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

enum LoadingState {
  /// didn't load or success
  idle,
  loading,
  error,

  /// loaded and there isn't any data
  noData,

  /// loaded several pages and there isn't no more data
  noMore,
  success,
}

typedef ErrorTapCallback = void Function();
typedef NoDataTapCallback = void Function();
typedef SuccessWidgetBuilder = Widget Function();

class LoadingStateIndicator extends StatelessWidget {
  final double? height;
  final double? width;
  final LoadingState loadingState;
  final ErrorTapCallback? errorTapCallback;
  final NoDataTapCallback? noDataTapCallback;
  final bool userCupertinoIndicator;
  final double indicatorRadius;
  final Widget? idleWidget;
  final Widget? loadingWidget;
  final Widget? noMoreWidget;
  final Widget? noDataWidget;
  final SuccessWidgetBuilder? successWidgetBuilder;
  final Widget? errorWidget;
  final bool errorWidgetSameWithIdle;
  final bool successWidgetSameWithIdle;

  const LoadingStateIndicator({
    Key? key,
    this.height,
    this.width,
    required this.loadingState,
    this.errorTapCallback,
    this.noDataTapCallback,
    this.userCupertinoIndicator = true,
    this.indicatorRadius = 12,
    this.idleWidget,
    this.loadingWidget,
    this.noMoreWidget,
    this.noDataWidget,
    this.successWidgetBuilder,
    this.errorWidget,
    this.errorWidgetSameWithIdle = false,
    this.successWidgetSameWithIdle = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child;

    switch (loadingState) {
      case LoadingState.loading:
        child = loadingWidget ??
            (userCupertinoIndicator
                ? CupertinoActivityIndicator(radius: indicatorRadius)
                : const CircularProgressIndicator());
        break;
      case LoadingState.error:
        child = errorWidget ??
            (errorWidgetSameWithIdle
                ? idleWidget!
                : GestureDetector(
                    onTap: errorTapCallback,
                    child: Icon(
                      FontAwesomeIcons.redoAlt,
                      size: indicatorRadius * 2,
                      color: Colors.grey.shade700,
                    ),
                  ));
        break;
      case LoadingState.idle:
        if (idleWidget != null) {
          return idleWidget!;
        }
        child = CupertinoActivityIndicator(radius: indicatorRadius);
        break;
      case LoadingState.noMore:
        child = noMoreWidget ?? Text('noMoreData'.tr, style: const TextStyle(color: Colors.grey));
        break;
      case LoadingState.success:
        if (successWidgetSameWithIdle == true) {
          return idleWidget!;
        }
        if (successWidgetBuilder != null) {
          return successWidgetBuilder!();
        }
        child = const SizedBox();
        break;
      case LoadingState.noData:
        child = GestureDetector(
          onTap: noDataTapCallback,
          child: noDataWidget ?? Text('noData'.tr, style: const TextStyle(color: Colors.grey)),
        );
        break;
    }

    return Center(
      child: SizedBox(
        height: height,
        width: width,
        child: child,
      ),
    );
  }
}
