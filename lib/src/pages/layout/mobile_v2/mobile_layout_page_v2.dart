import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_logic.dart';
import 'package:jhentai/src/pages/layout/mobile_v2/mobile_layout_page_v2_state.dart';
import 'package:jhentai/src/pages/search/simple/simple_search_page.dart';

class MobileLayoutPageV2 extends StatelessWidget {
  final MobileLayoutPageV2Logic logic = Get.put(MobileLayoutPageV2Logic(), permanent: true);
  final MobileLayoutPageV2State state = Get.find<MobileLayoutPageV2Logic>().state;

  MobileLayoutPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.unknown,
        },
        scrollbars: true,
      ),
      child: Scaffold(
        drawer: Drawer(),
        endDrawer: Drawer(),
        body: SafeArea(
          child: Stack(
            children: [
              Offstage(
                offstage: false,
                child: GallerysPage(),
              ),
              Offstage(
                child: SimpleSearchPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
