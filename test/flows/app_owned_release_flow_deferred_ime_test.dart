import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/app_flow_fixture.dart';

/// 模擬 Android IME：文字欄取得焦點時鍵盤立刻佔住 viewInsets，失焦後的收合卻是
/// 平台端非同步動作，viewInsets 要等 [hideLatency] 才歸零，不隨 Flutter 幀推進。
/// 以 [FocusManager] 為 seam，因為 host binding 的 TextInput channel 由
/// TestTextInput 持有，而 EditableText 的 show／hide 本來就跟著焦點走。
class _DeferredHideKeyboard {
  _DeferredHideKeyboard(this.tester, {required this.hideLatency});

  final WidgetTester tester;
  final Duration hideLatency;
  Timer? _pendingHide;
  bool _shown = false;

  void attach() => FocusManager.instance.addListener(_onFocusChanged);

  void detach() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _pendingHide?.cancel();
  }

  void _onFocusChanged() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    final editing =
        focusContext != null &&
        focusContext.findAncestorStateOfType<EditableTextState>() != null;
    if (editing) {
      _pendingHide?.cancel();
      _pendingHide = null;
      if (!_shown) {
        _shown = true;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      }
      return;
    }
    if (_shown && _pendingHide == null) {
      _pendingHide = Timer(hideLatency, () {
        _pendingHide = null;
        _shown = false;
        tester.view.viewInsets = FakeViewPadding.zero;
      });
    }
  }
}

void main() {
  testWidgets('app-owned release flow 在 IME 延遲收合時仍能回到 root tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    // Test Lab MediumPhone.arm 實測 hide 請求到 onHidden 相隔 2.9s；取 3s。
    final keyboard = _DeferredHideKeyboard(
      tester,
      hideLatency: const Duration(seconds: 3),
    );
    keyboard.attach();
    addTearDown(keyboard.detach);
    await runAppOwnedReleaseFlow(tester);
  });
}
