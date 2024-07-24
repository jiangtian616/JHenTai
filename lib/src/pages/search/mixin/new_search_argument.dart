import '../../../model/search_config.dart';
import '../../../setting/preference_setting.dart';

class NewSearchArgument {
  final String? keyword;
  final SearchBehaviour? keywordSearchBehaviour;

  final SearchConfig? rewriteSearchConfig;
  
  final bool loadImmediately;

  const NewSearchArgument({
    this.keyword,
    this.keywordSearchBehaviour,
    this.rewriteSearchConfig,
    required this.loadImmediately,
  }) : assert((keywordSearchBehaviour != null) || rewriteSearchConfig != null);
}