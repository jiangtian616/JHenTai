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

import '../../../mixin/login_required_logic_mixin.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/eh_spider_parser.dart';
import '../../../widget/eh_comment_dialog.dart';

class CommentPage extends StatefulWidget {
  const CommentPage({Key? key}) : super(key: key);

  @override
  _CommentPageState createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> with LoginRequiredMixin {
  late List<GalleryComment> comments = Get.arguments;
  late bool disableButtons = comments.any((comment) => comment.fromMe);

  final ScrollController _scrollController = ScrollController();

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
        controller: _scrollController,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.only(top: 6, left: 8, right: 8, bottom: 200),
          controller: _scrollController,
          children: comments
              .map(
                (comment) => EHComment(comment: comment, disableButtons: disableButtons).marginOnly(bottom: 8),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _handleAddComment() async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    bool? success = await Get.dialog(const EHCommentDialog());

    if (success == null || success == false) {
      return;
    }

    List<GalleryComment> newComments = await EHRequest.requestDetailPage(
      galleryUrl: DetailsPageLogic.current!.state.gallery!.galleryUrl,
      parser: EHSpiderParser.detailPage2Comments,
      useCacheIfAvailable: false,
    );

    setState(() {
      disableButtons = true;
      comments.clear();
      comments.addAll(newComments);
    });

    DetailsPageLogic.current?.update();
  }
}
