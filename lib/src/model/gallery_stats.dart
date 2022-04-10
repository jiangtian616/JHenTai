class GalleryStats {
  int totalVisits;

  int? allTimeRanking;
  int? allTimeScore;
  int? yearRanking;
  int? yearScore;
  int? monthRanking;
  int? monthScore;
  int? dayRanking;
  int? dayScore;

  List<VisitStat> yearlyStats;
  List<VisitStat> monthlyStats;
  List<VisitStat> dailyStats;

  GalleryStats({
    required this.totalVisits,
    this.allTimeRanking,
    this.allTimeScore,
    this.yearRanking,
    this.yearScore,
    this.monthRanking,
    this.monthScore,
    this.dayRanking,
    this.dayScore,
    required this.yearlyStats,
    required this.monthlyStats,
    required this.dailyStats,
  });
}

class VisitStat {
  /// 1. 2013
  /// 2. January
  /// 3. 1st
  String period;

  /// 1. 16.2M
  /// 2. 570K
  /// 3. 5731
  double visits;

  /// 1. 16.2M
  /// 2. 570K
  /// 3. 5731
  double hits;

  VisitStat({
    required this.period,
    required this.visits,
    required this.hits,
  });
}
