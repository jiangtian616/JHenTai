import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../utils/route_util.dart';
import '../../../utils/snack_util.dart';
import '../../home/tab_view/gallerys/gallerys_view_logic.dart' as g;

class RatingDialog extends StatefulWidget {
  const RatingDialog({Key? key}) : super(key: key);

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  DetailsPageState detailsPageState = DetailsPageLogic.current!.state;

  late double rating=detailsPageState.gallery!.rating;

  @override
  void initState() {
    rating = DetailsPageLogic.current!.state.gallery!.rating;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 280,
          height: 140,
          padding: const EdgeInsets.only(top: 8),
          color: Get.theme.brightness == Brightness.light ? Colors.grey.shade200 : Colors.grey.shade800,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                rating.toString(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              RatingBar.builder(
                unratedColor: Colors.grey.shade300,
                minRating: 0.5,
                initialRating: max(rating, 0.5),
                itemCount: 5,
                allowHalfRating: true,
                itemSize: 36,
                itemPadding: const EdgeInsets.only(left: 4),
                updateOnDrag: true,
                itemBuilder: (context, index) => Icon(
                  Icons.star,
                  color: detailsPageState.gallery!.hasRated ? Get.theme.primaryColor : Colors.amber.shade800,
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    this.rating = rating;
                  });
                },
              ).marginOnly(top: 8, bottom: 8),
              SizedBox(
                height: 40,
                child: TextButton(
                  onPressed: () => back(result: rating),
                  child: Text(
                    'submit'.tr,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
