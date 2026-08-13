// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

// ignore_for_file: constant_identifier_names

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_onnxruntime/src/flutter_onnxruntime_platform_interface.dart';
import 'package:flutter_onnxruntime/src/ort_provider.dart';
import 'package:flutter_onnxruntime/src/ort_session.dart';

class OnnxRuntime {
  Future<String?> getPlatformVersion() {
    return FlutterOnnxruntimePlatform.instance.getPlatformVersion();
  }

  /// Create an ONNX Runtime session with the given model path
  Future<OrtSession> createSession(
    String modelPath, {
    OrtSessionOptions? options,
  }) async {
    final result = await FlutterOnnxruntimePlatform.instance.createSession(
      modelPath,
      sessionOptions: options?.toMap() ?? {},
    );
    return OrtSession.fromMap(result);
  }

  /// Create an ONNX Runtime session from an asset model file
  ///
  /// This will extract the asset to a temporary file and use that path
  Future<OrtSession> createSessionFromAsset(
    String assetKey, {
    OrtSessionOptions? options,
  }) async {
    if (kIsWeb) {
      // On web, we need to handle differently as path_provider is not available
      // Instead, pass the asset key directly to the web implementation
      // The web implementation will handle loading from asset properly
      return createSession(assetKey, options: options);
    } else {
      // Native platforms implementation (iOS, Android, etc)
      // Get the temporary directory
      final directory = await getTemporaryDirectory();
      // Extract filename from asset path using String manipulation
      final fileName = assetKey.split('/').last;
      // Join paths using string concatenation with platform-specific separator
      final filePath = '${directory.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);
      // Extract the asset only when it is not already cached. A cached file that
      // was fully written by a previous run is safe to reuse (see _extractAsset,
      // which writes atomically so a present file is always complete).
      final wasCached = await file.exists();
      if (!wasCached) {
        await _extractAsset(assetKey, file);
      }

      try {
        return await createSession(filePath, options: options);
      } catch (_) {
        // A cached model can still be truncated/corrupt (interrupted extraction
        // by an older non-atomic build, partial cache eviction). Such a file
        // "exists", so it would be reused and keep failing to load forever
        // (e.g. ORT_INVALID_PROTOBUF). Re-extract the always-intact bundled
        // asset and retry once so the install self-heals. Skip the retry when
        // the asset was extracted in this very call: those bytes are already
        // intact, so retrying identical bytes would only repeat the failure.
        if (!wasCached) rethrow;
        await _extractAsset(assetKey, file);
        return await createSession(filePath, options: options);
      }
    }
  }

  /// Extracts a bundled asset to [destination] atomically.
  ///
  /// The bytes are written to a sibling temporary file first and then renamed
  /// into place. rename() is atomic on the same filesystem, so an interrupted
  /// write (app killed, low storage) can never leave a partially-written model
  /// at the final path for a later run to reuse.
  Future<void> _extractAsset(String assetKey, File destination) async {
    await destination.parent.create(recursive: true);
    final data = await rootBundle.load(assetKey);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final tempFile = File('${destination.path}.tmp');
    await tempFile.writeAsBytes(bytes, flush: true);
    try {
      await tempFile.rename(destination.path);
    } on FileSystemException {
      // Some platforms (e.g. Windows) cannot rename onto an existing file.
      // Only reached when replacing an already-cached (corrupt) file.
      if (await destination.exists()) {
        await destination.delete();
      }
      await tempFile.rename(destination.path);
    }
  }

  /// Get the available providers
  ///
  /// Returns a list of the available providers
  Future<List<OrtProvider>> getAvailableProviders() async {
    final providers =
        await FlutterOnnxruntimePlatform.instance.getAvailableProviders();
    return providers.map((p) {
      final provider = OrtProvider.values.firstWhere(
        (e) => e.name == p,
        orElse:
            () =>
                throw ArgumentError('Provider $p is not a valid OrtProvider.'),
      );
      return provider;
    }).toList();
  }

  /// Returns the version compiled into the native ORT library. This can
  /// differ from the Dart package version for desktop system-library builds.
  Future<Map<String, dynamic>> getRuntimeInfo() {
    return FlutterOnnxruntimePlatform.instance.getRuntimeInfo();
  }
}
