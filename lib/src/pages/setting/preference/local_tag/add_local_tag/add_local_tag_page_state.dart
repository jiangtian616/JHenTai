import 'package:throttling/throttling.dart';

import '../../../../../database/database.dart';
import '../../../../../widget/loading_state_indicator.dart';

class AddLocalTagPageState {
  String? keyword;
  List<TagData> tags = [];

  final Debouncing searchDebouncing = Debouncing(duration: const Duration(milliseconds: 300));
  LoadingState searchLoadingState = LoadingState.idle;
}
