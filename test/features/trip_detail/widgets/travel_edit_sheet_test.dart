import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/features/trip_detail/widgets/travel_edit_sheet.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/segment.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void main() {
  testWidgets('移動段衝突刷新後保留草稿，確認後以最新版本儲存', (tester) async {
    final repository = _MockTripRepository();
    const initial = TripSegment(
      id: 50,
      fromEntryId: 11,
      toEntryId: 12,
      mode: 'driving',
      min: 10,
      source: 'manual',
      version: 1,
    );
    const remote = TripSegment(
      id: 50,
      fromEntryId: 11,
      toEntryId: 12,
      mode: 'driving',
      min: 40,
      source: 'manual',
      version: 2,
    );
    const saved = TripSegment(
      id: 50,
      fromEntryId: 11,
      toEntryId: 12,
      mode: 'driving',
      min: 25,
      source: 'manual',
      version: 3,
    );
    final refresh = Completer<List<TripSegment>>();
    var reads = 0;
    final submittedVersions = <int?>[];
    when(() => repository.watchSegments(tripId: 'trip-1')).thenAnswer((_) {
      reads++;
      return reads == 1 ? Stream.value([initial]) : refresh.future.asStream();
    });
    when(
      () => repository.updateSegment(
        tripId: 'trip-1',
        segmentId: 50,
        mode: 'driving',
        submode: null,
        clearSubmode: true,
        min: 25,
        noTravel: false,
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer((invocation) async {
      final version = invocation.namedArguments[#expectedVersion] as int?;
      submittedVersions.add(version);
      if (version != 2) {
        throw const ApiError(status: 409, code: 'STALE_ENTRY', message: '版本衝突');
      }
      return saved;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Consumer(
            builder: (context, ref, child) {
              // 模擬時間軸持續 watch 正式 family，sheet 開啟後仍會收到刷新。
              final segments = ref.watch(tripSegmentsProvider('trip-1')).value;
              return Scaffold(
                body: FilledButton(
                  onPressed: segments == null
                      ? null
                      : () => showTravelEditSheet(
                          context,
                          tripId: 'trip-1',
                          segment: segments.single,
                        ),
                  child: const Text('開啟'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    final minutes = find.byKey(const ValueKey('travel-min'));
    final submit = find.byKey(const ValueKey('travel-submit'));
    await tester.enterText(minutes, '25');
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump();
    expect(submittedVersions, [1]);
    expect(reads, greaterThanOrEqualTo(2), reason: '409 會重新載入正式移動段來源');

    refresh.complete([remote]);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(minutes).controller?.text, '25');
    expect(submittedVersions, [1], reason: '取得對方版本不可自動覆蓋');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('保留你的版本？'), findsOneWidget);
    expect(submittedVersions, [1], reason: '需明確確認才覆蓋衝突欄位');
    await tester.tap(find.text('保留我的版本'));
    await tester.pumpAndSettle();
    expect(submittedVersions, [1, 2]);
    expect(find.text('交通方式'), findsNothing);
    expect(find.text('已更新交通'), findsOneWidget);
  });

  testWidgets('移動段刷新缺少新版時提示重試並保留草稿，後續新版仍可恢復', (tester) async {
    final repository = _MockTripRepository();
    const initial = TripSegment(
      id: 50,
      fromEntryId: 11,
      toEntryId: 12,
      mode: 'driving',
      min: 10,
      source: 'manual',
      version: 1,
    );
    const remote = TripSegment(
      id: 50,
      fromEntryId: 11,
      toEntryId: 12,
      mode: 'driving',
      min: 40,
      source: 'manual',
      version: 2,
    );
    const saved = TripSegment(
      id: 50,
      fromEntryId: 11,
      toEntryId: 12,
      mode: 'driving',
      min: 25,
      source: 'manual',
      version: 3,
    );
    final refresh = StreamController<List<TripSegment>>.broadcast();
    addTearDown(refresh.close);
    var reads = 0;
    final submittedVersions = <int?>[];
    when(() => repository.watchSegments(tripId: 'trip-1')).thenAnswer((_) {
      reads++;
      return reads == 1 ? Stream.value([initial]) : refresh.stream;
    });
    when(
      () => repository.updateSegment(
        tripId: 'trip-1',
        segmentId: 50,
        mode: 'driving',
        submode: null,
        clearSubmode: true,
        min: 25,
        noTravel: false,
        expectedVersion: any(named: 'expectedVersion'),
      ),
    ).thenAnswer((invocation) async {
      final version = invocation.namedArguments[#expectedVersion] as int?;
      submittedVersions.add(version);
      if (version != 2) {
        throw const ApiError(status: 409, code: 'STALE_ENTRY', message: '版本衝突');
      }
      return saved;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tripRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Consumer(
            builder: (context, ref, child) {
              // 模擬時間軸持續 watch 正式 family，sheet 開啟後仍會收到刷新。
              final segments = ref.watch(tripSegmentsProvider('trip-1')).value;
              return Scaffold(
                body: FilledButton(
                  onPressed: segments == null
                      ? null
                      : () => showTravelEditSheet(
                          context,
                          tripId: 'trip-1',
                          segment: segments.single,
                        ),
                  child: const Text('開啟'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();
    final minutes = find.byKey(const ValueKey('travel-min'));
    final submit = find.byKey(const ValueKey('travel-submit'));
    await tester.enterText(minutes, '25');
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump();
    expect(submittedVersions, [1]);
    expect(reads, greaterThanOrEqualTo(2), reason: '409 會重新載入正式移動段來源');

    refresh.add([]);
    await tester.pumpAndSettle();
    final unavailable = find.text('無法確認最新交通設定。你的修改已保留，請重試。');
    expect(unavailable.hitTestable(), findsOneWidget);
    expect(find.text('重試').hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(minutes).controller?.text, '25');
    await tester.tap(submit);
    await tester.pump();
    expect(submittedVersions, [1], reason: '缺 row 不可用原版本送出，也不可假定已刪除');

    refresh.add([initial]);
    await tester.pumpAndSettle();
    expect(unavailable.hitTestable(), findsOneWidget);
    await tester.tap(submit);
    await tester.pump();
    expect(submittedVersions, [1], reason: '同版本快取不是解除衝突的新版本');

    refresh.add([remote]);
    await tester.pumpAndSettle();
    expect(unavailable, findsNothing);
    expect(tester.widget<TextField>(minutes).controller?.text, '25');
    expect(submittedVersions, [1], reason: '取得對方版本不可自動覆蓋');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('保留你的版本？'), findsOneWidget);
    expect(submittedVersions, [1], reason: '需明確確認才覆蓋衝突欄位');
    await tester.tap(find.text('保留我的版本'));
    await tester.pumpAndSettle();
    expect(submittedVersions, [1, 2]);
    expect(find.text('交通方式'), findsNothing);
    expect(find.text('已更新交通'), findsOneWidget);
  });

  for (final update in [true, false]) {
    testWidgets(update ? '移動段衝突刷新失敗保留草稿，重試載入後才允許儲存' : '新增移動段失敗保留輸入，重試成功才關閉', (
      tester,
    ) async {
      final repository = _MockTripRepository();
      final first = Completer<TripSegment>();
      final retry = Completer<TripSegment>();
      var requests = 0;
      final submittedVersions = <int?>[];
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
        when(() => repository.watchSegments(tripId: 'trip-1')).thenAnswer(
          (_) => Stream.error(
            const ApiError(
              status: 503,
              code: 'SYS_UPSTREAM_UNAVAILABLE',
              message: '服務暫時無法使用',
            ),
          ),
        );
        when(
          () => repository.updateSegment(
            tripId: 'trip-1',
            segmentId: 50,
            mode: 'transit',
            submode: '接駁船',
            clearSubmode: false,
            min: 25,
            noTravel: false,
            expectedVersion: any(named: 'expectedVersion'),
          ),
        ).thenAnswer((invocation) {
          submittedVersions.add(
            invocation.namedArguments[#expectedVersion] as int?,
          );
          return request();
        });
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
          retry: (retryCount, error) => null,
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
      expect(
        find.text(update ? '無法載入最新交通設定。你的修改已保留，請重試。' : '更新失敗，請稍後再試'),
        findsOneWidget,
      );
      expect(find.text('交通方式'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(mode).selected, isTrue);
      expect(tester.widget<TextField>(name).controller?.text, '接駁船');
      expect(tester.widget<TextField>(minutes).controller?.text, '25');

      if (update) {
        await tester.tap(submit);
        await tester.pump();
        expect(submittedVersions, [1], reason: '刷新失敗不可用已過期版本重送');
        when(() => repository.watchSegments(tripId: 'trip-1')).thenAnswer(
          (_) => Stream.value([
            const TripSegment(
              id: 50,
              fromEntryId: 11,
              toEntryId: 12,
              mode: 'driving',
              min: 40,
              source: 'manual',
              version: 2,
            ),
          ]),
        );
        await tester.tap(find.text('重試'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(name).controller?.text, '接駁船');
        expect(tester.widget<TextField>(minutes).controller?.text, '25');
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('保留你的版本？'), findsOneWidget);
        expect(submittedVersions, [1]);
        await tester.tap(find.text('保留我的版本'));
        await tester.pump();
        expect(submittedVersions, [1, 2]);
      } else {
        await tester.tap(submit);
        await tester.pump();
      }
      expect(requests, 2, reason: '保留的草稿可在恢復後再次送出');
      expect(find.text('交通方式'), findsOneWidget);
      retry.complete(saved);
      await tester.pumpAndSettle();
      expect(find.text('交通方式'), findsNothing);
      expect(find.text('已更新交通'), findsOneWidget);
    });
  }

  testWidgets('移動段保存遇到 500 時錯誤在 sheet 內持續可讀，草稿可再次儲存', (tester) async {
    final repository = _MockTripRepository();
    var requests = 0;
    const segment = TripSegment(id: 50, mode: 'driving', version: 1);
    when(
      () => repository.updateSegment(
        tripId: 'trip-1',
        segmentId: 50,
        mode: 'driving',
        submode: null,
        clearSubmode: true,
        min: 25,
        noTravel: false,
        expectedVersion: 1,
      ),
    ).thenAnswer((_) async {
      if (++requests == 1) {
        throw const ApiError(
          status: 500,
          code: 'INTERNAL_ERROR',
          message: '內部錯誤',
        );
      }
      return const TripSegment(id: 50, mode: 'driving', min: 25, version: 2);
    });
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
                  segment: segment,
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
    final minutes = find.byKey(const ValueKey('travel-min'));
    final submit = find.byKey(const ValueKey('travel-submit'));
    await tester.enterText(minutes, '25');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    final error = find.text('更新失敗，請稍後再試');
    expect(
      error.hitTestable(),
      findsOneWidget,
      reason: '錯誤不能藏在 modal barrier 後方',
    );
    expect(
      find.ancestor(
        of: error,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(minutes).controller?.text, '25');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('交通方式'), findsNothing);
  });

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
