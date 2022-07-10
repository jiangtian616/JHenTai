import 'dart:ui';

import 'package:clipboard/clipboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../consts/eh_consts.dart';
import '../../../model/gallery.dart';
import '../../../model/search_config.dart';
import '../../../network/eh_request.dart';
import '../../../routes/routes.dart';
import '../../../service/history_service.dart';
import '../../../service/storage_service.dart';
import '../../../service/tag_translation_service.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/log.dart';
import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/app_state_listener.dart';
import '../../../widget/loading_state_indicator.dart';
import '../base/page_logic_base.dart';
import 'gallerys_page_state.dart';

class GallerysPageLogic extends LogicBase {
  @override
  final String appBarId = 'appBarId';
  @override
  final String bodyId = 'bodyId';
  @override
  final String refreshStateId = 'refreshStateId';
  @override
  final String loadingStateId = 'loadingStateId';

  @override
  final GallerysPageState state = GallerysPageState();

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageNo) async {
    Log.info('get gallery data, pageNo:$pageNo', false);

    List<dynamic> gallerysAndPageInfo = await EHRequest.requestGalleryPage(
      pageNo: pageNo,
      url: EHConsts.EIndex,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    return gallerysAndPageInfo;
  }
}
