import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/pages/gallery/dashboard/dashboard_page_logic.dart';
import 'package:jhentai/src/pages/gallery/dashboard/dashboard_page_state.dart';

/// Regression: the Apple slide-down quick-search overlay state used to live in
/// widget-local fields on [DashboardPage] (a StatelessWidget). Because the
/// mobile layout rebuilds the page whenever the system keyboard changes
/// viewInsets, opening the search bar popped the keyboard up, which rebuilt
/// the page, which reset the bar and the focus node — the bar and keyboard
/// "flashed" once and instantly closed.
///
/// The overlay state now lives on the persistent [DashboardPageState], owned by
/// the permanent [DashboardPageLogic] controller, so recreating the widget does
/// not tear the overlay down.
void main() {
  test('search overlay state is hosted on the persistent page state', () {
    final DashboardPageLogic logic = DashboardPageLogic();
    final DashboardPageState state = logic.state;

    // Fresh page: overlay closed and unfocused.
    expect(state.searchVisible.value, isFalse);
    expect(state.searchFocusNode.hasFocus, isFalse);
    expect(state.searchController.text, isEmpty);

    // Mirrors DashboardPage._toggleSearch: the toggle mutates the persistent
    // state object, so a parent layout rebuild that recreates the DashboardPage
    // widget cannot reset the overlay back to hidden.
    state.searchVisible.value = true;
    expect(state.searchVisible.value, isTrue);

    state.searchController.text = 'sample';
    expect(state.searchController.text, 'sample');

    state.searchVisible.value = false;
    expect(state.searchVisible.value, isFalse);
  });

  test('DashboardPageLogic.onClose releases the search overlay resources', () {
    final DashboardPageLogic logic = DashboardPageLogic();
    // Must not throw even though the overlay was opened first.
    logic.state.searchVisible.value = true;
    logic.onClose();
  });
}
