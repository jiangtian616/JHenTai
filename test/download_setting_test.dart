import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/setting/download_setting.dart';

void main() {
  test('recent gallery groups can be disabled', () {
    DownloadSetting setting = DownloadSetting();
    setting.recentGalleryGroups = ['recent', 'older'];

    expect(setting.preferredGalleryGroups, ['recent', 'older']);

    setting.prioritizeRecentGalleryGroups.value = false;
    expect(setting.preferredGalleryGroups, isEmpty);
  });
}
