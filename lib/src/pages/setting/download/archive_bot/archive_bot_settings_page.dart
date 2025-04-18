import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/response/archive_bot_response.dart';
import 'package:jhentai/src/network/archive_bot_request.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/utils/archive_bot_response_parser.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class ArchiveBotSettingsPage extends StatefulWidget {
  const ArchiveBotSettingsPage({Key? key}) : super(key: key);

  @override
  State<ArchiveBotSettingsPage> createState() => _ArchiveBotSettingsPageState();
}

class _ArchiveBotSettingsPageState extends State<ArchiveBotSettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  LoadingState _balanceState = LoadingState.idle;
  LoadingState _checkinState = LoadingState.idle;

  final RxnInt _balance = RxnInt(null);

  @override
  void initState() {
    super.initState();

    _apiKeyController.text = archiveBotSetting.apiKey.value ?? '';
    _checkBalance();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('archiveBotSettings'.tr)),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          _buildApiKeySetting(),
          _buildBalance(),
          _buildCheckin(),
        ],
      ).withListTileTheme(context),
    );
  }

  Widget _buildApiKeySetting() {
    return ListTile(
      title: Text('apiKey'.tr),
      subtitle: Text(archiveBotSetting.apiKey.value == null ? 'apiKeyHint'.tr : archiveBotSetting.apiKey.value.toString()),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _showApiKeyDialog,
    );
  }

  Widget _buildBalance() {
    return ListTile(
      title: Text('currentBalance'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _balanceState,
            useCupertinoIndicator: true,
            successWidgetBuilder: () => Text(_balance.value == null ? '' : '${_balance.value} GP'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckin() {
    return ListTile(
      title: Text('dailyCheckin'.tr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            loadingState: _checkinState,
            useCupertinoIndicator: true,
            idleWidgetBuilder: () => const Icon(Icons.keyboard_arrow_right),
            successWidgetBuilder: () => const Icon(Icons.check_circle_outline),
          ),
        ],
      ),
      onTap: _handleCheckin,
    );
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('apiKey'.tr),
        content: TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            constraints: const BoxConstraints(minWidth: 400),
            suffixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(child: const Icon(Icons.cancel), onTap: _apiKeyController.clear),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              backRoute();

              setState(() {
                archiveBotSetting.saveApiKey(_apiKeyController.text.isEmpty ? null : _apiKeyController.text);
              });
              if (_apiKeyController.text.isNotEmpty) {
                _checkBalance();
              }
            },
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _checkBalance() async {
    if (_balanceState == LoadingState.loading) {
      return;
    }

    setState(() => _balanceState = LoadingState.loading);

    try {
      ArchiveBotResponse<int?> response =
          await archiveBotRequest.requestBalance(apiKey: archiveBotSetting.apiKey.value ?? 'checkAlive', parser: ArchiveBotResponseParser.commonParse<int?>);
      log.info('Check balance response: $response');

      if (response.code == 0) {
        setState(() => _balanceState = LoadingState.success);
        _balance.value = response.data;
      } else {
        ArchiveBotResponseCodeEnum? responseCodeEnum = ArchiveBotResponseCodeEnum.fromCode(response.code);
        toast(responseCodeEnum == null ? 'internalError'.tr : responseCodeEnum.name.tr);

        setState(() => _balanceState = LoadingState.error);
      }
    } on DioException catch (e) {
      log.error('Failed to check balance', e.errorMsg, e.stackTrace);
      setState(() => _balanceState = LoadingState.error);
    } catch (e) {
      log.error('Failed to check balance', e.toString());
      setState(() => _balanceState = LoadingState.error);
    }
  }

  Future<void> _handleCheckin() async {
    if (_checkinState == LoadingState.loading) {
      return;
    }

    setState(() => _checkinState = LoadingState.loading);

    try {
      ArchiveBotResponse<String?> response =
          await archiveBotRequest.requestCheckIn(apiKey: archiveBotSetting.apiKey.value ?? '', parser: ArchiveBotResponseParser.commonParse<String?>);
      log.info('Checkin response: $response');
      setState(() => _checkinState = LoadingState.success);
    } on DioException catch (e) {
      log.error('Failed to checkin', e.errorMsg, e.stackTrace);
      setState(() => _checkinState = LoadingState.error);
    } catch (e) {
      log.error('Failed to checkin', e.toString());
      setState(() => _checkinState = LoadingState.error);
    }
  }
}
