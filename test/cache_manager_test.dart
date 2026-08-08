import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/network/eh_cache_manager.dart';

void main() {
  group('CacheResponse.willExpireSoon', () {
    CacheResponse build(DateTime expireDate) => CacheResponse(
          url: 'https://example.com/gallery/1',
          cacheKey: 'k',
          content: Uint8List(0),
          headers: Uint8List(0),
          expireDate: expireDate,
        );

    test('renews when the remaining time is within 10% of the TTL', () {
      // 5 minutes left out of a 1 hour TTL (10% = 6 minutes) => renew
      final expireDate = DateTime.now().add(const Duration(minutes: 5));
      expect(build(expireDate).willExpireSoon(const Duration(hours: 1)), isTrue);
    });

    test('skips renewal when the entry is far from expiring', () {
      // 50 minutes left out of a 1 hour TTL => no write needed
      final expireDate = DateTime.now().add(const Duration(minutes: 50));
      expect(build(expireDate).willExpireSoon(const Duration(hours: 1)), isFalse);
    });

    test('renews an already-expired entry', () {
      final expireDate = DateTime.now().subtract(const Duration(seconds: 1));
      expect(build(expireDate).willExpireSoon(const Duration(hours: 1)), isTrue);
    });

    test('never renews when the TTL is zero or negative', () {
      final expireDate = DateTime.now().add(const Duration(seconds: 1));
      expect(build(expireDate).willExpireSoon(Duration.zero), isFalse);
      expect(build(expireDate).willExpireSoon(const Duration(seconds: -1)), isFalse);
    });
  });

  group('CacheResponse gzip content', () {
    test('fromResponseAsync stores gzip and toResponse returns the original', () async {
      final response = Response(
        data: '<html><body>hello world</body></html>',
        requestOptions: RequestOptions(
          path: 'https://example.com/gallery/1',
          responseType: ResponseType.plain,
        )..extra[EHCacheManager.realUriExtraKey] =
            'https://example.com/gallery/1',
      );

      final cacheResponse = await CacheResponse.fromResponseAsync(
          response,
          const CacheOptions(
              policy: CachePolicy.disable,
              expire: Duration(hours: 1)));

      // The stored content must actually be gzip (header 0x1f 0x8b) and
      // smaller than the original for repetitive text.
      expect(cacheResponse.content.length, greaterThan(2));
      expect(cacheResponse.content[0], 0x1f);
      expect(cacheResponse.content[1], 0x8b);

      final decoded = cacheResponse.toResponse(response.requestOptions);
      expect(decoded.data, '<html><body>hello world</body></html>');
    });

    test('toResponse falls back to raw content for legacy uncompressed entries', () {
      final legacy = CacheResponse(
        url: 'https://example.com/gallery/1',
        cacheKey: 'k',
        content: utf8.encode('plain uncompressed body'),
        headers: utf8.encode('{"content-type":["text/html"]}'),
        expireDate: DateTime.now().add(const Duration(hours: 1)),
      );

      final decoded = legacy.toResponse(RequestOptions(
        path: 'https://example.com/gallery/1',
        responseType: ResponseType.plain,
      ));
      expect(decoded.data, 'plain uncompressed body');
    });
  });
}
