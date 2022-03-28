import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../home/tab_view/gallerys/gallerys_view_logic.dart' as g;

class RatingDialog extends StatefulWidget {
  const RatingDialog({Key? key}) : super(key: key);

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  g.GallerysViewLogic gallerysViewLogic = Get.find<g.GallerysViewLogic>();
  DetailsPageLogic detailsPageLogic = DetailsPageLogic.currentDetailsPageLogic;
  DetailsPageState detailsPageState = DetailsPageLogic.currentDetailsPageLogic.state;

  LoadingState submitState = LoadingState.idle;
  late double rating;

  @override
  void initState() {
    rating = detailsPageState.gallery!.rating;
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
          color: Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                rating.toString(),
                style: const TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              RatingBar.builder(
                unratedColor: Colors.grey.shade300,
                minRating: 0.5,
                initialRating: rating,
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
                child: LoadingStateIndicator(
                  indicatorRadius: 12,
                  loadingState: submitState,
                  idleWidget: TextButton(
                    onPressed: submitRating,
                    child: Text(
                      'submit'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  successWidget: const DoneWidget(outline: true),
                  errorWidgetSameWithIdle: true,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void submitRating() async {
    if (submitState == LoadingState.loading) {
      return;
    }
    setState(() {
      submitState = LoadingState.loading;
    });

    String response;
    try {
      response = await EHRequest.requestSubmitRating(
        detailsPageState.gallery!.gid,
        detailsPageState.gallery!.token,
        UserSetting.ipbMemberId.value!,
        detailsPageState.apikey,
        (rating * 2).toInt(),
      );
    } on DioError catch (e) {
      Log.error(e);
      Get.snackbar('评分错误', e.message, snackPosition: SnackPosition.BOTTOM);
      setState(() {
        submitState = LoadingState.error;
      });
      return;
    }

    /// eg: {"rating_avg":0.93000000000000005,"rating_usr":0.5,"rating_cnt":21,"rating_cls":"ir irr"}
    Map<String, dynamic> respMap = jsonDecode(response);
    detailsPageState.gallery!.hasRated = true;
    detailsPageState.gallery!.rating = double.parse(respMap['rating_usr'].toString());
    detailsPageState.galleryDetails!.ratingCount = respMap['rating_cnt'];
    detailsPageState.galleryDetails!.realRating = double.parse(respMap['rating_avg'].toString());
    detailsPageLogic.update([bodyId]);
    gallerysViewLogic.update([g.bodyId]);
    setState(() {
      submitState = LoadingState.success;
    });

    /// wait for DoneWidget animation
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      submitState = LoadingState.idle;
    });
    Get.back();
  }
}
