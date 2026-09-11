import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:patrol/patrol.dart';
import 'package:tripline/features/map/map_adapter.dart';

import '../integration_test/support/app_flow_fixture.dart';
import 'support/ios_system_alerts.dart';

void main() {
  patrolTest('app-owned release flow stays off production services', ($) async {
    await dismissStaleSpringBoardTutorial($);
    await runAppOwnedReleaseFlow(
      $.tester,
      enterText: (finder, text) =>
          $.enterText(finder, text, hideKeyboard: false),
    );
  });

  // 同一份真機 artifact 內的視覺證據：production chrome 疊在真實 Google 地圖與
  // 文字列表上，明暗走 App 外觀設定，無障礙情境由測試 wrapper 注入並在 log 標明。
  patrolTest(
    'app-owned visual evidence walks production chrome on a real map',
    ($) async {
      await dismissStaleSpringBoardTutorial($);
      // 與 lib/main.dart 相同的公開玻璃 bootstrap：shader 預熱、自適應品質，
      // 以及等值重現的品牌 tint 光暈主題（見 productionEquivalentGlassTheme）。
      await LiquidGlassWidgets.initialize();
      await runAppOwnedVisualEvidenceFlow(
        $.tester,
        mapEvidence: TripMapCanvasEvidence(canvas: buildTripMapCanvas),
        enterText: (finder, text) =>
            $.enterText(finder, text, hideKeyboard: false),
        appWrapper: (child) => LiquidGlassWidgets.wrap(
          theme: productionEquivalentGlassTheme(),
          adaptiveQuality: true,
          adaptiveConfig: GlassAdaptiveScopeConfig(
            onDiagnostic: (diagnostic) => debugPrint(
              'Tripline visual evidence | glass quality '
              '${diagnostic.from.name} → ${diagnostic.to.name}'
              ' (${diagnostic.reason.name}, p75=${diagnostic.p75Ms}ms)',
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
