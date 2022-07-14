import 'dart:io' as io;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/service/archive_download_service.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../utils/log.dart';

class SettingDownloadPage extends StatelessWidget {
  final GalleryDownloadService galleryDownloadService = Get.find();
  final ArchiveDownloadService archiveDownloadService = Get.find();

  SettingDownloadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('downloadSetting'.tr),
        elevation: 1,
      ),
      body: Obx(() {
        return ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            ListTile(
              title: Text('downloadPath'.tr),
              subtitle: Text(DownloadSetting.downloadPath.value),
              onTap: () => toast('changeDownloadPathHint'.tr, isShort: false),
              onLongPress: _handleChangeDownloadPath,
            ),
            if (!GetPlatform.isIOS)
              ListTile(
                title: Text('resetDownloadPath'.tr),
                subtitle: Text('longPress2Reset'.tr),
                onLongPress: _handleResetDownloadPath,
              ),
            ListTile(
              title: Text('downloadTaskConcurrency'.tr),
              subtitle: Text('needRestart'.tr),
              trailing: DropdownButton<int>(
                value: DownloadSetting.downloadTaskConcurrency.value,
                elevation: 4,
                onChanged: (int? newValue) {
                  DownloadSetting.saveDownloadTaskConcurrency(newValue!);
                },
                items: const [
                  DropdownMenuItem(
                    child: Text('2'),
                    value: 2,
                  ),
                  DropdownMenuItem(
                    child: Text('4'),
                    value: 4,
                  ),
                  DropdownMenuItem(
                    child: Text('6'),
                    value: 6,
                  ),
                  DropdownMenuItem(
                    child: Text('8'),
                    value: 8,
                  ),
                  DropdownMenuItem(
                    child: Text('10'),
                    value: 10,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('${'speedLimit'.tr} (${'needRestart'.tr})'),
              subtitle: Text('speedLimitHint'.tr),
              trailing: SizedBox(
                width: 150,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownButton<int>(
                      value: DownloadSetting.maximum.value,
                      elevation: 4,
                      alignment: AlignmentDirectional.bottomEnd,
                      onChanged: (int? newValue) {
                        DownloadSetting.saveMaximum(newValue!);
                      },
                      items: const [
                        DropdownMenuItem(
                          child: Text('1'),
                          value: 1,
                        ),
                        DropdownMenuItem(
                          child: Text('2'),
                          value: 2,
                        ),
                        DropdownMenuItem(
                          child: Text('3'),
                          value: 3,
                        ),
                        DropdownMenuItem(
                          child: Text('5'),
                          value: 5,
                        ),
                        DropdownMenuItem(
                          child: Text('10'),
                          value: 10,
                        ),
                        DropdownMenuItem(
                          child: Text('99'),
                          value: 99,
                        ),
                      ],
                    ),
                    Text('${'images'.tr} ${'per'.tr}').marginSymmetric(horizontal: 4),
                    DropdownButton<Duration>(
                      value: DownloadSetting.period.value,
                      elevation: 4,
                      alignment: AlignmentDirectional.bottomEnd,
                      onChanged: (Duration? newValue) {
                        DownloadSetting.savePeriod(newValue!);
                      },
                      items: const [
                        DropdownMenuItem(
                          child: Text('1s'),
                          value: Duration(seconds: 1),
                        ),
                        DropdownMenuItem(
                          child: Text('2s'),
                          value: Duration(seconds: 2),
                        ),
                        DropdownMenuItem(
                          child: Text('3s'),
                          value: Duration(seconds: 3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              title: Text('downloadTimeout'.tr),
              trailing: DropdownButton<int>(
                value: DownloadSetting.timeout.value,
                elevation: 4,
                onChanged: (int? newValue) {
                  DownloadSetting.saveTimeout(newValue!);
                },
                items: const [
                  DropdownMenuItem(
                    child: Text('5s'),
                    value: 5,
                  ),
                  DropdownMenuItem(
                    child: Text('10s'),
                    value: 10,
                  ),
                  DropdownMenuItem(
                    child: Text('15s'),
                    value: 15,
                  ),
                  DropdownMenuItem(
                    child: Text('20s'),
                    value: 20,
                  ),
                  DropdownMenuItem(
                    child: Text('30s'),
                    value: 30,
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('enableStoreMetadataForRestore'.tr),
              trailing: Switch(
                value: DownloadSetting.enableStoreMetadataForRestore.value,
                onChanged: (value) => DownloadSetting.saveEnableStoreMetadataToRestore(value),
              ),
              subtitle: Text('enableStoreMetadataForRestoreHint'.tr),
            ),
            ListTile(
              title: Text('restoreDownloadTasks'.tr),
              subtitle: Text('restoreDownloadTasksHint'.tr),
              onTap: _restore,
            ),
          ],
        ).paddingSymmetric(vertical: 16);
      }),
    );
  }

  Future<void> _handleChangeDownloadPath({String? newDownloadPath}) async {
    if (GetPlatform.isIOS) {
      return;
    }

    /// request storage permission
    bool hasStoragePermission = await Permission.manageExternalStorage.request().isGranted && await Permission.storage.request().isGranted;
    if (!hasStoragePermission) {
      toast('needPermissionToChangeDownloadPath'.tr, isShort: false);
      return;
    }

    /// choose new download path
    String oldDownloadPath = DownloadSetting.downloadPath.value;
    try {
      newDownloadPath ??= await FilePicker.platform.getDirectoryPath();
    } on Exception catch (e) {
      Log.error('Pick file failed', e);
    }

    if (newDownloadPath == null || newDownloadPath == oldDownloadPath) {
      return;
    }

    try {
      _checkPermissionForNewPath(newDownloadPath);
    } on FileSystemException catch (e) {
      toast('invalidPath'.tr);
      Log.error('${'invalidPath'.tr}:$newDownloadPath', e);
      return;
    }

    Future future = Future.wait([
      galleryDownloadService.pauseAllDownloadGallery(),
      archiveDownloadService.pauseAllDownloadArchive(),
    ]);

    io.Directory oldDir = io.Directory(oldDownloadPath);
    List<io.FileSystemEntity> gallerys = oldDir.listSync();

    /// copy
    future = future.then((_) async {
      List<Future> futures = [];
      for (io.FileSystemEntity oldGallery in gallerys) {
        io.FileSystemEntity newGallery = io.Directory(join(newDownloadPath!, basename(oldGallery.path)));

        /// other directory
        if (newGallery is! io.Directory || !basename(oldGallery.path).startsWith(RegExp(r'\d'))) {
          continue;
        }

        futures.add(newGallery.create(recursive: true).then((_) async {
          List<io.FileSystemEntity> files = (oldGallery as io.Directory).listSync();
          for (io.FileSystemEntity file in files) {
            file = file as io.File;
            await file.copy(join(newGallery.path, basename(file.path)));
          }
        }));
      }

      await Future.wait(futures);
    });

    DownloadSetting.saveDownloadPath(newDownloadPath);

    /// To be compatible with the previous version, update the database.
    future = future.then((_) async {
      await galleryDownloadService.updateImagePathAfterDownloadPathChanged();
    });

    /// Empty old directory
    future = future.then((_) async {
      await oldDir.delete(recursive: true).then((_) => oldDir.create(recursive: true));
    });

    future = future.then((_) async {
      await Future.wait([
        galleryDownloadService.resumeAllDownloadGallery(),
        archiveDownloadService.resumeAllDownloadArchive(),
      ]);
    });
  }

  Future<void> _handleResetDownloadPath() async {
    await _handleChangeDownloadPath(newDownloadPath: DownloadSetting.defaultDownloadPath);
  }

  Future<void> _restore() async {
    Log.verbose('Restore download task.');

    int restoredGalleryCount = await Get.find<GalleryDownloadService>().restore();
    int restoredArchiveCount = await Get.find<ArchiveDownloadService>().restore();
    snack(
      'restoreDownloadTasksSuccess'.tr,
      '${'restoredGalleryCount'.tr}: $restoredGalleryCount, ${'restoredArchiveCount'.tr}: $restoredArchiveCount',
    );
  }

  void _checkPermissionForNewPath(String newDownloadPath) {
    io.File file = io.File(join(newDownloadPath, 'test'));
    file.createSync(recursive: true);
    file.deleteSync();
  }
}
