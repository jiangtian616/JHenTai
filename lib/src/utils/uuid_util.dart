import 'package:uuid/v1.dart';

const UuidV1 uuid = UuidV1();

String newUUID() {
  return uuid.generate();
}
