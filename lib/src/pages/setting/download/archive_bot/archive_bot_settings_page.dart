import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/archive_bot_response/balance_vo.dart';
import 'package:jhentai/src/model/archive_bot_response/check_in_vo.dart';
import 'package:jhentai/src/network/archive_bot_request.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/utils/archive_bot_response_parser.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../model/archive_bot_response/archive_bot_response.dart';

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

    if (archiveBotSetting.apiKey.value != null) {
      _apiKeyController.text = archiveBotSetting.apiKey.value!;
      _checkBalance();
    }
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
          if (archiveBotSetting.apiKey.value != null) _buildBalance(),
          if (archiveBotSetting.apiKey.value != null) _buildCheckin(),
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
            errorWidgetBuilder: () => const Icon(Icons.error_outline),
          ),
        ],
      ),
      onTap: _checkBalance,
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
            errorWidgetBuilder: () => const Icon(Icons.error_outline),
          ),
        ],
      ),
      onTap: _checkin,
    );
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('apiKey'.tr),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: TextField(
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
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                String? text = (await Clipboard.getData('text/plain'))?.text?.toString();
                if (text != null) {
                  _apiKeyController.text = text;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              backRoute();

              setState(() {
                archiveBotSetting.saveApiKey(_apiKeyController.text.isBlank! ? null : _apiKeyController.text);
                if (!_apiKeyController.text.isBlank!) {
                  _checkBalance();
                }
              });
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
    if (archiveBotSetting.apiKey.value == null) {
      return;
    }

    setState(() => _balanceState = LoadingState.loading);

    try {
      ArchiveBotResponse response =
          await archiveBotRequest.requestBalance(apiKey: archiveBotSetting.apiKey.value!, parser: ArchiveBotResponseParser.commonParse);
      log.info('Check balance response: $response');

      if (response.isSuccess) {
        setState(() {
          _balanceState = LoadingState.success;
          _balance.value = BalanceVO.fromResponse(response.data).gp;
        });
      } else {
        snack('checkBalanceFailed'.tr, response.errorMessage);
        setState(() => _balanceState = LoadingState.error);
      }
    } on DioException catch (e) {
      log.error('Failed to check balance', e.errorMsg, e.stackTrace);
      snack('checkBalanceFailed'.tr, e.errorMsg ?? '');
      setState(() => _balanceState = LoadingState.error);
    } catch (e) {
      log.error('Failed to check balance', e.toString(), StackTrace.current);
      snack('checkBalanceFailed'.tr, e.toString());
      setState(() => _balanceState = LoadingState.error);
    }
  }

  Future<void> _checkin() async {
    if (_checkinState == LoadingState.loading) {
      return;
    }

    setState(() => _checkinState = LoadingState.loading);

    try {
      ArchiveBotResponse response =
          await archiveBotRequest.requestCheckIn(apiKey: archiveBotSetting.apiKey.value ?? '', parser: ArchiveBotResponseParser.commonParse);
      log.info('Checkin response: $response');
      if (response.isSuccess) {
        CheckInVO checkInVO = CheckInVO.fromResponse(response.data);
        setState(() {
          _checkinState = LoadingState.success;
          _balance.value = checkInVO.currentGP;
        });
        snack('checkInSuccess'.tr, 'checkInSuccessHint'.trArgs([checkInVO.getGP.toString(), checkInVO.currentGP.toString()]));
      } else {
        snack('checkInFailed'.tr, response.errorMessage);
        setState(() => _checkinState = LoadingState.error);
      }
    } on DioException catch (e) {
      log.error('Failed to checkin', e.errorMsg, e.stackTrace);
      snack('checkInFailed'.tr, e.errorMsg ?? '');
      setState(() => _checkinState = LoadingState.error);
    } catch (e) {
      log.error('Failed to checkin', e.toString(), StackTrace.current);
      snack('checkInFailed'.tr, e.toString());
      setState(() => _checkinState = LoadingState.error);
    }
  }
}
