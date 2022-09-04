import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/extensions/widget_extensions.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/comment/eh_comment.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import '../../../setting/user_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../utils/snack_util.dart';
import '../../../widget/comment_dialog.dart';

class CommentPage extends StatefulWidget {
  const CommentPage({Key? key}) : super(key: key);

  @override
  _CommentPageState createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  late List<GalleryComment> comments;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    comments = Get.arguments;
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('allComments'.tr)),
      floatingActionButton: FloatingActionButton(onPressed: _handleAddComment, child: const Icon(Icons.add)),
      body: EHWheelSpeedController(
        scrollController: _scrollController,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.only(top: 6, left: 8, right: 8, bottom: 200),
          controller: _scrollController,
          children: comments
              .map(
                (comment) => EHComment(
                  comment: comment,
                  canTapUrl: true,
                  isSelectable: true,
                  showVotingButtons: comment.username != UserSetting.userName.value && comment.score.isNotEmpty,
                ).marginOnly(bottom: 8),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _handleAddComment() async {
    if (!UserSetting.hasLoggedIn()) {
      snack('operationFailed'.tr, 'needLoginToOperate'.tr);
      return;
    }

    bool? success = await Get.dialog(const CommentDialog());

    if (success ?? false) {
      List<GalleryComment> newComments = await EHRequest.requestDetailPage(
        galleryUrl: DetailsPageLogic.current!.state.gallery!.galleryUrl,
        parser: EHSpiderParser.detailPage2Comments,
        useCacheIfAvailable: false,
      );

      setState(() {
        comments.clear();
        comments.addAll(newComments);
      });

      DetailsPageLogic.current?.update();
    }
  }
}
