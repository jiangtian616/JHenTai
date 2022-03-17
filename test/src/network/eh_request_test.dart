import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1', () async {
    print('main');
    await m1();
    print('main');
  });
}

Future<void> m1() async {
  print('m1');
  m2();
  print('m1');
  m3();
  print('m1');
}

Future<void> m2() async {
  print('m2');
  Future.delayed(Duration(seconds: 1));
  print('m2');
}

Future<void> m3() async {
  print('m3');
  Future.delayed(Duration(seconds: 1));
  print('m3');
}
