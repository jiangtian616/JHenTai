import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../service/read_progress_service.dart';

class ReadProgressBadge extends StatelessWidget {
  final String recordKey;
  final int? pageCount;

  const ReadProgressBadge({
    Key? key,
    required this.recordKey,
    required this.pageCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (pageCount == null || pageCount! <= 0) {
      return const SizedBox.shrink();
    }

    return GetBuilder<ReadProgressService>(
      init: Get.find<ReadProgressService>(),
      id: '${ReadProgressService.readProgressUpdateId}::$recordKey',
      builder: (_) {
        return FutureBuilder<int?>(
          future: readProgressService.getReadProgressByKey(recordKey),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }

            if (snapshot.data == null || snapshot.data! <= 0) {
              return _buildStatusBadge(Icons.radio_button_unchecked, Colors.redAccent);
            }

            final readIndex = snapshot.data!.clamp(0, pageCount! - 1);
            final progress = ((readIndex + 1) / pageCount!).clamp(0.0, 1.0);
            if (progress > 0.9) {
              return _buildStatusBadge(Icons.check_circle, Colors.greenAccent);
            }

            final percent = (progress * 100).ceil();

            return Container(
              constraints: const BoxConstraints(minWidth: 30),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$percent%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(IconData icon, Color color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 16),
    );
  }
}
