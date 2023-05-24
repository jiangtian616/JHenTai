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
    logic = DetailsPreviewPageLogic();
    state = logic.state;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConfig.backGroundColor(context),
      body: buildBody(context),
      floatingActionButton: buildFloatingActionButton(),
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: logic.onUserScroll,
      child: EHWheelSpeedController(
        controller: state.scrollController,
        child: CustomScrollView(
          controller: state.scrollController,
          slivers: [
            buildDetail(context),
            buildDivider(),
            buildNewVersionHint(),
            buildActions(context),
            buildTags(),
            buildComments(),
            buildThumbnails(),
            buildLoadingThumbnailIndicator(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildActions(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
      sliver: SliverToBoxAdapter(
        child: SizedBox(
          height: UIConfig.detailsPageActionsHeight,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) => ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemExtent: max(UIConfig.detailsPageActionExtent, (constraints.maxWidth - 15 * 2) / 9),
              padding: EdgeInsets.zero,
              children: [
                IconTextButton(
                  icon: Icon(Icons.visibility, color: UIConfig.detailsPageActionIconColor(context)),
                  text: Text(
                    'read'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.download, color: UIConfig.detailsPageActionIconColor(context)),
                  text: Text(
                    'download'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(
                    state.gallery!.favoriteTagIndex != null ? Icons.favorite : Icons.favorite_border,
                    color: UIConfig.detailsPageActionIconColor(context),
                  ),
                  text: Text(
                    'favorite'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(
                    state.gallery!.hasRated ? Icons.star : Icons.star_border,
                    color: state.gallery!.hasRated ? UIConfig.alertColor(context) : UIConfig.detailsPageActionTextColor(context),
                  ),
                  text: Text(
                    state.gallery!.hasRated ? state.gallery!.rating.toString() : 'rating'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.archive, color: UIConfig.detailsPageActionIconColor(context)),
                  text: Text(
                    'archive'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.cloud_download, color: UIConfig.detailsPageActionIconColor(context)),
                  text: Text(
                    'H@H',
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.saved_search, color: UIConfig.detailsPageActionIconColor(context)),
                  text: Text(
                    'similar'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.file_present, color: UIConfig.detailsPageActionIconColor(context)),
                  text: Text(
                    '${'torrent'.tr}(${state.galleryDetails?.torrentCount ?? '.'})',
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
                      height: 1,
                    ),
                  ),
                  onPressed: () {},
                ),
                IconTextButton(
                  icon: Icon(Icons.analytics, color: UIConfig.detailsPageActionIconColor(context)),
                  text: Text(
                    'statistic'.tr,
                    style: TextStyle(
                      fontSize: UIConfig.detailsPageActionTextSize,
                      color: UIConfig.detailsPageActionTextColor(context),
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
    return SliverPadding(
      padding: const EdgeInsets.only(top: 36, left: UIConfig.detailPagePadding, right: UIConfig.detailPagePadding),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return KeepAliveWrapper(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: GestureDetector(
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
                  const SizedBox(height: 3),
                  Text((index + 1).toString(), style: TextStyle(color: UIConfig.detailsPageThumbnailIndexColor(context))),
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

  @override
  Widget buildLoadingThumbnailIndicator(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 12, bottom: 40),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: Text('noMoreData'.tr, style: TextStyle(color: UIConfig.loadingStateIndicatorButtonColor(context))),
        ),
      ),
    );
  }
}

class DetailsPreviewPageLogic extends DetailsPageLogic {
  @override
  final DetailsPageState state = DetailsPreviewPageState();

  DetailsPreviewPageLogic() : super.preview();
}

class DetailsPreviewPageState extends DetailsPageState {
  DetailsPreviewPageState() {
    galleryUrl = 'gallery url - preview';

    gallery = Gallery(
      gid: 1,
      token: 'token - preview',
      title: 'Title - This is the detail preview page, you can change theme seed color to view the difference',
      category: 'Doujinshi',
      cover:
          GalleryImage(url: 'https://ehgt.org/e5/21/e5217336083e509d7f5757c0b19dc45f1b0ae6ab-4871964-2490-3523-png_250.jpg', height: 354, width: 250),
      rating: 4.5,
      pageCount: 66,
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
          GalleryTag(tagData: TagData(namespace: 'character', key: 'hibiki')),
        ],
        'female': [
          GalleryTag(tagData: TagData(namespace: 'female', key: 'lolicon')),
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
          username: 'Your name',
          score: '+66',
          scoreDetails: ['JTMONSTER +66'],
          content: dom.Element.html('<p>Comment - This is a comment from mine, you can see the color of the uploader is different</p>'),
          time: '2022-02-22',
          fromMe: true,
        ),
        GalleryComment(
          id: 0,
          username: 'Others',
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
          thumbUrl: 'https://ehgt.org/e5/21/e5217336083e509d7f5757c0b19dc45f1b0ae6ab-4871964-2490-3523-png_250.jpg',
          isLarge: true,
        ),
        GalleryThumbnail(
          href: 'href - preview',
          thumbUrl: 'https://ehgt.org/db/f5/dbf5141490676994fe3d7df681cb30a5080b6f11-8415428-2796-4015-jpg_250.jpg',
          isLarge: true,
        ),
        GalleryThumbnail(
          href: 'href - preview',
          thumbUrl: 'https://ehgt.org/e1/ba/e1bab290a2ca1217955d395bd6e0a56874383c4e-8159354-2796-4015-jpg_250.jpg',
          isLarge: true,
        ),
        GalleryThumbnail(
          href: 'href - preview',
          thumbUrl: 'https://ehgt.org/c1/fc/c1fc4299c883bb5a6e2e7142a635b9349f07030d-7593228-2796-4015-jpg_250.jpg',
          isLarge: true,
        ),
        GalleryThumbnail(
          href: 'href - preview',
          thumbUrl: 'https://ehgt.org/54/66/5466d5c0318f708c5f7d0d71930a68ca549fa73c-954881-1800-2544-jpg_250.jpg',
          isLarge: true,
        ),
        GalleryThumbnail(
          href: 'href - preview',
          thumbUrl: 'https://ehgt.org/6d/06/6d06775741f61da2d9989ed5e42dd0e672858b7a-3183575-2115-3036-jpg_250.jpg',
          isLarge: true,
        ),
      ],
      thumbnailsPageCount: 1,
    );

    apikey = 'api key - preview';
  }
}
