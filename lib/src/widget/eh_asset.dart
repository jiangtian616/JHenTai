import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';

class EHAsset extends StatelessWidget {
  final int gpCount;
  final int creditCount;

  const EHAsset({Key? key, required this.gpCount, required this.creditCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _CircleAssetChip(str: 'C'),
        Text(creditCount.toString(), style: const TextStyle(fontSize: 12)).marginOnly(left: 2),
        const _CircleAssetChip(str: 'G').marginOnly(left: 16),
        Text(gpCount.toString(), style: const TextStyle(fontSize: 12)).marginOnly(left: 2),
      ],
    );
  }
}

class _CircleAssetChip extends StatelessWidget {
  final String str;

  const _CircleAssetChip({Key? key, required this.str}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: UIConfig.primaryColor(context), shape: BoxShape.circle),
      child: Center(
        child: Text(
          str,
          style: TextStyle(
            color: UIConfig.onPrimaryColor(context),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
