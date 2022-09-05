import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EHGalleryFavoriteTag extends StatelessWidget {
  final String name;
  final Color color;

  const EHGalleryFavoriteTag({Key? key, required this.name, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 8, color: Colors.white),
          Text(name, style: const TextStyle(fontSize: 10, height: 1, color: Colors.white)).marginOnly(left: 2),
        ],
      ),
    );
  }
}
