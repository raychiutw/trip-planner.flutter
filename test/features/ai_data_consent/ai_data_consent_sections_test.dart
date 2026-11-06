import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/ai_data_consent/ai_data_consent_sections.dart';
import 'package:tripline/models/ai_data_consent.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  testWidgets('已撤回橫幅在手機寬度下正好兩行，沒有孤字（A26）', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: AiDataConsentStatusBanner(
              status: AiDataConsentStatus.withdrawn,
            ),
          ),
        ),
      ),
    );

    final text = find.descendant(
      of: find.byKey(const ValueKey('ai-data-consent-banner')),
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(text.first);
    final lines = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: paragraph.text.toPlainText().length,
      ),
    );
    // 每個選取框是一行；兩個句子各佔一行，且末行不會只剩一兩個字。
    expect(lines.length, 2);
    expect(lines.last.toRect().width, greaterThan(100));
  });
}
