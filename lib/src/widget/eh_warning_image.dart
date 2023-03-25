import 'package:blur/blur.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';

class EHWarningImage extends StatefulWidget {
  final bool warning;
  final String src;

  const EHWarningImage({Key? key, required this.warning, required this.src}) : super(key: key);

  @override
  State<EHWarningImage> createState() => _EHWarningImageState();
}

class _EHWarningImageState extends State<EHWarningImage> {
  bool warning = false;

  @override
  void initState() {
    warning = widget.warning;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (warning) {
          setState(() => warning = false);
        }
      },
      child: warning
          ? Blur(
              blur: 15,
              blurColor: UIConfig.warningImageBlurColor,
              colorOpacity: 0.75,
              child: ExtendedImage.network(widget.src),
              overlay: Center(
                child: Text(
                  'warningImageHint'.tr,
                  style: const TextStyle(fontSize: 12, height: 2, color: UIConfig.warningImageTextColor),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ExtendedImage.network(widget.src),
    );
  }
}
