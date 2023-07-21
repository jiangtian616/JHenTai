import '../../../routes/routes.dart';
import '../../base/base_page_state.dart';
import '../mixin/search_page_state_mixin.dart';

class SearchPageMobileV2State extends BasePageState with SearchPageStateMixin {
  @override
  String get route => Routes.mobileV2Search;
}
