import '../../../model/search_config.dart';
import '../../../setting/preference_setting.dart';

class NewSearchArgument {
  final String? keyword;
  final SearchBehaviour? keywordSearchBehaviour;

  final SearchConfig? rewriteSearchConfig;

  const NewSearchArgument({
    this.keyword,
    this.keywordSearchBehaviour,
    this.rewriteSearchConfig,
  }) : assert((keyword != null && keywordSearchBehaviour != null) || rewriteSearchConfig != null);
}
