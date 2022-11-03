import '../base/old_base_page_state.dart';

enum RanklistType {
  allTime,
  year,
  month,
  day,
}

class RanklistPageState extends OldBasePageState {
  RanklistType ranklistType = RanklistType.day;
}
