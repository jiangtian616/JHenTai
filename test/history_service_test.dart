import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/history_service.dart';

void main() {
  testWidgets('history change notification rebuilds history listeners', (
    WidgetTester tester,
  ) async {
    final HistoryService service = HistoryService();
    Get.put(service, permanent: true);
    addTearDown(Get.reset);

    int buildCount = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        home: GetBuilder<HistoryService>(
          id: HistoryService.historyUpdateId,
          builder: (_) {
            buildCount++;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(buildCount, 1);

    service.notifyHistoryChanged();
    await tester.pump();

    expect(buildCount, 2);
  });
}
