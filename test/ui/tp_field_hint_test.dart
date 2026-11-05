import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';
import 'package:tripline/ui/tp_field_hint.dart';

void main() {
  testWidgets('說明字左緣與同寬 TextField 的內文對齊，頂端留 s1', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: ValueKey('f'),
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              TpFieldHint('提示', textKey: ValueKey('h')),
            ],
          ),
        ),
      ),
    );
    final fieldText = tester.getTopLeft(
      find.descendant(
        of: find.byKey(const ValueKey('f')),
        matching: find.byType(EditableText),
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('h'))).dx,
      closeTo(fieldText.dx, 2),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('h'))).dy -
          tester.getBottomLeft(find.byKey(const ValueKey('f'))).dy,
      TpSpacing.s1,
    );
  });
}
