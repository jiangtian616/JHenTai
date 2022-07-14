import '../../consts/eh_consts.dart';
import '../../network/eh_request.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/log.dart';
import '../base/base_page_logic.dart';
import 'popular_page_state.dart';

class PopularPageLogic extends BasePageLogic {
  @override
  final String pageId = 'pageId';
  @override
  final String appBarId = 'appBarId';
  @override
  final String bodyId = 'bodyId';
  @override
  final String refreshStateId = 'refreshStateId';
  @override
  final String loadingStateId = 'loadingStateId';

  @override
  int get tabIndex => 2;

  @override
  final PopularPageState state = PopularPageState();

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageNo) async {
    Log.info('Get popular data, pageNo:$pageNo', false);

    List<dynamic> gallerysAndPageInfo = await EHRequest.requestGalleryPage(
      pageNo: pageNo,
      url: EHConsts.EPopular,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );
    gallerysAndPageInfo[1] = 1;

    await translateGalleryTagsIfNeeded(gallerysAndPageInfo[0]);
    return gallerysAndPageInfo;
  }
}
