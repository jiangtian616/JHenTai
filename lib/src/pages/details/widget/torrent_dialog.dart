import 'package:clipboard/clipboard.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_torrent.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/snack_util.dart';

class TorrentDialog extends StatefulWidget {
  const TorrentDialog({Key? key}) : super(key: key);

  @override
  _TorrentDialogState createState() => _TorrentDialogState();
}

class _TorrentDialogState extends State<TorrentDialog> {
  final DetailsPageState state = DetailsPageLogic.current!.state;
  List<GalleryTorrent> galleryTorrents = <GalleryTorrent>[];
  LoadingState loadingState = LoadingState.idle;

  @override
  void initState() {
    _getTorrent();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Center(child: Text('torrent'.tr)),
      children: [
        if (loadingState == LoadingState.loading) const CupertinoActivityIndicator(),
        if (loadingState == LoadingState.success)
          ...galleryTorrents
              .map(
                (galleryTorrent) => Column(
                  children: [
                    ListTile(
                      dense: true,
                      title: InkWell(
                        onTap: () => launch(galleryTorrent.torrentUrl),
                        child: Text(
                          galleryTorrent.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, color: Colors.blue),
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.account_circle, size: 12),
                          Text(galleryTorrent.peers.toString(), style: const TextStyle(fontSize: 12)),
                          const Icon(Icons.download, size: 12).marginOnly(left: 10),
                          Text(galleryTorrent.downloads.toString(), style: const TextStyle(fontSize: 12)),
                          const Icon(Icons.attach_file, size: 12).marginOnly(left: 10),
                          Text(galleryTorrent.size, style: const TextStyle(fontSize: 10)),
                          Text(galleryTorrent.postTime, style: const TextStyle(fontSize: 10)).marginOnly(left: 10),
                        ],
                      ),
                      trailing: InkWell(
                        child: const Icon(FontAwesomeIcons.magnet, size: 16, color: Colors.blue),
                        onTap: () {
                          FlutterClipboard.copy(galleryTorrent.magnetUrl).then(
                            (value) => snack('success'.tr, 'hasCopiedToClipboard'.tr),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        if (loadingState == LoadingState.error)
          GestureDetector(
            onTap: _getTorrent,
            child: Icon(
              FontAwesomeIcons.redoAlt,
              size: 24,
              color: Colors.grey.shade700,
            ),
          ),
      ],
    );
  }

  void _getTorrent() {
    setState(() {
      loadingState = LoadingState.loading;
    });

    EHRequest.requestTorrentPage<List<GalleryTorrent>>(
      state.gallery!.gid,
      state.gallery!.token,
      EHSpiderParser.torrentPage2GalleryTorrent,
    ).then((value) {
      if(mounted) {
        setState(() {
          galleryTorrents = value;
          loadingState = LoadingState.success;
        });
      }
    }).catchError((error) {
      Log.error(error);
      if(mounted) {
        setState(() {
          loadingState = LoadingState.error;
        });
      }
    });
  }
}
