import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/tap_zone_config.dart';
import 'package:jhentai/src/setting/read_setting.dart';

/// One-time semi-transparent overlay that depicts the current tap zone grid.
/// The grid fills the whole screen and matches the real gesture regions.
/// Any tap dismisses it.
class TapZoneGuideOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const TapZoneGuideOverlay({super.key, required this.onDismiss});

  static Color actionColor(TapZoneAction action) => switch (action) {
        TapZoneAction.none => Colors.grey,
        TapZoneAction.prevPage => Colors.blue,
        TapZoneAction.nextPage => Colors.green,
        TapZoneAction.toggleMenu => Colors.orange,
        TapZoneAction.flipLeft => Colors.blue,
        TapZoneAction.flipRight => Colors.green,
      };

  @override
  Widget build(BuildContext context) {
    TapZoneConfig config = readSetting.tapZoneConfig;
    List<int> columnFlex = [
      config.leftColumnWidthRatio,
      config.middleColumnWidthRatio,
      config.rightColumnWidthRatio,
    ];
    List<int> rowFlex = [
      config.topRowHeightRatio,
      config.middleRowHeightRatio,
      config.bottomRowHeightRatio,
    ];

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: Colors.black54,
          child: Stack(
            children: [
              Column(
                children: [
                  for (int row = 0; row < 3; row++)
                    Expanded(
                      flex: rowFlex[row],
                      child: Row(
                        children: [
                          for (int col = 0; col < 3; col++)
                            Expanded(
                              flex: columnFlex[col],
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: actionColor(config.actions[row * 3 + col]).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white30),
                                ),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  config.actions[row * 3 + col].i18nKey.tr,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'tapZoneGuideHint'.tr,
                        style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
