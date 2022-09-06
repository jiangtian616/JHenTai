import '../../consts/eh_consts.dart';
import '../../network/eh_request.dart';
import '../../utils/eh_spider_parser.dart';
import '../../utils/log.dart';
import '../base/base_page_logic.dart';
import 'popular_page_state.dart';

class PopularPageLogic extends BasePageLogic {
  @override
  int get tabIndex => 2;

  @override
  final PopularPageState state = PopularPageState();

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    Log.info('Get popular data, pageIndex:$pageIndex', false);

    List<dynamic> gallerysAndPageInfo = await EHRequest.requestGalleryPage(
      pageNo: pageIndex,
      url: EHConsts.EPopular,
      parser: EHSpiderParser.galleryPage2GalleryListAndPageInfo,
    );
    gallerysAndPageInfo[1] = 1;

    return gallerysAndPageInfo;
  }
}
