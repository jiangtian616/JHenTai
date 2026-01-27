import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/service/log.dart';

import 'jh_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

MlttsService mlTtsService = MlttsService();

enum TtsState { playing, stopped, paused, continued, completed }

enum TtsDirection { defaultDirection, leftToRight, rightToLeft }

class MlttsService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late TextRecognizer _textRecognizer;
  final List<TextBlock> _extractedTextList = [];
  final Rxn<TextBlock> _currentSpeakingTextBlock = Rxn<TextBlock>();
  Map<String, String> _replaceList = {};
  int _breakTime = 0;
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
  Rxn<TextBlock> get currentSpeakingTextBlock => _currentSpeakingTextBlock;

  late Worker mlTtsScriptLister;
  late Worker mlTtsEngineLister;
  late Worker mlTtsLanguageLister;
  late Worker mlTtsPitchLister;
  late Worker mlTtsRateLister;
  late Worker mlTtsVolumeLister;
  late Worker mlTtsReplaceListLister;
  late Worker mlTtsBreakLister;

  Future<void> _initConfig(_) async {
    await _setTtsEngine(null);
    _setTtsConfig(null);
    _addListers();
    _setLanguages();
    _setReplaceList();
    _setBreakTime(null);

    _flutterTts.setStartHandler(() {
      log.debug('setStartHandler:Playing');
      ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() async {
      if (_extractedTextList.isEmpty) {
        ttsState = TtsState.completed;
        _currentSpeakingTextBlock.value = null;
        log.debug('setCompletionHandler:Complete');
      } else {
        await Future.delayed(Duration(milliseconds: _breakTime), _speak);
        log.debug('setCompletionHandler:Continued Next');
      }
    });

    _flutterTts.setCancelHandler(() {
      log.debug('setCancelHandler:Cancel');
      if (_extractedTextList.isEmpty) {
        ttsState = TtsState.stopped;
      }
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
      await _flutterTts.speak(" ");
    }
  }

  Future<void> _setTtsConfig(_) async {
    await _flutterTts.setLanguage(readSetting.mlTtsLanguage.value!);
    await _flutterTts.setSpeechRate(readSetting.mlTtsRate.value);
    await _flutterTts.setVolume(readSetting.mlTtsVolume.value);
    await _flutterTts.setPitch(readSetting.mlTtsPitch.value);
    await _flutterTts.speak(" ");
  }

  void _setBreakTime(_) {
    const double baseAnchor = 250.0;
    const double baseRate = 0.5;
    double intensity = readSetting.mlTtsBreak.value / baseAnchor;
    double rateFactor = baseRate / readSetting.mlTtsRate.value.clamp(0.01, 2.0);
    _breakTime = (baseAnchor * intensity * rateFactor).round().clamp(0, 2000);
  }

  void _setReplaceList() {
    _replaceList = {};
    var list = readSetting.mlTtsReplaceList.value?.split('\n') ?? [];
    list = list.where((e) => e != '').toList();
    for (var replace in list) {
      var values = replace.split(':');
      if (values.length != 2) {
        continue;
      }
      var oldValue = values[0];
      var newValue = values[1];
      var isRegex = oldValue.startsWith('r/') && oldValue.endsWith('/');

      String pattern;
      if (isRegex) {
        pattern = oldValue.substring(2, oldValue.length - 1);
      } else {
        pattern = RegExp.escape(oldValue);
      }

      _replaceList[pattern] = newValue;
    }
  }

  void dispose() {
    mlTtsScriptLister.dispose();
    mlTtsEngineLister.dispose();
    mlTtsLanguageLister.dispose();
    mlTtsPitchLister.dispose();
    mlTtsRateLister.dispose();
    mlTtsVolumeLister.dispose();
    mlTtsReplaceListLister.dispose();
    mlTtsBreakLister.dispose();
  }

  void _addListers() {
    mlTtsScriptLister = ever(readSetting.mlTtsScript, (_) {
      _textRecognizer = TextRecognizer(script: readSetting.mlTtsScript.value);
    });
    mlTtsReplaceListLister = ever(readSetting.mlTtsReplaceList, (_) {
      _setReplaceList();
    });

    mlTtsEngineLister = ever(readSetting.mlTtsEngine, _setTtsEngine);
    mlTtsLanguageLister = ever(readSetting.mlTtsLanguage, _setTtsConfig);
    mlTtsPitchLister = ever(readSetting.mlTtsPitch, _setTtsConfig);
    mlTtsRateLister = ever(readSetting.mlTtsRate, _setTtsConfig);
    mlTtsVolumeLister = ever(readSetting.mlTtsVolume, _setTtsConfig);
    mlTtsBreakLister = ever(readSetting.mlTtsBreak, _setBreakTime);
  }

  @override
  Future<void> doInitBean() async {
    _flutterTts = FlutterTts();
    _textRecognizer = TextRecognizer(script: readSetting.mlTtsScript.value);

    await _initConfig('');
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<ui.Image> _compressImage(File imageFile) async {
    final data = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frameInfo = await codec.getNextFrame();
    final originalImage = frameInfo.image;

    double targetSize = 720.0;
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
    
    const double sameRowThreshold = 0.5; // 垂直中心偏差小于平均高度的 50% 视为同一行
    
    blocks.sort((a, b) {
      final aRect = a.boundingBox;
      final bRect = b.boundingBox;

      final aCenterY = aRect.top + aRect.height / 2;
      final bCenterY = bRect.top + bRect.height / 2;
      final avgHeight = (aRect.height + bRect.height) / 2;

      if ((aCenterY - bCenterY).abs() <= avgHeight * sameRowThreshold) {
        return direction == TtsDirection.rightToLeft
            ? bRect.left.compareTo(aRect.left)
            : aRect.left.compareTo(bRect.left);
      }

      return aCenterY.compareTo(bCenterY);
    });

    return blocks;
  }

  List<TextBlock> _mergeBlocks(List<TextBlock> blocks) {
    if (blocks.isEmpty) {
      return blocks;
    }

    final List<TextBlock> merged = [];
    TextBlock? firstBlock;

    for (final lastBlock in blocks) {
      if (firstBlock == null) {
        firstBlock = lastBlock;
        continue;
      }

      final firstBlockRect = firstBlock.boundingBox;
      final lastBlockRect = lastBlock.boundingBox;
      final bool isRowMode = firstBlockRect.width > firstBlockRect.height;

      bool shouldMerge;
      if (isRowMode) {
        // 行模式：垂直重叠 & 水平相邻
        final double spacing = firstBlock.lines.last.boundingBox.height;
        final vertOverlap = lastBlockRect.top - spacing < firstBlockRect.bottom;
        final horizAdj = lastBlockRect.center.dx > firstBlockRect.left &&
                         lastBlockRect.center.dx < firstBlockRect.right;
        shouldMerge = vertOverlap && horizAdj;
      } else {
        // 列模式：水平重叠 & 垂直相邻
        final double spacing = firstBlock.lines.last.boundingBox.width;
        final horizOverlap = lastBlockRect.right + spacing > firstBlockRect.left;
        final vertAdj = lastBlockRect.center.dy > firstBlockRect.top &&
                        lastBlockRect.center.dy < firstBlockRect.bottom;
        shouldMerge = horizOverlap && vertAdj;
      }

      if (shouldMerge) {
        final newText = firstBlock.text + lastBlock.text;
        final newRect = firstBlockRect.expandToInclude(lastBlockRect);
        firstBlock = TextBlock(
          text: newText,
          boundingBox: newRect,
          recognizedLanguages: firstBlock.recognizedLanguages,
          cornerPoints: firstBlock.cornerPoints,
          lines: [...firstBlock.lines, ...lastBlock.lines],
        );
      } else {
        merged.add(firstBlock);
        firstBlock = lastBlock;
      }
    }

    if (firstBlock != null) {
      merged.add(firstBlock);
    }

    return merged;
  }

  Future<void> _recognizedText() async {
    try {
      final imgByteData = await _compressImage(File(_path!));
      final byteData = await imgByteData.toByteData(format: ui.ImageByteFormat.rawRgba);
      final inputImage = InputImage.fromBitmap(
        bitmap: byteData!.buffer.asUint8List(), 
        width: imgByteData.width,
        height: imgByteData.height
      );

      _extractedTextList.clear();

      final RecognizedText text = await _textRecognizer.processImage(inputImage);
      var blocks = _mergeBlocks(text.blocks);
      blocks = _sortedBlocks(blocks, direction: readSetting.mlTtsDirection.value);
      final RegExp blankReg = RegExp(r'\s');
      final int minLen = readSetting.mlTtsMinWordLimit.value;
      for (var block in blocks) {
        String t = block.text.replaceAll(blankReg, '');
        if (t.length < minLen) {
          continue;
        }
        for (var entry in _replaceList.entries) {
          t = t.replaceAll(RegExp(entry.key, caseSensitive: false, unicode: true), entry.value);
        }
        if (t.isEmpty) {
          continue;
        }
        _extractedTextList.add(TextBlock(
            text: t,
            lines: block.lines,
            boundingBox: block.boundingBox,
            recognizedLanguages: block.recognizedLanguages,
            cornerPoints: block.cornerPoints));
        log.debug('_recognizedText: $t');
      }
    } catch (e) {
      log.debug('_recognizedText:error: $e');
    }
  }

  Future<void> _speak() async {
    if (_extractedTextList.isNotEmpty) {
      final textBlock = _extractedTextList.removeAt(0);
      _currentSpeakingTextBlock.value = textBlock;
      await _flutterTts.speak(textBlock.text);
      log.debug('_speak:Speaking block with text: ${textBlock.text}, rect: ${textBlock.boundingBox}');
    }
  }

  Future<void> playFromPath(path) async {
    if (path == null || _path == path || !readSetting.mlTtsEnable.value) {
      return;
    }

    _path = path;
    _currentSpeakingTextBlock.value = null;
    _extractedTextList.clear();
    await stop();
    await _recognizedText();
    await _speak();
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
    _currentSpeakingTextBlock.value = null;
    _extractedTextList.clear();
    await stop();
    await _recognizedText();
    await _speak();
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
