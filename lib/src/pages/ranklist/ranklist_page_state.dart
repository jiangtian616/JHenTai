import '../../routes/routes.dart';
import '../base/old_base_page_state.dart';

enum RanklistType {
  allTime,
  year,
  month,
  day,
}

class RanklistPageState extends OldBasePageState {
  @override
  String get route => Routes.ranklist;

  RanklistType ranklistType = RanklistType.day;
}
