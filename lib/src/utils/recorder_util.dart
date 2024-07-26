import 'package:jhentai/src/service/log.dart';

Future<void> recordTimeCost(String name, Function function) async {
  DateTime startTime = DateTime.now();
  await function.call();
  DateTime endTime = DateTime.now();
  log.trace('Time cost of $name: ${endTime.difference(startTime).inMilliseconds}ms');
}
