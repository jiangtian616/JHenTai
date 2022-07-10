import '../../consts/eh_consts.dart';
import '../../network/eh_request.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/log.dart';
import '../gallerys/base/page_logic_base.dart';
import 'popular_page_state.dart';

class PopularPageLogic extends LogicBase {
  @override
  final String appBarId = 'appBarId';
  @override
  final String bodyId = 'bodyId';
  @override
  final String refreshStateId = 'refreshStateId';
  @override
  final String loadingStateId = 'loadingStateId';

  @override
  final PopularPageState state = PopularPageState();

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
