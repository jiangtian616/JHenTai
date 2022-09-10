import 'dart:math';

import 'package:get/get.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:resizable_widget/resizable_widget.dart';
import 'package:throttling/throttling.dart';

import '../utils/log.dart';

class WindowService extends GetxService {
  final StorageService storageService = Get.find<StorageService>();

  final Debouncing debouncing = Debouncing(duration: const Duration(milliseconds: 300));
  double leftColumnWidthRatio = 1 - 0.618;

  static void init() {
    Get.put(WindowService(), permanent: true);
  }

  @override
  void onInit() {
    super.onInit();
    leftColumnWidthRatio = storageService.read('leftColumnWidthRatio') ?? leftColumnWidthRatio;
    leftColumnWidthRatio = max(0.01, leftColumnWidthRatio);
  }

  void handleResized(List<WidgetSizeInfo> infoList) {
    if (leftColumnWidthRatio == infoList[0].percentage) {
      return;
    }

    debouncing.debounce(() {
      leftColumnWidthRatio = max(0.01, infoList[0].percentage);

      Log.info('Resize left column ratio to: $leftColumnWidthRatio');
      storageService.write('leftColumnWidthRatio', leftColumnWidthRatio);
    });
  }
}
