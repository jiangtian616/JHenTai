import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/network/eh_cookie_manager.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/utils/string_uril.dart';

import '../../../../consts/eh_consts.dart';
import '../../../../utils/route_util.dart';
import '../../../../utils/toast_util.dart';

class HostMappingPage extends StatelessWidget {
  const HostMappingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('hostMapping'.tr),
        actions: [
          IconButton(onPressed: () => toast('hostDataSource'.tr, isShort: false), icon: const Icon(Icons.help)),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            ListTile(
              title: const Text('e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.eHentaiIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveEHentaiIP(newValue!),
                items: _dropdownMenuItems('e-hentai.org'),
              ),
            ),
            ListTile(
              title: const Text('exhentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.exHentaiIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveEXHentaiIP(newValue!),
                items: _dropdownMenuItems('exhentai.org'),
              ),
            ),
            ListTile(
              title: const Text('upld.e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.upldIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveUpldIP(newValue!),
                items: _dropdownMenuItems('upld.e-hentai.org'),
              ),
            ),
            ListTile(
              title: const Text('api.e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.apiIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveApiIP(newValue!),
                items: _dropdownMenuItems('api.e-hentai.org'),
              ),
            ),
            ListTile(
              title: const Text('forums.e-hentai.org'),
              trailing: DropdownButton<String>(
                value: NetworkSetting.forumsIP.value,
                elevation: 4,
                onChanged: (String? newValue) => NetworkSetting.saveForumsIP(newValue!),
                items: _dropdownMenuItems('forums.e-hentai.org'),
              ),
            ),
          ],
        ).withListTileTheme(context),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(context: context, builder: (_) => const _AddHostMappingDialog());
        },
      ),
    );
  }

  List<DropdownMenuItem<String>> _dropdownMenuItems(String host) {
    return {...NetworkSetting.host2IPs[host]!, NetworkSetting.currentHost2IP[host]!}
        .map((ip) => DropdownMenuItem(
              child: Text(ip),
              value: ip,
            ))
        .toList();
  }
}

class _AddHostMappingDialog extends StatefulWidget {
  const _AddHostMappingDialog({super.key});

  @override
  State<_AddHostMappingDialog> createState() => _AddHostMappingDialogState();
}

class _AddHostMappingDialogState extends State<_AddHostMappingDialog> {
  String _targetHost = NetworkSetting.host2IPs.keys.first;
  String? _targetIp;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(child: Text('addHostMapping'.tr)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Text('host', style: TextStyle(fontSize: 14)),
            trailing: DropdownButton<String>(
              value: _targetHost,
              elevation: 4,
              onChanged: (String? newValue) => setState(() => _targetHost = newValue!),
              alignment: Alignment.centerRight,
              items: _dropdownMenuItems(),
            ),
          ),
          ListTile(
            leading: const Text('ip', style: TextStyle(fontSize: 14)),
            title: TextField(
              textAlign: TextAlign.right,
              onChanged: (str) => _targetIp = str,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text('cancel'.tr),
          onPressed: backRoute,
        ),
        TextButton(
          child: Text('OK'.tr),
          onPressed: () {
            if (isEmptyOrNull(_targetIp)) {
              return;
            }

            switch (_targetHost) {
              case 'e-hentai.org':
                NetworkSetting.saveEHentaiIP(_targetIp!);
                break;
              case 'exhentai.org':
                NetworkSetting.saveEXHentaiIP(_targetIp!);
                break;
              case 'upld.e-hentai.org':
                NetworkSetting.saveUpldIP(_targetIp!);
                break;
              case 'api.e-hentai.org':
                NetworkSetting.saveApiIP(_targetIp!);
                break;
              case 'forums.e-hentai.org':
                NetworkSetting.saveForumsIP(_targetIp!);
                break;
              default:
                break;
            }

            EHCookieManager cookieManager = Get.find<EHCookieManager>();
            cookieManager.getCookie(Uri.parse(EHConsts.EHIndex)).then((value) => cookieManager.storeEhCookiesForAllUri(value));
            backRoute();
          },
        ),
      ],
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }

  List<DropdownMenuItem<String>> _dropdownMenuItems() {
    return NetworkSetting.host2IPs.keys
        .map((host) => DropdownMenuItem(
              child: Text(host),
              value: host,
            ))
        .toList();
  }
}
