import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/widgets/travel_edit_sheet.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  testWidgets('取消已修改交通表單會確認捨棄且不更新 API', (tester) async {
    final repository = _MockTripRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showTravelEditSheet(
                  context,
                  tripId: 'trip-1',
                  segment: const TripSegment(
                    id: 50,
                    fromEntryId: 11,
                    toEntryId: 12,
                    mode: 'driving',
                    version: 1,
                  ),
                ),
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    expect(find.text('交通方式'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('travel-mode-walking')));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);

    await tester.tap(find.text('捨棄'));
    await tester.pumpAndSettle();
    expect(find.text('交通方式'), findsNothing);
    verifyNever(
      () => repository.updateSegment(
        tripId: any(named: 'tripId'),
        segmentId: any(named: 'segmentId'),
        mode: any(named: 'mode'),
        submode: any(named: 'submode'),
        clearSubmode: any(named: 'clearSubmode'),
        min: any(named: 'min'),
        noTravel: any(named: 'noTravel'),
        expectedVersion: any(named: 'expectedVersion'),
      ),
    );
  });

  testWidgets('缺 segment 時以 Travel 物件帶入初始值,不再拆成五個欄位', (tester) async {
    final repository = _MockTripRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showTravelEditSheet(
                  context,
                  tripId: 'trip-1',
                  fromEntryId: 11,
                  toEntryId: 12,
                  travel: const Travel(
                    type: 'walking',
                    min: 12,
                    source: 'manual',
                  ),
                ),
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    final minField = tester.widget<TextField>(
      find.byKey(const ValueKey('travel-min')),
    );
    expect(minField.controller?.text, '12', reason: 'Travel.min 帶進分鐘欄');
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('travel-mode-walking')))
          .selected,
      isTrue,
      reason: 'Travel.type 帶進交通方式',
    );
  });

  testWidgets('Travel.sameplace 帶進「不需計算路程」', (tester) async {
    final repository = _MockTripRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showTravelEditSheet(
                  context,
                  tripId: 'trip-1',
                  fromEntryId: 11,
                  toEntryId: 12,
                  travel: const Travel(type: 'car', sameplace: true),
                ),
                child: const Text('開啟'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('travel-mode-no-travel')),
          )
          .selected,
      isTrue,
    );
  });
}
