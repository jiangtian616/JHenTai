import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/jh_request.dart';
import 'package:jhentai/src/utils/jh_spider_parser.dart';
import 'package:jhentai/src/service/log.dart';

import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../../../widget/loading_state_indicator.dart';

class SettingCloudPage extends StatefulWidget {
  const SettingCloudPage({super.key});

  @override
  State<SettingCloudPage> createState() => _SettingCloudPageState();
}

class _SettingCloudPageState extends State<SettingCloudPage> {
  LoadingState _loadingState = LoadingState.idle;

  @override
  void initState() {
    _loadingState = LoadingState.loading;

    JHRequest.requestAlive(parser: JHResponseParser.api2Success).then((bool alive) {
      setState(() => _loadingState = alive ? LoadingState.success : LoadingState.error);
    }).catchError((e) {
      log.error('requestAlive error: $e');
      setState(() => _loadingState = LoadingState.error);
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('cloud'.tr)),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          _buildServerCondition(),
          _buildConfigSync(),
        ],
      ).withListTileTheme(context),
    );
  }

  Widget _buildServerCondition() {
    return ListTile(
      title: Text('serverCondition'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _loadingState,
            successWidgetBuilder: () => const Icon(Icons.check, color: Colors.green),
            errorWidgetBuilder: () => const Icon(Icons.close, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSync() {
    return ListTile(
      title: Text('configSync'.tr),
      subtitle: Text('configSyncHint'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.configSync),
    );
  }
}
