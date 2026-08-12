import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
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
        leading:
            showMenuButton
                ? EHAppleIconButton(
                  icon: Icon(AppIcons.menu, size: 20),
                  onPressed:
                      () => TapMenuButtonNotification().dispatch(context),
                )
                : null,
      ),
      body: Obx(() {
        // Read the login state in this observer's closure.  Calling the
        // helper indirectly from the tile factory made the dependency
        // invisible to GetX in some desktop builds, which turned this
        // whole settings body into a no-op Obx and surfaced the red error
        // overlay.
        final bool isLoggedIn = userSetting.ipbMemberId.value != null;
        return ThemeConfig.isApple
            ? _buildAppleSettings(context, isLoggedIn: isLoggedIn)
            : _buildMaterialSettings(context, isLoggedIn: isLoggedIn);
      }),
    );
  }

  Widget _buildMaterialSettings(
    BuildContext context, {
    required bool isLoggedIn,
  }) => ListView(
    padding: EdgeInsets.only(
      top: 12,
      bottom: UIConfig.liquidGlassNavContentInset(context),
    ),
    children: _settingTiles(appleStyle: false, isLoggedIn: isLoggedIn),
  );

  Widget _buildAppleSettings(BuildContext context, {required bool isLoggedIn}) {
    final tiles = _settingTiles(appleStyle: true, isLoggedIn: isLoggedIn);
    final groups = <List<ListTile>>[
      tiles.take(isLoggedIn ? 2 : 1).toList(),
      tiles.skip(isLoggedIn ? 2 : 1).take(3).toList(),
      tiles.skip(isLoggedIn ? 5 : 4).toList(),
    ];
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        14,
        16,
        14,
        24 + UIConfig.liquidGlassNavContentInset(context),
      ),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder:
          (_, index) => DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
                width: 0.5,
              ),
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

  List<ListTile> _settingTiles({
    required bool appleStyle,
    required bool isLoggedIn,
  }) => [
    _settingTile(
      _settingIcon(Icons.account_circle, CupertinoIcons.person_crop_circle),
      'account',
      'account',
      appleStyle,
    ),
    if (isLoggedIn)
      _settingTile(
        _settingIcon(Icons.mood, CupertinoIcons.smiley),
        'EH',
        'EH',
        appleStyle,
      ),
    _settingTile(
      _settingIcon(Icons.style, CupertinoIcons.paintbrush),
      'style',
      'style',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.local_library, CupertinoIcons.book),
      'read',
      'read',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.stars, CupertinoIcons.star),
      'preference',
      'preference',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.wifi, CupertinoIcons.wifi),
      'network',
      'network',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.download, CupertinoIcons.cloud_download),
      'download',
      'download',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.memory, CupertinoIcons.cube),
      'inferenceSetting',
      'inference',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.mouse, CupertinoIcons.slider_horizontal_3),
      'mouseWheel',
      'mouse_wheel',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.settings_suggest, CupertinoIcons.settings),
      'advanced',
      'advanced',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.security, CupertinoIcons.lock_shield),
      'security',
      'security',
      appleStyle,
    ),
    _settingTile(
      _settingIcon(Icons.info, CupertinoIcons.info),
      'about',
      'about',
      appleStyle,
    ),
  ];

  IconData _settingIcon(IconData materialIcon, IconData appleIcon) =>
      ThemeConfig.isApple ? appleIcon : materialIcon;

  ListTile _settingTile(
    IconData icon,
    String label,
    String route,
    bool appleStyle,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(label.tr),
    minVerticalPadding: appleStyle ? 10 : null,
    trailing: appleStyle ? const Icon(Icons.chevron_right, size: 19) : null,
    onTap: () => toRoute(Routes.settingPrefix + route),
  );
}
