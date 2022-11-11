import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:resizable_widget/resizable_widget.dart';

import '../service/windows_service.dart';
import '../widget/eh_separator.dart';

mixin DoubleColumnWidgetMixin on StatelessWidget {
  final WindowService windowService = Get.find<WindowService>();

  Widget buildDoubleColumnWidget(Widget leftColumn, Widget rightColumn) {
    return ColoredBox(
      color: Get.theme.colorScheme.background,
      child: ResizableWidget(
        separatorSize: 7.5,
        separatorColor: Get.theme.colorScheme.onBackground.withOpacity(0.5),
        separatorBuilder: (SeparatorArgsInfo info, SeparatorController controller) => EHSeparator(info: info, controller: controller),
        percentages: [windowService.leftColumnWidthRatio, 1 - windowService.leftColumnWidthRatio],
        onResized: windowService.handleResized,
        isDisabledSmartHide: true,
        children: [leftColumn, rightColumn],
      ),
    );
  }
}
