import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:jhentai/src/model/gallery_image.dart';

import '../widget/eh_image.dart';

class TestPage extends StatelessWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Center(
        child: FlutterListView(
          delegate: FlutterListViewDelegate(
            (BuildContext context, int index) {
              return EHImage(
                galleryImage: GalleryImage(
                  url:
                      'https://kytaajr.paygwbmmxiaa.hath.network:8080/h/453e3a68a65bcc74c7942258ca191931b845e6e4-494704-1124-1600-jpg/keystamp=1647353700-bb98652305;fileindex=104410124;xres=org/00004.jpg',
                  height: 1600,
                  width: 1124,
                ),
                adaptive: true,
              );
            },
            childCount: 4,
          ),
        ),
      ),
    );
  }
}
