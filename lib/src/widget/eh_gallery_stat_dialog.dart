import 'package:animate_do/animate_do.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_stats.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../exception/eh_exception.dart';

enum GraphType { allTime, year, month, day }

class EHGalleryStatDialog extends StatefulWidget {
  final int gid;
  final String token;

  const EHGalleryStatDialog({Key? key, required this.gid, required this.token}) : super(key: key);

  @override
  State<EHGalleryStatDialog> createState() => _EHGalleryStatDialogState();
}

class _EHGalleryStatDialogState extends State<EHGalleryStatDialog> {
  late GalleryStats galleryStats;
  LoadingState loadingState = LoadingState.idle;

  GraphType graphType = GraphType.allTime;

  @override
  void initState() {
    _getGalleryStats();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Center(child: Text('VisitorStatistics'.tr)),
      children: [
        LoadingStateIndicator(
          loadingState: loadingState,
          successWidgetBuilder: () => Column(
            children: [
              _buildSegmentedControl().marginOnly(bottom: 24),
              if (graphType == GraphType.allTime) FadeIn(key: const Key('1'), child: _AllTimeTable(galleryStats: galleryStats)),
              if (graphType == GraphType.year) FadeIn(key: const Key('2'), child: _LineGraph(datasource: galleryStats.yearlyStats)),
              if (graphType == GraphType.month) FadeIn(key: const Key('3'), child: _LineGraph(datasource: galleryStats.monthlyStats)),
              if (graphType == GraphType.day) FadeIn(key: const Key('4'), child: _LineGraph(datasource: galleryStats.dailyStats)),
            ],
          ),
          errorTapCallback: _getGalleryStats,
          noDataWidget: Text('invisible2UserWithoutDonation'.tr),
          noDataTapCallback: _getGalleryStats,
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    return CupertinoSlidingSegmentedControl<GraphType>(
      groupValue: graphType,
      children: {
        GraphType.allTime: Text('allTime'.tr).paddingSymmetric(horizontal: 12),
        GraphType.year: Text('year'.tr).paddingSymmetric(horizontal: 12),
        GraphType.month: Text('month'.tr).paddingSymmetric(horizontal: 12),
        GraphType.day: Text('day'.tr).paddingSymmetric(horizontal: 12),
      },
      onValueChanged: (value) => setState(() => graphType = value!),
    );
  }

  Future<void> _getGalleryStats() async {
    setState(() {
      loadingState = LoadingState.loading;
    });

    try {
      galleryStats = await EHRequest.requestStatPage(
        gid: widget.gid,
        token: widget.token,
        parser: EHSpiderParser.statPage2GalleryStats,
      );
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        Log.info('invisible2UserWithoutDonation'.tr);
        if (mounted) {
          setState(() => loadingState = LoadingState.noData);
        }
        return;
      }

      Log.error('getGalleryStatisticsFailed'.tr, e.message);
      snack('getGalleryStatisticsFailed'.tr, e.message);
      setStateSafely(() => loadingState = LoadingState.error);

      return;
    } on EHException catch (e) {
      Log.error('getGalleryStatisticsFailed'.tr, e.message);
      snack('getGalleryStatisticsFailed'.tr, e.message);
      setStateSafely(() => loadingState = LoadingState.error);
      return;
    }

    if (mounted) {
      setState(() {
        loadingState = LoadingState.success;
      });
    }
  }
}

class _AllTimeTable extends StatelessWidget {
  final GalleryStats galleryStats;

  const _AllTimeTable({Key? key, required this.galleryStats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${'totalVisits'.tr}: ${galleryStats.totalVisits}', style: const TextStyle(fontWeight: FontWeight.bold)),
        DataTable(
          columnSpacing: UIConfig.statisticsDialogColumnSpacing,
          columns: <DataColumn>[
            DataColumn(
              label: SizedBox(width: UIConfig.statisticsDialogColumnWidth, child: Center(child: Text('period'.tr))),
            ),
            DataColumn(
              label: SizedBox(width: UIConfig.statisticsDialogColumnWidth, child: Center(child: Text('ranking'.tr))),
            ),
            DataColumn(
              label: SizedBox(width: UIConfig.statisticsDialogColumnWidth, child: Center(child: Text('score'.tr))),
            ),
          ],
          rows: <DataRow>[
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('allTime'.tr))),
                DataCell(Center(child: Text(galleryStats.allTimeRanking == null ? '-' : '#${galleryStats.allTimeRanking}'))),
                DataCell(Center(child: Text(galleryStats.allTimeScore == null ? '-' : galleryStats.allTimeScore.toString()))),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('year'.tr))),
                DataCell(Center(child: Text(galleryStats.yearRanking == null ? '-' : '#${galleryStats.yearRanking}'))),
                DataCell(Center(child: Text(galleryStats.yearScore == null ? '-' : galleryStats.yearScore.toString()))),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('month'.tr))),
                DataCell(Center(child: Text(galleryStats.monthRanking == null ? '-' : '#${galleryStats.monthRanking}'))),
                DataCell(Center(child: Text(galleryStats.monthScore == null ? '-' : galleryStats.monthScore.toString()))),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Center(child: Text('day'.tr))),
                DataCell(Center(child: Text(galleryStats.dayRanking == null ? '-' : '#${galleryStats.dayRanking}'))),
                DataCell(Center(child: Text(galleryStats.dayScore == null ? '-' : galleryStats.dayScore.toString()))),
              ],
            ),
          ],
        ).marginOnly(top: 4),
      ],
    );
  }
}

class _LineGraph extends StatelessWidget {
  final List<VisitStat> datasource;

  const _LineGraph({Key? key, required this.datasource}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      child: SizedBox(
        height: UIConfig.statisticsDialogGraphHeight,
        width: UIConfig.statisticsDialogGraphWidth,
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
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color.fromRGBO(75, 135, 185, 1)),
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
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color.fromRGBO(192, 108, 132, 1)),
              ),
              labelStyle: const TextStyle(fontSize: 10),
              majorTickLines: const MajorTickLines(width: 1, size: 3),
            ),
          ],
          legend: Legend(isVisible: true, position: LegendPosition.bottom),
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
