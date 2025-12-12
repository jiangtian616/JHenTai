import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/service/log.dart';

import 'jh_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

MlttsService mlTtsService = MlttsService();

enum TtsState { playing, stopped, paused, continued }

enum TtsDirection { defaultDirection, leftToRight, rightToLeft }

class MlttsService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late TextRecognizer _textRecognizer;
  String _extractedText = '';
  List<String> _exclusionList = [];
  List<List<String>> _replaceList = [];

  String? _path;
  late FlutterTts _flutterTts;
  bool isCurrentLanguageInstalled = false;
  TtsState ttsState = TtsState.stopped;
  RxList<String> languages = <String>[].obs;
  RxList<String> engines = <String>[].obs;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  late Worker mlTtsScriptLister;
  late Worker mlTtsEngineLister;
  late Worker mlTtsLanguageLister;
  late Worker mlTtsPitchLister;
  late Worker mlTtsRateLister;
  late Worker mlTtsVolumeLister;
  late Worker mlTtsExclusionListLister;
  late Worker mlTtsReplaceListLister;

  Future<void> _initConfig(_) async {
    await _setTtsEngine(null);
    _addListers();
    _setLanguages();
    _setExclusionList();
    _setReplaceList();

    _flutterTts.setStartHandler(() {
      log.debug('setStartHandler:Playing');
      ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      log.debug('setCompletionHandler:Complete');
      ttsState = TtsState.stopped;
    });

    _flutterTts.setCancelHandler(() {
      log.debug('setCancelHandler:Cancel');
      ttsState = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      log.debug('setPauseHandler:Paused');
      ttsState = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      log.debug('setContinueHandler:Continued');
      ttsState = TtsState.continued;
    });

    _flutterTts.setErrorHandler((msg) {
      log.debug('setErrorHandler: $msg');
      ttsState = TtsState.stopped;
    });
  }

  Future<void> _setLanguages() async {
    var langs = await _flutterTts.getLanguages;
    for (var element in langs) {
      languages.add(element);
    }
    log.debug('_setLanguages: $languages');
  }

  Future<void> _setTtsEngine(_) async {
    if (GetPlatform.isAndroid) {
      engines.clear();
      var engs = await _flutterTts.getEngines;
      for (var element in engs) {
        engines.add(element);
      }

      var engine = readSetting.mlTtsEngine.value ?? await _flutterTts.getDefaultEngine;
      if (engine != null) {
        log.debug('_setEngine: $engine');
      }
      var voice = await _flutterTts.getDefaultVoice;
      if (voice != null) {
        log.debug('_setEngine: $voice');
      }

      _flutterTts
          .isLanguageInstalled(readSetting.mlTtsLanguage.value!)
          .then((value) => isCurrentLanguageInstalled = (value as bool));

      await _flutterTts.setEngine(engine);
    }
  }

  Future<void> _setTtsEngineConfig(_) async {
    await _flutterTts.setLanguage(readSetting.mlTtsLanguage.value!);
    await _flutterTts.setSpeechRate(readSetting.mlTtsRate.value);
    await _flutterTts.setVolume(readSetting.mlTtsVolume.value);
    await _flutterTts.setPitch(readSetting.mlTtsPitch.value);
  }

  String _rateToRelativeString() {
    double rate = readSetting.mlTtsRate.value;
    return rate >= 0.9 ? 'x-fast' : 
           rate >= 0.6 ? 'fast' : 
           rate >= 0.4 ? 'medium' : 
           rate >= 0.2 ? 'slow' : 'x-slow';
  }

  String _volumeToRelativeString() {
    double volume = readSetting.mlTtsVolume.value;
    return volume >= 1.0 ? 'x-loud' :
           volume >= 0.8 ? 'loud' :
           volume >= 0.6 ? 'medium' :
           volume >= 0.4 ? 'soft' :
           volume >= 0.2 ? 'x-soft' : 'silent';
  }

  String _pitchToRelativeString() {
    double pitch = readSetting.mlTtsPitch.value;
    return pitch >= 1.1 ? 'high' : 
           pitch >= 0.9 ? 'medium' : 'low';
  }
  
  void _setExclusionList() {
    var exclusionList = readSetting.mlTtsExclusionList.value?.split(',') ?? [];
    exclusionList = exclusionList.map((e) => e.trim()).toList();
    _exclusionList = exclusionList.where((e) => e != '').toList();
  }

  void _setReplaceList() {
    _replaceList = [];
    var list = readSetting.mlTtsReplaceList.value?.split(',') ?? [];
    list = list.where((e) => e != '').toList();
    for (var replace in list) {
      var values = replace.split(':');
      if (values.length != 2) {
        continue;
      }
      _replaceList.add(values);
    }
  }

  void dispose() {
    mlTtsScriptLister.dispose();
    mlTtsEngineLister.dispose();
    mlTtsLanguageLister.dispose();
    mlTtsPitchLister.dispose();
    mlTtsRateLister.dispose();
    mlTtsVolumeLister.dispose();
    mlTtsExclusionListLister.dispose();
    mlTtsReplaceListLister.dispose();
  }

  void _addListers() {
    mlTtsScriptLister = ever(readSetting.mlTtsScript, (_) {
      _textRecognizer = TextRecognizer(script: readSetting.mlTtsScript.value);
    });
    mlTtsExclusionListLister = ever(readSetting.mlTtsExclusionList, (_) {
      _setExclusionList();
    });
    mlTtsReplaceListLister = ever(readSetting.mlTtsReplaceList, (_) {
      _setReplaceList();
    });

    mlTtsEngineLister = ever(readSetting.mlTtsEngine, _setTtsEngine);
    mlTtsLanguageLister = ever(readSetting.mlTtsLanguage, _setTtsEngineConfig);
    mlTtsPitchLister = ever(readSetting.mlTtsPitch, _setTtsEngineConfig);
    mlTtsRateLister = ever(readSetting.mlTtsRate, _setTtsEngineConfig);
    mlTtsVolumeLister = ever(readSetting.mlTtsVolume, _setTtsEngineConfig);
  }

  @override
  Future<void> doInitBean() async {
    _flutterTts = FlutterTts();
    _textRecognizer = TextRecognizer(script: readSetting.mlTtsScript.value);

    await _initConfig('');
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<ui.Image> _compressImage(File imageFile, int targetSize) async {
    final data = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frameInfo = await codec.getNextFrame();
    final originalImage = frameInfo.image;

    double scaleHeight = targetSize / originalImage.height;
    double scaleWidth = targetSize / originalImage.width;
    double scale = max(scaleHeight, scaleWidth);

    if (scale >= 1) {
      return originalImage;
    }

    int newWidth = (originalImage.width * scale).toInt();
    int newHeight = (originalImage.height * scale).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale);
    canvas.drawImage(originalImage, ui.Offset.zero, ui.Paint());
    final picture = recorder.endRecording();

    return await picture.toImage(newWidth, newHeight);
  }

  List<TextBlock> _sortedBlocks(List<TextBlock> blocks, {TtsDirection direction = TtsDirection.defaultDirection}) {
    if (direction == TtsDirection.defaultDirection) {
      return blocks;
    }

    blocks.sort((a, b) {
      final aRect = a.boundingBox;
      final bRect = b.boundingBox;
      final aCenterY = aRect.top + aRect.height / 2;
      final bCenterY = bRect.top + bRect.height / 2;
      final avgHeight = (aRect.height + bRect.height) / 2;
      if ((aCenterY - bCenterY).abs() < avgHeight) {
        if (direction == TtsDirection.rightToLeft) {
          return bRect.left.compareTo(aRect.left);
        } else {
          return aRect.left.compareTo(bRect.left);
        }
      } else {
        return aRect.top.compareTo(bRect.top);
      }
    });
    return blocks;
  }

  Future<void> _recognizedText() async {
    try {
      final imgByteData = await _compressImage(File(_path!), 720);
      final byteData = await imgByteData.toByteData(format: ui.ImageByteFormat.rawRgba);
      final inputImage = InputImage.fromBitmap(
        bitmap: byteData!.buffer.asUint8List(), 
        width: imgByteData.width,
        height: imgByteData.height
      );

      final RecognizedText text = await _textRecognizer.processImage(inputImage);
      _extractedText = GetPlatform.isIOS ? "<speak><prosody rate=\"${_rateToRelativeString()}\" pitch=\"${_pitchToRelativeString()}\" volume=\"${_volumeToRelativeString()}\">" : '';
      var blocks = _sortedBlocks(text.blocks.toList(), direction: readSetting.mlTtsDirection.value);
      for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i];
        var t = block.text.replaceAll(RegExp(r'\s'), '');
        var flag = false;
        for (var val in _exclusionList) {
          if (t.toLowerCase().contains(val)) {
            flag = true;
            break;
          }
        }
        if (flag || t.length < readSetting.mlTtsMinWordLimit.value) {
          continue;
        }
        for (var val in _replaceList) {
          t = t.replaceAll(val[0], val[1]);
        }
        log.debug('_recognizedText: $t');
        if (i == blocks.length - 1 || readSetting.mlTtsBreak.value == 0 || !GetPlatform.isIOS) {
          _extractedText += t;
        } else {
          _extractedText += t + "<break time=\"weak\"/>";
        }
      }
      _extractedText += GetPlatform.isIOS ? "</prosody></speak>" : '';
      log.debug('_recognizedText: $_extractedText');
    } catch (e) {
      log.debug('_recognizedText:error: $e');
    }
  }

  Future<void> _speak() async {
    if (_extractedText.isNotEmpty) {
      await stop();
      await _flutterTts.clearVoice();
      await _flutterTts.speak(_extractedText);
    }
  }

  Future<void> playFromPath(path) async {
    if (path == null || _path == path || !readSetting.mlTtsEnable.value) {
      return;
    }

    _path = path;
    await _recognizedText();
    _speak();
  }

  Future<void> playFromUrl(String? url) async {
    if (url == null || !readSetting.mlTtsEnable.value) {
      return;
    }

    var path = await getCachedImageFilePath(url);
    if (_path == path) {
      return;
    }

    _path = path;
    await _recognizedText();
    _speak();
  }

  Future<void> stop() async {
    var result = await _flutterTts.stop();
    if (result == 1) {
      ttsState = TtsState.stopped;
    }
  }

  Future<void> pause() async {
    var result = await _flutterTts.pause();
    if (result == 1) {
      ttsState = TtsState.paused;
    }
  }
}
