import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/routes/eh_page.dart';
import 'package:jhentai/src/routes/routes.dart';

void main() {
  test('LAN sharing keeps Advanced Settings in the right route stack', () {
    final EHPage route = Routes.pages.firstWhere(
      (page) => page.name == Routes.lanSharing,
    );

    expect(route.side, Side.right);
    expect(route.offAllBefore, isFalse);
  });
}
