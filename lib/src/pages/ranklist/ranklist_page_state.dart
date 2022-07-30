import '../base/base_page_state.dart';

enum RanklistType {
  allTime,
  year,
  month,
  day,
}

class RanklistPageState extends BasePageState {
  RanklistType ranklistType = RanklistType.day;
}
