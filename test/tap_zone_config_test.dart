import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/model/tap_zone_config.dart';

void main() {
  test('normalizes out-of-range ratios so derived segments stay >= 1', () {
    TapZoneConfig config = TapZoneConfig(
      actions: TapZoneConfig.classic().actions,
      leftColumnWidthRatio: 98,
      middleColumnWidthRatio: 60,
      topRowHeightRatio: 99,
      middleRowHeightRatio: 99,
    );
    expect(config.leftColumnWidthRatio, 98);
    expect(config.middleColumnWidthRatio, 1);
    expect(config.rightColumnWidthRatio, 1);
    expect(config.topRowHeightRatio, 98);
    expect(config.middleRowHeightRatio, 1);
    expect(config.bottomRowHeightRatio, 1);
  });

  test('json round-trip preserves normalized config', () {
    TapZoneConfig config = TapZoneConfig.fromJsonString(
      '{"actions":[0,3,2,0,3,2,0,3,2],"leftColumnWidthRatio":50,"middleColumnWidthRatio":49,"topRowHeightRatio":10,"middleRowHeightRatio":80}',
    );
    expect(config.rightColumnWidthRatio, 1);
    expect(config.bottomRowHeightRatio, 10);
    expect(TapZoneConfig.fromJsonString(config.toJsonString()), config);
  });
}
