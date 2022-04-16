import 'package:animate_do/animate_do.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_stats.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StatDialog extends StatefulWidget {
  const StatDialog({Key? key}) : super(key: key);

  @override
  State<StatDialog> createState() => _StatDialogState();
}

class _StatDialogState extends State<StatDialog> {
  final DetailsPageLogic logic = DetailsPageLogic.current!;
  final DetailsPageState state = DetailsPageLogic.current!.state;

  late GalleryStats galleryStats;
  LoadingState loadingState = LoadingState.idle;

  String graphType = 'allTime';

  @override
  void initState() {
    _getGalleryStats();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Center(child: Text('VisitorStatistics'.tr)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        LoadingStateIndicator(
          loadingState: loadingState,
          successWidgetBuilder: () => CupertinoSlidingSegmentedControl<String>(
            groupValue: graphType,
            children: {
              'allTime': Text('allTime'.tr).paddingSymmetric(horizontal: 12),
              'year': Text('year'.tr).paddingSymmetric(horizontal: 12),
              'month': Text('month'.tr).paddingSymmetric(horizontal: 12),
              'day': Text('day'.tr).paddingSymmetric(horizontal: 12),
            },
            onValueChanged: (value) {
              setState(() {
                graphType = value!;
              });
            },
          ).marginSymmetric(horizontal: 24),
          errorTapCallback: _getGalleryStats,
          noDataWidget: Text('invisible2UserWithoutDonation'.tr),
          noDataTapCallback: _getGalleryStats,
        ),
        if (loadingState == LoadingState.success && graphType == 'allTime')
          FadeIn(key: const Key('1'), child: _allTimeGraph()).marginOnly(top: 24),
        if (loadingState == LoadingState.success && graphType == 'year')
          FadeIn(key: const Key('2'), child: _lineGraph(galleryStats.yearlyStats)).marginOnly(top: 24),
        if (loadingState == LoadingState.success && graphType == 'month')
          FadeIn(key: const Key('3'), child: _lineGraph(galleryStats.monthlyStats)).marginOnly(top: 24),
        if (loadingState == LoadingState.success && graphType == 'day')
          FadeIn(key: const Key('4'), child: _lineGraph(galleryStats.dailyStats)).marginOnly(top: 24),
      ],
    );
  }

  Future<void> _getGalleryStats() async {
    setState(() {
      loadingState = LoadingState.loading;
    });

    try {
      galleryStats = await EHRequest.requestStatPage(
        gid: state.gallery!.gid,
        token: state.gallery!.token,
        parser: EHSpiderParser.statPage2GalleryStats,
      );
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        Log.info('invisible2UserWithoutDonation'.tr, false);
        setState(() {
          loadingState = LoadingState.noData;
        });
      } else {
        Log.error('getGalleryStatisticsFailed'.tr, e.message);
        snack('getGalleryStatisticsFailed'.tr, e.message, snackPosition: SnackPosition.TOP);
        setState(() {
          loadingState = LoadingState.error;
        });
      }
      return;
    }

    setState(() {
      loadingState = LoadingState.success;
    });
  }

  Widget _allTimeGraph() {
    return Column(
      children: [
        Text(
          '${'totalVisits'.tr}: ${galleryStats.totalVisits}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        DataTable(
          columnSpacing: 40,
          columns: <DataColumn>[
            DataColumn(
              label: SizedBox(width: 50, child: Center(child: Text('period'.tr))),
            ),
            DataColumn(
              label: SizedBox(width: 50, child: Center(child: Text('ranking'.tr))),
            ),
            DataColumn(
              label: SizedBox(width: 50, child: Center(child: Text('score'.tr))),
            ),
          ],
          rows: <DataRow>[
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('allTime'.tr))),
                DataCell(
                  Center(
                    child: Text(galleryStats.allTimeRanking == null ? '-' : '#${galleryStats.allTimeRanking}'),
                  ),
                ),
                DataCell(
                  Center(child: Text(galleryStats.allTimeScore == null ? '-' : galleryStats.allTimeScore.toString())),
                ),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('year'.tr))),
                DataCell(
                  Center(child: Text(galleryStats.yearRanking == null ? '-' : '#${galleryStats.yearRanking}')),
                ),
                DataCell(
                  Center(child: Text(galleryStats.yearScore == null ? '-' : galleryStats.yearScore.toString())),
                ),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('month'.tr))),
                DataCell(
                  Center(child: Text(galleryStats.monthRanking == null ? '-' : '#${galleryStats.monthRanking}')),
                ),
                DataCell(
                  Center(child: Text(galleryStats.monthScore == null ? '-' : galleryStats.monthScore.toString())),
                ),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('day'.tr))),
                DataCell(
                  Center(child: Text(galleryStats.dayRanking == null ? '-' : '#${galleryStats.dayRanking}')),
                ),
                DataCell(
                  Center(child: Text(galleryStats.dayScore == null ? '-' : galleryStats.dayScore.toString())),
                ),
              ],
            ),
          ],
        ).marginOnly(top: 18),
      ],
    );
  }

  Widget _lineGraph(List<VisitStat> datasource) {
    return FadeIn(
      key: Key(datasource.hashCode.toString()),
      child: SizedBox(
        height: 300,
        width: 300,
        child: SfCartesianChart(
          trackballBehavior: TrackballBehavior(
            enable: true,
            activationMode: ActivationMode.singleTap,
            tooltipSettings: const InteractiveTooltip(format: 'point.x: point.y'),
            hideDelay: 1500,
          ),
          primaryXAxis: CategoryAxis(
            tickPosition: TickPosition.inside,
            majorGridLines: const MajorGridLines(width: 0),
            majorTickLines: const MajorTickLines(width: 1, size: 3),
            edgeLabelPlacement: EdgeLabelPlacement.shift,
            labelStyle: const TextStyle(fontSize: 10),
          ),
          primaryYAxis: NumericAxis(
            title: AxisTitle(
              text: 'visits'.tr,
              textStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(75, 135, 185, 1),
              ),
            ),
            tickPosition: TickPosition.inside,
            labelStyle: const TextStyle(fontSize: 10),
            majorTickLines: const MajorTickLines(width: 1, size: 3),
          ),
          axes: <ChartAxis>[
            NumericAxis(
              name: 'imageAccesses',
              opposedPosition: true,
              title: AxisTitle(
                text: 'imageAccesses'.tr,
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(192, 108, 132, 1),
                ),
              ),
              labelStyle: const TextStyle(fontSize: 10),
              majorTickLines: const MajorTickLines(width: 1, size: 3),
            ),
          ],
          legend: Legend(
            isVisible: true,
            position: LegendPosition.bottom,
          ),
          series: <ChartSeries<VisitStat, String>>[
            LineSeries<VisitStat, String>(
              name: 'visits'.tr,
              dataSource: datasource,
              enableTooltip: true,
              animationDuration: 400,
              xValueMapper: (VisitStat stat, _) => stat.period,
              yValueMapper: (VisitStat stat, _) => stat.visits,
              markerSettings: MarkerSettings(
                isVisible: true,
                height: datasource.length < 3 ? 2 : 1,
                width: datasource.length < 3 ? 2 : 1,
              ),
            ),
            LineSeries<VisitStat, String>(
              name: 'imageAccesses'.tr,
              dataSource: datasource,
              enableTooltip: true,
              animationDuration: 400,
              xValueMapper: (VisitStat stat, _) => stat.period,
              yValueMapper: (VisitStat stat, _) => stat.hits,
              yAxisName: 'imageAccesses',
              markerSettings: MarkerSettings(
                isVisible: true,
                height: datasource.length < 3 ? 2 : 1,
                width: datasource.length < 3 ? 2 : 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
