import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';

/// 無障礙語意旗標的斷言輔助。呼叫端須先 `tester.ensureSemantics()`。
extension SemanticsFlagsX on WidgetTester {
  bool isLiveRegionOf(Finder finder) =>
      getSemantics(finder).getSemanticsData().flagsCollection.isLiveRegion;

  bool isHeaderOf(Finder finder) =>
      getSemantics(finder).getSemanticsData().flagsCollection.isHeader;

  bool isSelectedOf(Finder finder) =>
      getSemantics(finder).getSemanticsData().flagsCollection.isSelected ==
      Tristate.isTrue;

  bool isToggledOf(Finder finder) =>
      getSemantics(finder).getSemanticsData().flagsCollection.isToggled ==
      Tristate.isTrue;
}
