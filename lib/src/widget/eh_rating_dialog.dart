import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:jhentai/src/config/ui_config.dart';

import '../utils/route_util.dart';

class EHRatingDialog extends StatefulWidget {
  final double rating;
  final bool hasRated;

  const EHRatingDialog({Key? key, required this.rating, required this.hasRated}) : super(key: key);

  @override
  _EHRatingDialogState createState() => _EHRatingDialogState();
}

class _EHRatingDialogState extends State<EHRatingDialog> {
  late double rating = widget.rating;
  late bool hasRated = widget.hasRated;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      contentPadding: const EdgeInsets.only(top: 16, bottom: 12),
      children: [
        Center(child: Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
        _buildRatingBar().marginOnly(top: 16),
        _buildSubmitButton().marginOnly(top: 12),
      ],
    );
  }

  Widget _buildRatingBar() {
    return Center(
      child: RatingBar.builder(
        unratedColor: UIConfig.galleryRatingStarUnRatedColor(context),
        minRating: 0.5,
        initialRating: max(rating, 0.5),
        itemCount: 5,
        allowHalfRating: true,
        itemSize: UIConfig.ratingDialogStarSize,
        itemPadding: const EdgeInsets.only(left: 4),
        updateOnDrag: true,
        itemBuilder: (context, index) => Icon(Icons.star, color: hasRated ? UIConfig.galleryRatingStarRatedColor(context) : UIConfig.galleryRatingStarColor),
        onRatingUpdate: (rating) => setState(() => this.rating = rating),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: SizedBox(
        height: UIConfig.ratingDialogButtonBoxHeight,
        width: UIConfig.ratingDialogButtonBoxWidth,
        child: TextButton(
          onPressed: () => backRoute(result: rating),
          child: Text('submit'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
