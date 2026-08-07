import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/config/theme_config.dart';
import '../../config/ui_config.dart';
import '../../setting/user_setting.dart';
import '../../utils/app_icons.dart';
import '../../utils/route_util.dart';
import '../layout/mobile_v2/notification/tap_menu_button_notification.dart';

class SettingPage extends StatelessWidget {
  final bool showMenuButton;

  const SettingPage({Key? key, this.showMenuButton = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: !ThemeConfig.isApple,
        title: Text('setting'.tr),
        leading: showMenuButton
            ? IconButton(
                icon: Icon(AppIcons.menu, size: 20),
                onPressed: () => TapMenuButtonNotification().dispatch(context))
            : null,
      ),
      body: Obx(
        () => ThemeConfig.isApple
            ? _buildAppleSettings(context)
            : _buildMaterialSettings(context),
      ),
    );
  }

  Widget _buildMaterialSettings(BuildContext context) => ListView(
        padding: EdgeInsets.only(
            top: 12, bottom: UIConfig.liquidGlassNavContentInset(context)),
        children: _settingTiles(appleStyle: false),
      );

  Widget _buildAppleSettings(BuildContext context) {
    final tiles = _settingTiles(appleStyle: true);
    final groups = <List<ListTile>>[
      tiles.take(userSetting.hasLoggedIn() ? 2 : 1).toList(),
      tiles.skip(userSetting.hasLoggedIn() ? 2 : 1).take(3).toList(),
      tiles.skip(userSetting.hasLoggedIn() ? 5 : 4).toList(),
    ];
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          14, 16, 14, 24 + UIConfig.liquidGlassNavContentInset(context)),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
              width: 0.5),
        ),
        child: _buildAppleGroup(context, groups[index]),
      ),
    );
  }

  Widget _buildAppleGroup(BuildContext context, List<ListTile> tiles) => Column(
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            tiles[index],
            if (index < tiles.length - 1)
              Divider(
                height: 0.5,
                indent: 56,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
              ),
          ],
        ],
      );

  List<ListTile> _settingTiles({required bool appleStyle}) => [
        _settingTile(
            _settingIcon(
                Icons.account_circle, CupertinoIcons.person_crop_circle),
            'account',
            'account',
            appleStyle),
        if (userSetting.hasLoggedIn())
          _settingTile(_settingIcon(Icons.mood, CupertinoIcons.smiley), 'EH',
              'EH', appleStyle),
        _settingTile(_settingIcon(Icons.style, CupertinoIcons.paintbrush),
            'style', 'style', appleStyle),
        _settingTile(_settingIcon(Icons.local_library, CupertinoIcons.book),
            'read', 'read', appleStyle),
        _settingTile(_settingIcon(Icons.stars, CupertinoIcons.star),
            'preference', 'preference', appleStyle),
        _settingTile(_settingIcon(Icons.wifi, CupertinoIcons.wifi), 'network',
            'network', appleStyle),
        _settingTile(
            _settingIcon(Icons.download, CupertinoIcons.cloud_download),
            'download',
            'download',
            appleStyle),
        _settingTile(_settingIcon(Icons.electric_bolt, CupertinoIcons.bolt),
            'performance', 'performance', appleStyle),
        _settingTile(
            _settingIcon(Icons.mouse, CupertinoIcons.slider_horizontal_3),
            'mouseWheel',
            'mouse_wheel',
            appleStyle),
        _settingTile(
            _settingIcon(Icons.settings_suggest, CupertinoIcons.settings),
            'advanced',
            'advanced',
            appleStyle),
        _settingTile(_settingIcon(Icons.security, CupertinoIcons.lock_shield),
            'security', 'security', appleStyle),
        _settingTile(_settingIcon(Icons.info, CupertinoIcons.info), 'about',
            'about', appleStyle),
      ];

  IconData _settingIcon(IconData materialIcon, IconData appleIcon) =>
      ThemeConfig.isApple ? appleIcon : materialIcon;

  ListTile _settingTile(
          IconData icon, String label, String route, bool appleStyle) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label.tr),
        minVerticalPadding: appleStyle ? 10 : null,
        trailing: appleStyle ? const Icon(Icons.chevron_right, size: 19) : null,
        onTap: () => toRoute(Routes.settingPrefix + route),
      );
}
