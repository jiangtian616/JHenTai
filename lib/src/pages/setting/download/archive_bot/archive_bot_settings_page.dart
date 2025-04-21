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
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/widget/eh_archive_bot_setting_dialog.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../model/archive_bot_response/archive_bot_response.dart';
import '../../../../setting/preference_setting.dart';

class ArchiveBotSettingsPage extends StatefulWidget {
  const ArchiveBotSettingsPage({Key? key}) : super(key: key);

  @override
  State<ArchiveBotSettingsPage> createState() => _ArchiveBotSettingsPageState();
}

class _ArchiveBotSettingsPageState extends State<ArchiveBotSettingsPage> {
  LoadingState _balanceState = LoadingState.idle;
  LoadingState _checkinState = LoadingState.idle;

  final RxnInt _balance = RxnInt(null);

  @override
  void initState() {
    super.initState();

    if (archiveBotSetting.isReady) {
      _checkBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('archiveBotSettings'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () {
              launchUrlString(
                preferenceSetting.locale.value.languageCode == 'zh'
                    ? 'https://github.com/jiangtian616/JHenTai/wiki/%E5%BD%92%E6%A1%A3%E6%9C%BA%E5%99%A8%E4%BA%BA%E4%BD%BF%E7%94%A8%E6%96%B9%E6%B3%95'
                    : 'https://github.com/jiangtian616/JHenTai/wiki/Archive-Bot-Usage',
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          _buildApiKeySetting(),
          if (archiveBotSetting.isReady) _buildBalance(),
          if (archiveBotSetting.isReady) _buildCheckin(),
        ],
      ).withListTileTheme(context),
    );
  }

  Widget _buildApiKeySetting() {
    return ListTile(
      title: Text('apiSetting'.tr),
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

  Widget _buildUseProxyServer() {
    return SwitchListTile(
      title: Text('useProxyServer'.tr),
      subtitle: Text('useProxyServerHint'.tr),
      value: archiveBotSetting.useProxyServer.value,
      onChanged: (bool value) async {
        await archiveBotSetting.saveUseProxyServer(value);
        setStateSafely(() {});
      },
    );
  }

  Future<void> _showApiKeyDialog() async {
    bool? result = await showDialog(
      context: context,
      builder: (_) => EHArchiveBotSettingDialog(
        apiAddress: archiveBotSetting.apiAddress.value,
        apiKey: archiveBotSetting.apiKey.value,
        useProxy: archiveBotSetting.useProxyServer.value,
      ),
    );

    if (result == true) {
      setStateSafely(() {
        _checkBalance();
      });
    }
  }

  Future<void> _checkBalance() async {
    if (_balanceState == LoadingState.loading) {
      return;
    }
    if (!archiveBotSetting.isReady) {
      return;
    }

    setStateSafely(() => _balanceState = LoadingState.loading);

    try {
      ArchiveBotResponse response = await archiveBotRequest.requestBalance(
        apiAddress: archiveBotSetting.apiAddress.value,
        apiKey: archiveBotSetting.apiKey.value!,
        parser: ArchiveBotResponseParser.commonParse,
      );
      log.info('Check balance response: $response');

      if (response.isSuccess) {
        setStateSafely(() {
          _balanceState = LoadingState.success;
          _balance.value = BalanceVO.fromResponse(response.data).gp;
        });
      } else {
        snack('checkBalanceFailed'.tr, response.errorMessage);
        setStateSafely(() => _balanceState = LoadingState.error);
      }
    } on DioException catch (e) {
      log.error('Failed to check balance', e.errorMsg, e.stackTrace);
      snack('checkBalanceFailed'.tr, e.errorMsg ?? '');
      setStateSafely(() => _balanceState = LoadingState.error);
    } catch (e) {
      log.error('Failed to check balance', e.toString(), StackTrace.current);
      snack('checkBalanceFailed'.tr, e.toString());
      setStateSafely(() => _balanceState = LoadingState.error);
    }
  }

  Future<void> _checkin() async {
    if (_checkinState == LoadingState.loading) {
      return;
    }
    if (!archiveBotSetting.isReady) {
      return;
    }

    setStateSafely(() => _checkinState = LoadingState.loading);

    try {
      ArchiveBotResponse response = await archiveBotRequest.requestCheckIn(
        apiAddress: archiveBotSetting.apiAddress.value,
        apiKey: archiveBotSetting.apiKey.value!,
        parser: ArchiveBotResponseParser.commonParse,
      );
      log.info('Checkin response: $response');
      if (response.isSuccess) {
        CheckInVO checkInVO = CheckInVO.fromResponse(response.data);
        setStateSafely(() {
          _checkinState = LoadingState.success;
          _balance.value = checkInVO.currentGP;
        });
        snack('checkInSuccess'.tr, 'checkInSuccessHint'.trArgs([checkInVO.getGP.toString(), checkInVO.currentGP.toString()]));
      } else {
        snack('checkInFailed'.tr, response.errorMessage);
        setStateSafely(() => _checkinState = LoadingState.error);
      }
    } on DioException catch (e) {
      log.error('Failed to checkin', e.errorMsg, e.stackTrace);
      snack('checkInFailed'.tr, e.errorMsg ?? '');
      setStateSafely(() => _checkinState = LoadingState.error);
    } catch (e) {
      log.error('Failed to checkin', e.toString(), StackTrace.current);
      snack('checkInFailed'.tr, e.toString());
      setStateSafely(() => _checkinState = LoadingState.error);
    }
  }
}
