import 'package:flutter/cupertino.dart';

import '../../../setting/download_setting.dart';

class LocalGalleryPageState {

  String currentPath = DownloadSetting.downloadPath.value;

  bool aggregateDirectories = false;

  final ScrollController scrollController = ScrollController();
}
