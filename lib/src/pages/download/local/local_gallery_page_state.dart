import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

import '../../../setting/download_setting.dart';

class LocalGalleryPageState with Scroll2TopStateMixin{

  String currentPath = DownloadSetting.downloadPath.value;

  bool aggregateDirectories = false;
}
