// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:extended_image_library/src/extended_image_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/src/services/dom.dart';
import 'package:http_client_helper/http_client_helper.dart';

import 'extended_network_image_provider.dart' as image_provider;

/// Creates a type for an overridable factory function for testing purposes.
typedef HttpRequestFactory = DomXMLHttpRequest Function();

/// Default HTTP client.
DomXMLHttpRequest _httpClient() {
  return DomXMLHttpRequest();
}

/// Creates an overridable factory function.
HttpRequestFactory httpRequestFactory = _httpClient;

/// Restores to the default HTTP request factory.
void debugRestoreHttpRequestFactory() {
  httpRequestFactory = _httpClient;
}

/// The dart:html implementation of [image_provider.NetworkImage].
///
/// NetworkImage on the web does not support decoding to a specified size.
class ExtendedNetworkImageProvider
    extends ImageProvider<image_provider.ExtendedNetworkImageProvider>
    with ExtendedImageProvider<image_provider.ExtendedNetworkImageProvider>
    implements image_provider.ExtendedNetworkImageProvider {
  /// Creates an object that fetches the image at the given URL.
  ///
  /// The arguments [url] and [scale] must not be null.
  ExtendedNetworkImageProvider(
    this.url, {
    this.scale = 1.0,
    this.headers,
    this.cache = false,
    this.retries = 3,
    this.timeLimit,
    this.timeRetry = const Duration(milliseconds: 100),
    this.cancelToken,
    this.cacheKey,
    this.printError = true,
    this.cacheRawData = false,
    this.imageCacheName,
    this.cacheMaxAge,
  });

  @override
  final String url;

  @override
  final double scale;

  @override
  final Map<String, String>? headers;

  @override
  final bool cache;

  @override
  final CancellationToken? cancelToken;

  @override
  final int retries;

  @override
  final Duration? timeLimit;

  @override
  final Duration timeRetry;

  @override
  final String? cacheKey;

  /// print error
  @override
  final bool printError;

  @override
  final bool cacheRawData;

  /// The name of [ImageCache], you can define custom [ImageCache] to store this provider.
  @override
  final String? imageCacheName;

  /// The duration before local cache is expired.
  /// After this time the cache is expired and the image is reloaded.
  @override
  final Duration? cacheMaxAge;

  @override
  Future<ExtendedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<ExtendedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      image_provider.ExtendedNetworkImageProvider key,
      ImageDecoderCallback decode) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode, chunkEvents),
      scale: key.scale,
      chunkEvents: chunkEvents.stream,
      informationCollector: () {
        return <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<image_provider.ExtendedNetworkImageProvider>(
              'Image key', key),
        ];
      },
    );
  }

  // TODO(garyq): We should eventually support custom decoding of network images on Web as
  // well, see https://github.com/flutter/flutter/issues/42789.
  //
  // Web does not support decoding network images to a specified size. The decode parameter
  // here is ignored and the web-only `ui.webOnlyInstantiateImageCodecFromUrl` will be used
  // directly in place of the typical `instantiateImageCodec` method.
  Future<ui.Codec> _loadAsync(
      image_provider.ExtendedNetworkImageProvider key,
      ImageDecoderCallback decode,
      StreamController<ImageChunkEvent> chunkEvents) async {
    assert(key == this);

    final Uri resolved = Uri.base.resolve(key.url);

    final bool containsNetworkImageHeaders = key.headers?.isNotEmpty ?? false;

    // We use a different method when headers are set because the
    // `ui.webOnlyInstantiateImageCodecFromUrl` method is not capable of handling headers.
    if (isCanvasKit || containsNetworkImageHeaders) {
      final Completer<DomXMLHttpRequest> completer =
          Completer<DomXMLHttpRequest>();
      final DomXMLHttpRequest request = httpRequestFactory();

      request.open('GET', key.url, true);
      request.responseType = 'arraybuffer';
      if (containsNetworkImageHeaders) {
        key.headers!.forEach((String header, String value) {
          request.setRequestHeader(header, value);
        });
      }

      request.addEventListener('load', createDomEventListener((DomEvent e) {
        final int? status = request.status;
        final bool accepted = status! >= 200 && status < 300;
        final bool fileUri = status == 0; // file:// URIs have status of 0.
        final bool notModified = status == 304;
        final bool unknownRedirect = status > 307 && status < 400;
        final bool success =
            accepted || fileUri || notModified || unknownRedirect;

        if (success) {
          completer.complete(request);
        } else {
          completer.completeError(e);
          throw NetworkImageLoadException(
              statusCode: request.status ?? 400, uri: resolved);
        }
      }));

      request.addEventListener(
          'error', createDomEventListener(completer.completeError));

      request.send();

      await completer.future;

      final Uint8List bytes =
          (request.response! as JSArrayBuffer).toDart.asUint8List();

      if (bytes.lengthInBytes == 0) {
        throw NetworkImageLoadException(
            statusCode: request.status!, uri: resolved);
      }

      final ui.ImmutableBuffer buffer =
          await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } else {
      // This API only exists in the web engine implementation and is not
      // contained in the analyzer summary for Flutter.
      // ignore: undefined_function, avoid_dynamic_calls
      return ui.webOnlyInstantiateImageCodecFromUrl(
        resolved,
        chunkCallback: (int bytes, int total) {
          chunkEvents.add(ImageChunkEvent(
              cumulativeBytesLoaded: bytes, expectedTotalBytes: total));
        },
      ) as Future<ui.Codec>;
    }
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExtendedNetworkImageProvider &&
        url == other.url &&
        scale == other.scale &&
        //cacheRawData == other.cacheRawData &&
        imageCacheName == other.imageCacheName;
  }

  @override
  int get hashCode => Object.hash(
        url,
        scale,
        //cacheRawData,
        imageCacheName,
      );

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';

  // not support on web
  @override
  Future<Uint8List?> getNetworkImageData({
    StreamController<ImageChunkEvent>? chunkEvents,
  }) {
    return Future<Uint8List>.error('not support on web');
  }

  static dynamic get httpClient => null;
}
