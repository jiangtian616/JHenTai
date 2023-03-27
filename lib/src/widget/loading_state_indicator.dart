import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

import '../config/ui_config.dart';

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

/// A widget that change itself when [loadingState] changes
class LoadingStateIndicator extends StatelessWidget {
  final double? height;
  final double? width;
  final LoadingState loadingState;
  final ErrorTapCallback? errorTapCallback;
  final NoDataTapCallback? noDataTapCallback;
  final bool useCupertinoIndicator;
  final double indicatorRadius;
  final Color? indicatorColor;
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
    this.useCupertinoIndicator = false,
    this.indicatorRadius = 12,
    this.indicatorColor,
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
            (useCupertinoIndicator
                ? CupertinoActivityIndicator(radius: indicatorRadius, color: indicatorColor)
                : Center(child: UIConfig.loadingAnimation(context)));
        break;
      case LoadingState.error:
        child = errorWidget ??
            (errorWidgetSameWithIdle
                ? idleWidget!
                : GestureDetector(
                    onTap: errorTapCallback,
                    child: Icon(FontAwesomeIcons.redoAlt, size: indicatorRadius * 2, color: UIConfig.loadingStateIndicatorButtonColor(context)),
                  ));
        break;
      case LoadingState.idle:
        child = idleWidget ??
            (useCupertinoIndicator
                ? CupertinoActivityIndicator(radius: indicatorRadius, color: indicatorColor)
                : Center(child: UIConfig.loadingAnimation(context)));
        break;
      case LoadingState.noMore:
        child = noMoreWidget ?? Text('noMoreData'.tr, style: TextStyle(color: UIConfig.loadingStateIndicatorButtonColor(context)));
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
          child: noDataWidget ?? Text('noData'.tr, style: TextStyle(color: UIConfig.loadingStateIndicatorButtonColor(context))),
        );
        break;
    }

    return Center(
      child: SizedBox(height: height, width: width, child: child),
    );
  }
}
