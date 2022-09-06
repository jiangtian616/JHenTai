import 'package:jhentai/src/pages/watched/watched_page_state.dart';

import '../../consts/eh_consts.dart';
import '../../network/eh_request.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/log.dart';
import '../base/base_page_logic.dart';

class WatchedPageLogic extends BasePageLogic {
  @override
  int get tabIndex => 5;

  @override
  bool get autoLoadNeedLogin => true;

  @override
  final WatchedPageState state = WatchedPageState();

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.info('Get watched data, pageIndex:$pageIndex', false);

    return await EHRequest.requestGalleryPage(
      url: EHConsts.EWatched,
      pageNo: pageIndex,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );
  }
}
