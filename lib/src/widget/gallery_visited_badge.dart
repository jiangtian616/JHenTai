import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../service/history_service.dart';

class GalleryVisitedBadge extends StatelessWidget {
  final int gid;

  const GalleryVisitedBadge({
    Key? key,
    required this.gid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HistoryService>(
      init: Get.find<HistoryService>(),
      id: '${HistoryService.historyUpdateId}::$gid',
      builder: (_) {
        return FutureBuilder<bool>(
          future: historyService.hasVisited(gid),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.data != true) {
              return const SizedBox.shrink();
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade700.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 10),
                  const SizedBox(width: 2),
                  Text(
                    'opened'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
