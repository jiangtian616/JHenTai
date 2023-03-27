import 'dart:collection';
import 'dart:math';

import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/pages/details/details_page.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:html/dom.dart' as dom;

import '../../../../../config/ui_config.dart';
import '../../../../../widget/eh_thumbnail.dart';
import '../../../../../widget/eh_wheel_speed_controller.dart';
import '../../../../../widget/icon_text_button.dart';

class DetailPreviewPage extends DetailsPage {

  DetailPreviewPage({super.key}) : super.preview() {
    logic = DetailsPreviewPageLogic('preview');
    state = logic.state;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConfig.backGroundColor(context),
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton(),
    );
  }

  @override
  Widget buildBody() {
    return NotificationListener<UserScrollNotification>(
      onNotification: logic.onUserScroll,
      child: EHWheelSpeedController(
        controller: state.scrollController,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          controller: state.scrollController,
          slivers: [
            buildHeader(),
            buildDivider(),
            buildNewVersionHint(),
            buildActions(),
            buildTags(),
            buildCommentsIndicator(),
            buildComments(),
            buildThumbnails(),
            buildLoadingThumbnailIndicator(),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildLoadingThumbnailIndicator() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: Text('noMoreData'.tr, style: TextStyle(color: UIConfig.loadingStateIndicatorButtonColor)),
      ),
    );
  }

  @override
  Widget buildActions() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: UIConfig.detailsPageActionsHeight,
          child: LayoutBuilder(
            builder: (_, BoxConstraints constraints) => ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemExtent: max(UIConfig.detailsPageActionExtent, (constraints.maxWidth - 15 * 2) / 9),
              padding: EdgeInsets.zero,
              children: [
                IconTextButton(
                  icon: Icon(Icons.visibility, color: UIConfig.detailsPageActionIconColor),
                  text: Text(
                    'read'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.download, color: UIConfig.detailsPageActionIconColor),
                  text: Text(
                    'download'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(
                    state.gallery!.favoriteTagIndex != null ? Icons.favorite : Icons.favorite_border,
                    color: UIConfig.detailsPageActionIconColor,
                  ),
                  text: Text(
                    'favorite'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(
                    state.gallery!.hasRated ? Icons.star : Icons.star_border,
                    color: state.gallery!.hasRated ? UIConfig.alertColor : UIConfig.detailsPageActionIconColor,
                  ),
                  text: Text(
                    state.gallery!.hasRated ? state.gallery!.rating.toString() : 'rating'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.archive, color: UIConfig.detailsPageActionIconColor),
                  text: Text(
                    'archive'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.cloud_download, color: UIConfig.detailsPageActionIconColor),
                  text: Text(
                    'H@H',
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.saved_search, color: UIConfig.detailsPageActionIconColor),
                  text: Text(
                    'similar'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.file_present, color: UIConfig.detailsPageActionIconColor),
                  text: Text(
                    '${'torrent'.tr}(${state.galleryDetails?.torrentCount ?? '.'})',
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.analytics, color: UIConfig.detailsPageActionIconColor),
                  text: Text(
                    'statistic'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor,
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildThumbnails() {
    if (state.galleryDetails == null) {
      return const SliverToBoxAdapter();
    }

    return SliverPadding(
      padding: const EdgeInsets.only(top: 36, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, index) {
            return KeepAliveWrapper(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: () => logic.goToReadPage(index),
                        child: LayoutBuilder(
                          builder: (_, constraints) => EHThumbnail(
                            thumbnail: state.galleryDetails!.thumbnails[index],
                            containerHeight: constraints.maxHeight,
                            containerWidth: constraints.maxWidth,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    (index + 1).toString(),
                    style: TextStyle(color: UIConfig.detailsPageThumbnailIndexColor),
                  ).paddingOnly(top: 3),
                ],
              ),
            );
          },
          childCount: state.galleryDetails!.thumbnails.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          mainAxisExtent: UIConfig.detailsPageThumbnailHeight,
          maxCrossAxisExtent: UIConfig.detailsPageThumbnailWidth,
          mainAxisSpacing: 20,
          crossAxisSpacing: 5,
        ),
      ),
    );
  }
}

class DetailsPreviewPageLogic extends DetailsPageLogic {
  @override
  final DetailsPageState state = DetailsPreviewPageState();

  DetailsPreviewPageLogic(String tag) : super.preview(tag);
}

class DetailsPreviewPageState extends DetailsPageState {
  DetailsPreviewPageState() {
    galleryUrl ='gallery url - preview';
    
    gallery = Gallery(
      gid: 1,
      token: 'token - preview',
      title: 'Title - This is the detail preview page',
      category: 'Doujinshi',
      cover: GalleryImage(url: 'https://www.baidu.com/img/PCtm_d9c8750bed0b3c7d089fa7d55720d6cf.png', height: 400, width: 800),
      rating: 4.5,
      hasRated: true,
      isFavorite: true,
      galleryUrl: 'gallery url - preview',
      tags: LinkedHashMap.of({
        'language': [
          GalleryTag(tagData: TagData(namespace: 'language', key: 'chinese')),
        ],
        'artist': [
          GalleryTag(tagData: TagData(namespace: 'artist', key: 'JTMonster')),
          GalleryTag(tagData: TagData(namespace: 'artist', key: '酱天小禽兽')),
        ],
        'character': [
          GalleryTag(tagData: TagData(namespace: 'artist', key: 'Hibiki')),
        ],
        'female': [
          GalleryTag(tagData: TagData(namespace: 'artist', key: 'Hibiki')),
        ],
      }),
      publishTime: '2022-02-22 12:12:12',
      isExpunged: true,
    );

    galleryDetails = GalleryDetail(
      rawTitle: 'Title - This is the detail preview page',
      ratingCount: 666,
      realRating: 4,
      size: '66.66MB',
      favoriteCount: 666,
      torrentCount: '666',
      torrentPageUrl: 'torrent page url - preview',
      archivePageUrl: 'archivePageUrl page url - preview',
      fullTags: LinkedHashMap.of({
        'language': [
          GalleryTag(tagData: TagData(namespace: 'language', key: 'chinese')),
        ],
        'artist': [
          GalleryTag(tagData: TagData(namespace: 'artist', key: 'JTMonster')),
          GalleryTag(tagData: TagData(namespace: 'artist', key: '酱天小禽兽')),
        ],
        'character': [
          GalleryTag(tagData: TagData(namespace: 'artist', key: 'Hibiki')),
        ],
        'female': [
          GalleryTag(tagData: TagData(namespace: 'artist', key: 'Hibiki')),
        ],
      }),
      comments: [
        GalleryComment(
          id: 0,
          score: '+66',
          scoreDetails: ['JTMONSTER +66'],
          content: dom.Element.html('<p>Comment - This is a comment from mine</p>'),
          time: '2022-02-22',
          fromMe: true,
        ),
        GalleryComment(
          id: 0,
          score: '-666',
          scoreDetails: ['JTMONSTER -666'],
          content: dom.Element.html('<p>Comment - This is a comment from others</p>'),
          time: '2022-02-22',
          fromMe: false,
        ),
      ],
      thumbnails: [
        GalleryThumbnail(
          href: 'href - preview',
          thumbUrl: 'https://www.baidu.com/img/PCtm_d9c8750bed0b3c7d089fa7d55720d6cf.png',
          isLarge: true,
        ),
      ],
      thumbnailsPageCount: 1,
    );

    apikey = 'api key - preview';
  }
}
