import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:retry/retry.dart';

import '../../../../exception/eh_exception.dart';
import '../../../../model/profile.dart';
import '../../../../network/eh_cookie_manager.dart';
import '../../../../network/eh_request.dart';
import '../../../../setting/site_setting.dart';
import '../../../../utils/eh_spider_parser.dart';
import '../../../../utils/log.dart';

class SettingEHProfilePage extends StatefulWidget {
  const SettingEHProfilePage({super.key});

  @override
  State<SettingEHProfilePage> createState() => _SettingEHProfilePageState();
}

class _SettingEHProfilePageState extends State<SettingEHProfilePage> {
  LoadingState loadingState = LoadingState.idle;
  late List<Profile> profiles;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('profileSetting'.tr)),
      body: _buildProfile(),
    );
  }

  Widget _buildProfile() {
    if (loadingState != LoadingState.success) {
      return LoadingStateIndicator(loadingState: loadingState, errorTapCallback: _loadProfile);
    }

    int number = profiles.firstWhere((p) => p.selected).number;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          ListTile(
            title: Text('selectedProfile'.tr),
            subtitle: Text('resetIfSwitchSite'.tr),
            trailing: DropdownButton<int>(
              value: number,
              elevation: 4,
              alignment: AlignmentDirectional.centerEnd,
              onChanged: (int? newValue) {
                EHRequest.storeEHCookies([Cookie('sp', newValue?.toString() ?? '1')]);
                setState(() {
                  for (Profile value in profiles) {
                    value.selected = value.number == newValue;
                  }
                });
              },
              items: profiles
                  .map(
                    (p) => DropdownMenuItem(child: Text(p.name), value: p.number),
                  )
                  .toList(),
            ),
          )
        ],
      ).withListTileTheme(context),
    );
  }

  Future<void> _loadProfile() async {
    if (loadingState == LoadingState.loading) {
      return;
    }

    loadingState = LoadingState.loading;
    ({List<Profile> profiles, FrontPageDisplayType frontPageDisplayType, bool isLargeThumbnail, int thumbnailRows}) settings;
    try {
      settings = await retry(
        () => EHRequest.requestSettingPage(EHSpiderParser.settingPage2SiteSetting),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } on DioException catch (e) {
      Log.error('Load profile fail', e.message);
      setState(() {
        loadingState = LoadingState.error;
      });
      return;
    } on EHException catch (e) {
      Log.error('Load profile fail', e.message);
      setState(() {
        loadingState = LoadingState.error;
      });
      return;
    }

    setState(() {
      profiles = settings.profiles;
      loadingState = LoadingState.success;
    });
  }
}
