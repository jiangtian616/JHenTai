import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/consts/color_consts.dart';

class GalleryCategoryTag extends StatelessWidget {
  String category;

  GalleryCategoryTag({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        color: ColorConsts.galleryCategoryColor[category],
        child: Text(
          category,
          style: const TextStyle(
            height: 1,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
