import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/widgets/travel_edit_sheet.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  for (final update in [true, false]) {
    testWidgets(update ? '更新移動段遇到 409 保留輸入並允許再次送出' : '新增移動段失敗保留輸入，重試成功才關閉', (
      tester,
    ) async {
      final repository = _MockTripRepository();
      final first = Completer<TripSegment>();
      final retry = Completer<TripSegment>();
      var requests = 0;
      const saved = TripSegment(
        id: 50,
        fromEntryId: 11,
        toEntryId: 12,
        mode: 'transit',
        submode: '接駁船',
        min: 25,
        version: 2,
      );
      Future<TripSegment> request() =>
          ++requests == 1 ? first.future : retry.future;
      if (update) {
        when(
          () => repository.updateSegment(
            tripId: 'trip-1',
            segmentId: 50,
            mode: 'transit',
            submode: '接駁船',
            clearSubmode: false,
            min: 25,
            noTravel: false,
            expectedVersion: 1,
          ),
        ).thenAnswer((_) => request());
      } else {
        when(
          () => repository.createSegment(
            tripId: 'trip-1',
            fromEntryId: 11,
            toEntryId: 12,
            mode: 'transit',
            submode: '接駁船',
            min: 25,
            noTravel: false,
          ),
        ).thenAnswer((_) => request());
      }
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
                    segment: update
                        ? const TripSegment(
                            id: 50,
                            fromEntryId: 11,
                            toEntryId: 12,
                            mode: 'driving',
                            version: 1,
                          )
                        : null,
                    fromEntryId: 11,
                    toEntryId: 12,
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
      final mode = find.byKey(const ValueKey('travel-mode-transit'));
      final name = find.byKey(const ValueKey('travel-other-name'));
      final minutes = find.byKey(const ValueKey('travel-min'));
      final submit = find.byKey(const ValueKey('travel-submit'));
      await tester.tap(mode);
      await tester.pump();
      await tester.enterText(name, '接駁船');
      await tester.enterText(minutes, '25');
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      expect(requests, 1, reason: '公開表單送出指定的交通方式、分鐘與端點');
      await tester.tap(submit);
      await tester.tap(find.text('取消'));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, 1, reason: '等待回應時不可重複提交');
      expect(find.text('交通方式'), findsOneWidget);
      expect(find.text('捨棄未儲存的變更？'), findsNothing);

      first.completeError(
        update
            ? const ApiError(status: 409, code: 'STALE_ENTRY', message: '版本衝突')
            : const ApiError(
                status: 503,
                code: 'SYS_UPSTREAM_UNAVAILABLE',
                message: '服務暫時無法使用',
              ),
      );
      await tester.pumpAndSettle();
      expect(find.text(update ? '交通已更新，已重新載入' : '更新失敗，請稍後再試'), findsOneWidget);
      expect(find.text('交通方式'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(mode).selected, isTrue);
      expect(tester.widget<TextField>(name).controller?.text, '接駁船');
      expect(tester.widget<TextField>(minutes).controller?.text, '25');

      await tester.tap(submit);
      await tester.pump();
      expect(requests, 2, reason: '失敗解除送出鎖定，原輸入可再次送出');
      expect(find.text('交通方式'), findsOneWidget);
      if (update) {
        // 既有 OCC 版本策略不保證重試成功，只驗證再次衝突仍保留表單。
        retry.completeError(
          const ApiError(status: 409, code: 'STALE_ENTRY', message: '版本衝突'),
        );
        await tester.pumpAndSettle();
        expect(find.text('交通方式'), findsOneWidget);
        expect(tester.widget<TextField>(name).controller?.text, '接駁船');
        expect(tester.widget<TextField>(minutes).controller?.text, '25');
      } else {
        retry.complete(saved);
        await tester.pumpAndSettle();
        expect(find.text('交通方式'), findsNothing);
        expect(find.text('已更新交通'), findsOneWidget);
      }
    });
  }

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
