import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trip_detail/entry_edit_route_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

void _stubSuccessfulEntryUpdate(_MockTripRepository repository) {
  when(
    () => repository.updateEntry(
      tripId: any(named: 'tripId'),
      entryId: any(named: 'entryId'),
      expectedVersion: any(named: 'expectedVersion'),
      description: any(named: 'description'),
      startTime: any(named: 'startTime'),
      endTime: any(named: 'endTime'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => repository.recomputeTravel(tripId: 'trip-1'),
  ).thenAnswer((_) async {});
}

const _entry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  startTime: '09:00',
  endTime: '10:00',
  title: '首里城',
  description: '世界遺產',
  version: 2,
);

const _updatedEntry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  startTime: '09:00',
  endTime: '10:00',
  title: '首里城',
  description: '更新後的說明',
  version: 3,
);

const _secondEntry = TimelineEntry(
  id: 12,
  sortOrder: 1,
  startTime: '11:00',
  endTime: '12:00',
  title: '玉陵',
  description: '第二個停留點',
  version: 1,
);

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/edit',
        builder: (context, state) =>
            const EntryEditRouteScreen(tripId: 'trip-1', entryId: 11),
      ),
      GoRoute(
        path: '/trips/:tripId',
        builder: (context, state) => const Scaffold(body: Text('行程頁')),
      ),
    ],
  );
}

Widget _buildApp(
  _MockTripRepository repository, {
  bool overrideEntry = true,
  GoRouter? router,
}) {
  return ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(repository),
      if (overrideEntry)
        entryDetailProvider((
          tripId: 'trip-1',
          entryId: 11,
        )).overrideWith((ref) => Stream.value(_entry)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      routerConfig: router ?? _buildRouter(),
    ),
  );
}

void main() {
  testWidgets('跨行程共用相同 entry id 時不沿用前一行程草稿', (tester) async {
    final repository = _MockTripRepository();
    final firstEntries = StreamController<TimelineEntry>.broadcast();
    final secondEntries = StreamController<TimelineEntry>.broadcast();
    final selectedTripId = ValueNotifier('trip-1');
    const trip2Entry = TimelineEntry(
      id: 11,
      sortOrder: 0,
      startTime: '13:00',
      endTime: '14:00',
      title: '大阪城',
      description: 'trip-2 正確內容',
      version: 1,
    );
    addTearDown(firstEntries.close);
    addTearDown(secondEntries.close);
    addTearDown(selectedTripId.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          entryDetailProvider((
            tripId: 'trip-1',
            entryId: 11,
          )).overrideWith((ref) => firstEntries.stream),
          entryDetailProvider((
            tripId: 'trip-2',
            entryId: 11,
          )).overrideWith((ref) => secondEntries.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Stack(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: selectedTripId,
                builder: (context, tripId, _) => EntryEditRouteScreen(
                  key: const ValueKey('reused-entry-editor'),
                  tripId: tripId,
                  entryId: 11,
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  ref.watch(
                    entryDetailProvider((tripId: 'trip-2', entryId: 11)),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );

    firstEntries.add(_entry);
    secondEntries.add(trip2Entry);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      'trip-1 未儲存草稿',
    );

    selectedTripId.value = 'trip-2';
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'trip-2 正確內容'), findsOneWidget);
    expect(find.text('trip-1 未儲存草稿'), findsNothing);
  });

  testWidgets('route 參數切換時不沿用前一個停留點與草稿', (tester) async {
    final repository = _MockTripRepository();
    final firstEntries = StreamController<TimelineEntry>.broadcast();
    final secondEntries = StreamController<TimelineEntry>.broadcast();
    final selectedEntryId = ValueNotifier(11);
    addTearDown(firstEntries.close);
    addTearDown(secondEntries.close);
    addTearDown(selectedEntryId.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          entryDetailProvider((
            tripId: 'trip-1',
            entryId: 11,
          )).overrideWith((ref) => firstEntries.stream),
          entryDetailProvider((
            tripId: 'trip-1',
            entryId: 12,
          )).overrideWith((ref) => secondEntries.stream),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ValueListenableBuilder<int>(
            valueListenable: selectedEntryId,
            builder: (context, entryId, _) => EntryEditRouteScreen(
              key: const ValueKey('reused-entry-editor'),
              tripId: 'trip-1',
              entryId: entryId,
            ),
          ),
        ),
      ),
    );

    firstEntries.add(_entry);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '第一個停留點的未儲存草稿',
    );

    selectedEntryId.value = 12;
    await tester.pump();
    expect(
      find.byKey(const ValueKey('entry-edit-loading')),
      findsOneWidget,
      reason: '等待新 entry 時不得繼續顯示舊 entry',
    );
    expect(find.text('第一個停留點的未儲存草稿'), findsNothing);

    secondEntries.add(_secondEntry);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '第二個停留點'), findsOneWidget);
    expect(find.text('第一個停留點的未儲存草稿'), findsNothing);
  });

  testWidgets('編輯停留點 route 使用取消／儲存 header 且不重複底部按鈕', (tester) async {
    final repository = _MockTripRepository();
    _stubSuccessfulEntryUpdate(repository);

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('儲存'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    expect(find.byKey(const ValueKey('entry-edit-title')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '更新後的說明',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateEntry(
        tripId: 'trip-1',
        entryId: 11,
        expectedVersion: 2,
        description: '更新後的說明',
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
    expect(find.text('行程頁'), findsOneWidget);
  });

  testWidgets('SWR fresh entry 到達時更新未編輯的備註與 OCC version', (tester) async {
    final repository = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    when(
      () => repository.watchEntry(tripId: 'trip-1', entryId: 11),
    ).thenAnswer((_) => entries.stream);
    _stubSuccessfulEntryUpdate(repository);

    await tester.pumpWidget(_buildApp(repository, overrideEntry: false));

    entries.add(_entry);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '世界遺產'), findsOneWidget);

    entries.add(_updatedEntry);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '更新後的說明'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '第二次更新',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateEntry(
        tripId: 'trip-1',
        entryId: 11,
        expectedVersion: 3,
        description: '第二次更新',
        startTime: '09:00',
        endTime: '10:00',
      ),
    ).called(1);
  });

  testWidgets('協作者更新未編輯的時間時，只保留本機已修改的備註', (tester) async {
    final repository = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    when(
      () => repository.watchEntry(tripId: 'trip-1', entryId: 11),
    ).thenAnswer((_) => entries.stream);
    _stubSuccessfulEntryUpdate(repository);

    await tester.pumpWidget(_buildApp(repository, overrideEntry: false));
    entries.add(_entry);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '我的備註修改',
    );

    entries.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        startTime: '11:30',
        endTime: '12:30',
        title: '首里城',
        description: '世界遺產',
        version: 3,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '我的備註修改'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    verify(
      () => repository.updateEntry(
        tripId: 'trip-1',
        entryId: 11,
        expectedVersion: 3,
        description: '我的備註修改',
        startTime: '11:30',
        endTime: '12:30',
      ),
    ).called(1);
  });

  testWidgets('送出中停用備註輸入，避免請求完成時丟失新草稿', (tester) async {
    final repository = _MockTripRepository();
    final save = Completer<void>();
    when(
      () => repository.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) => save.future);
    when(
      () => repository.recomputeTravel(tripId: 'trip-1'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('entry-edit-desc')),
    );
    expect(field.enabled, isFalse);

    save.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('儲存後重新開啟會顯示 fresh 備註並使用最新 OCC version', (tester) async {
    final repository = _MockTripRepository();
    final router = _buildRouter();
    var watchEntryCalls = 0;
    var currentEntry = _entry;
    final submittedVersions = <int>[];
    when(() => repository.watchEntry(tripId: 'trip-1', entryId: 11)).thenAnswer(
      (_) {
        watchEntryCalls += 1;
        return Stream.fromIterable([_entry, currentEntry]);
      },
    );
    when(
      () => repository.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((invocation) async {
      final version = invocation.namedArguments[#expectedVersion]! as int;
      final description = invocation.namedArguments[#description] as String?;
      submittedVersions.add(version);
      currentEntry = TimelineEntry(
        id: _entry.id,
        sortOrder: _entry.sortOrder,
        startTime: _entry.startTime,
        endTime: _entry.endTime,
        title: _entry.title,
        description: description,
        version: version + 1,
      );
    });
    when(
      () => repository.recomputeTravel(tripId: 'trip-1'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      _buildApp(repository, overrideEntry: false, router: router),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '儲存後的新備註',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    expect(watchEntryCalls, greaterThanOrEqualTo(2));
    expect(find.text('行程頁'), findsOneWidget);

    router.go('/edit');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '儲存後的新備註'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(submittedVersions, [2, 3]);
  });

  testWidgets('409 後保留輸入並用重新載入的 version 重試', (tester) async {
    final repository = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    var watchEntryCalls = 0;
    final submittedVersions = <int>[];
    when(() => repository.watchEntry(tripId: 'trip-1', entryId: 11)).thenAnswer(
      (_) {
        watchEntryCalls += 1;
        return entries.stream;
      },
    );
    when(
      () => repository.updateEntry(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        expectedVersion: any(named: 'expectedVersion'),
        description: any(named: 'description'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((invocation) async {
      final version = invocation.namedArguments[#expectedVersion]! as int;
      submittedVersions.add(version);
      if (submittedVersions.length == 1) {
        throw const ApiError(
          status: 409,
          code: 'STALE_ENTRY',
          message: 'stale',
        );
      }
    });
    when(
      () => repository.recomputeTravel(tripId: 'trip-1'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(repository, overrideEntry: false));
    entries.add(_entry);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '保留我的多行備註\n第二行',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();

    expect(watchEntryCalls, greaterThanOrEqualTo(2));
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(submittedVersions, [2]);

    entries.addError(Exception('temporary refresh failure'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, '保留我的多行備註\n第二行'),
      findsOneWidget,
      reason: 'refresh error 不得卸載表單並丟棄草稿',
    );
    expect(
      find.byKey(const ValueKey('entry-edit-refresh-error')),
      findsOneWidget,
    );

    entries.add(_updatedEntry);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '保留我的多行備註\n第二行'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('保留你的版本？'), findsOneWidget);
    expect(submittedVersions, [2]);
    await tester.tap(find.text('保留我的版本'));
    await tester.pumpAndSettle();

    expect(submittedVersions, [2, 3]);
    expect(find.text('行程頁'), findsOneWidget);
  });

  testWidgets('已載入的停留點收到 404 refresh 後停用儲存', (tester) async {
    final repository = _MockTripRepository();
    final entries = StreamController<TimelineEntry>.broadcast();
    addTearDown(entries.close);
    when(
      () => repository.watchEntry(tripId: 'trip-1', entryId: 11),
    ).thenAnswer((_) => entries.stream);

    await tester.pumpWidget(_buildApp(repository, overrideEntry: false));
    entries.add(_entry);
    await tester.pumpAndSettle();
    entries.addError(
      const ApiError(status: 404, code: 'ENTRY_NOT_FOUND', message: 'missing'),
    );
    await tester.pumpAndSettle();

    expect(find.text('此停留點已被刪除，無法再儲存；你的草稿仍保留。'), findsOneWidget);
    final saveButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byKey(const ValueKey('entry-edit-submit')),
        matching: find.byType(TextButton),
      ),
    );
    expect(saveButton.onPressed, isNull);
  });
}
