import 'package:jhentai/src/utils/log.dart';

Future<void> recordTimeCost(String name, Function function) async {
  DateTime startTime = DateTime.now();
  await function.call();
  DateTime endTime = DateTime.now();
  Log.verbose('Time cost of $name: ${endTime.difference(startTime).inMilliseconds}ms');
}
