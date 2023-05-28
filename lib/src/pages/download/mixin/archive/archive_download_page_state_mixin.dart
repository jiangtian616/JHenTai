import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/mixin/scroll_to_top_state_mixin.dart';

import '../../../../database/database.dart';
import '../../../../model/gallery_image.dart';
import '../../../../model/read_page_info.dart';
import '../../../../routes/routes.dart';
import '../../../../service/archive_download_service.dart';
import '../../../../service/storage_service.dart';
import '../../../../service/super_resolution_service.dart';
import '../../../../setting/read_setting.dart';
import '../../../../setting/super_resolution_setting.dart';
import '../../../../utils/process_util.dart';
import '../../../../utils/route_util.dart';
import '../../../../widget/eh_alert_dialog.dart';
import '../../../../widget/eh_download_dialog.dart';
import '../../../../widget/re_unlock_dialog.dart';
import '../basic/multi_select/multi_select_download_page_logic_mixin.dart';
import '../basic/multi_select/multi_select_download_page_state_mixin.dart';

mixin ArchiveDownloadPageStateMixin implements Scroll2TopStateMixin, MultiSelectDownloadPageStateMixin {}
