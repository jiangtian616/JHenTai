import 'dart:convert';
import 'package:crypto/crypto.dart';

class HmacUtil {
  static String hmacSha256(String data, String secretKey) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(data);

    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return base64.encode(digest.bytes);
  }
}
