import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/trip_detail/entry_poi_screen.dart';
import 'package:tripline/features/trip_detail/trip_providers.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/theme/tokens.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _MockPoiRepository extends Mock implements PoiRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

const _entry = TimelineEntry(
  id: 11,
  sortOrder: 0,
  title: '首里城',
  version: 2,
  entryPoisVersion: '4',
  master: EntryPoiInfo(
    poiId: 501,
    name: '首里城公園',
    type: 'attraction',
    rating: 4.4,
    note: '世界遺產',
  ),
  alternates: [
    EntryPoiInfo(
      poiId: 502,
      name: '玉陵',
      type: 'restaurant',
      lat: 35.6812,
      lng: 139.7671,
      sortOrder: 2,
      reservation: '已訂位 18:00',
      reservationUrl: 'https://book.example/abc',
    ),
    EntryPoiInfo(poiId: 503, name: '識名園', type: 'attraction', sortOrder: 3),
  ],
);

const _sameDayWithOkinawaSibling = [
  TripDay(
    id: 1,
    dayNum: 1,
    version: 1,
    timeline: [
      TimelineEntry(
        id: 11,
        sortOrder: 0,
        title: '首里城',
        version: 2,
        master: EntryPoiInfo(poiId: 501, name: '首里城公園'),
      ),
      TimelineEntry(
        id: 12,
        sortOrder: 1,
        title: '國際通',
        version: 1,
        master: EntryPoiInfo(
          poiId: 601,
          name: '國際通',
          lat: 26.2148,
          lng: 127.6792,
        ),
      ),
    ],
  ),
];

const _favorite = PoiFavorite(
  id: 7,
  userId: 'u1',
  poiId: 701,
  favoritedAt: '2026-07-09T00:00:00Z',
  poiName: '波上宮',
  poiAddress: '那霸市若狹',
  poiType: 'attraction',
);

Future<void> _pump(
  WidgetTester tester,
  _MockTripRepository repo, {
  _MockPoiRepository? poiRepo,
  _MockFavoritesRepository? favoritesRepo,
  List<TripDay> tripDays = const <TripDay>[],
  ReservationUrlLauncher reservationUrlLauncher = launchReservationUrl,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        entryDetailProvider((
          tripId: 't1',
          entryId: 11,
        )).overrideWith((ref) => Stream.value(_entry)),
        tripDaysProvider('t1').overrideWith((ref) => Stream.value(tripDays)),
        if (poiRepo != null) poiRepositoryProvider.overrideWithValue(poiRepo),
        if (favoritesRepo != null)
          favoritesRepositoryProvider.overrideWithValue(favoritesRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: EntryPoiScreen(
          tripId: 't1',
          entryId: 11,
          reservationUrlLauncher: reservationUrlLauncher,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openAlternateDelete(WidgetTester tester, int poiId) async {
  final dismissKey = ValueKey('alt-swipe-$poiId');
  await tester.drag(find.byKey(dismissKey), const Offset(-240, 0));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey<Object>(('swipe-delete-action', dismissKey))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(
    () => registerFallbackValue(const PoiSearchResult(placeId: 'x', name: 'x')),
  );

  testWidgets('顯示正選 + 備選 + 加入備選鈕', (tester) async {
    await _pump(tester, _MockTripRepository());
    expect(find.text('首里城公園'), findsOneWidget);
    expect(find.text('玉陵'), findsOneWidget);
    expect(find.text('識名園'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-alternate')), findsOneWidget);
  });

  testWidgets('訂位資訊有連結時可外開 reservationUrl', (tester) async {
    final opened = <Uri>[];
    await _pump(
      tester,
      _MockTripRepository(),
      reservationUrlLauncher: (url) async => opened.add(url),
    );

    expect(find.text('訂位:已訂位 18:00'), findsOneWidget);

    final link = find.byKey(const ValueKey('poi-reservation-link-502'));
    expect(link, findsOneWidget);
    expect(
      tester.getSize(link).shortestSide,
      greaterThanOrEqualTo(TpSpacing.tapMin),
    );

    await tester.tap(link);
    await tester.pump();

    expect(opened.single.toString(), 'https://book.example/abc');
  });

  testWidgets('設為正選 → 確認後 setEntryMaster(poiId, entryPoisVersion)', (
    tester,
  ) async {
    final repo = _MockTripRepository();
    when(
      () => repo.setEntryMaster(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => repo.recomputeTravel(tripId: any(named: 'tripId')),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('alt-setmaster-502')));
    await tester.pumpAndSettle();

    expect(find.text('設為正選？'), findsOneWidget);
    expect(find.text('要將「玉陵」設為此停留點的正選嗎？'), findsOneWidget);
    verifyNever(
      () => repo.setEntryMaster(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    );

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '設為正選'));
    await tester.pumpAndSettle();

    verify(
      () => repo.setEntryMaster(
        tripId: 't1',
        entryId: 11,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).called(1);
    verify(() => repo.recomputeTravel(tripId: 't1')).called(1);
  });

  testWidgets('設為正選跨區域時顯示距離警示', (tester) async {
    await _pump(
      tester,
      _MockTripRepository(),
      tripDays: _sameDayWithOkinawaSibling,
    );

    await tester.tap(find.byKey(const ValueKey('alt-setmaster-502')));
    await tester.pumpAndSettle();

    expect(find.textContaining('新正選距離本日其他點約'), findsOneWidget);
    expect(find.textContaining('可能跨區，前後車程會誤算'), findsOneWidget);
  });

  testWidgets('左滑備選只揭露刪除，確認後才 removeEntryAlternate', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.removeEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await _openAlternateDelete(tester, 502);
    expect(find.text('移除備選景點？'), findsOneWidget);
    verifyNever(
      () => repo.removeEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    );

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();

    verify(
      () => repo.removeEntryAlternate(
        tripId: 't1',
        entryId: 11,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('備選刪除確認取消不呼叫 repository', (tester) async {
    final repo = _MockTripRepository();
    await _pump(tester, repo);

    await _openAlternateDelete(tester, 502);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repo.removeEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    );
  });

  testWidgets('備選刪除 pending 顯示進度、鎖定返回且不重複送出', (tester) async {
    final repo = _MockTripRepository();
    final pending = Completer<void>();
    when(
      () => repo.removeEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) => pending.future);
    await _pump(tester, repo);

    await _openAlternateDelete(tester, 502);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pump();

    expect(find.byKey(const ValueKey('delete-progress')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(
      () => repo.removeEntryAlternate(
        tripId: 't1',
        entryId: 11,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).called(1);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('delete-progress')), findsOneWidget);
    verifyNoMoreInteractions(repo);

    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('備選刪除失敗保留資料與持續錯誤，重試不需重新確認', (tester) async {
    final repo = _MockTripRepository();
    var attempts = 0;
    when(
      () => repo.removeEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('offline');
    });
    await _pump(tester, repo);

    await _openAlternateDelete(tester, 502);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pumpAndSettle();

    expect(find.text('玉陵'), findsOneWidget);
    expect(find.text('刪除失敗，原資料已保留'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    verify(
      () => repo.removeEntryAlternate(
        tripId: 't1',
        entryId: 11,
        poiId: 502,
        entryPoisVersion: '4',
      ),
    ).called(2);
    expect(find.text('刪除失敗，原資料已保留'), findsNothing);
  });

  testWidgets('操作未回來就離開地點管理 → 不得因 use-after-dispose 崩潰', (tester) async {
    // _run 的 `if (!context.mounted) return` 原本排在兩個 ref.invalidate 之後,
    // 只護住了 showAppNotice。await 期間使用者離開 → ref.invalidate 擲 StateError
    // (非 Exception,`on Exception` 攔不到)→ 未捕捉例外 → 崩潰。
    final repo = _MockTripRepository();
    final pending = Completer<void>();
    when(
      () => repo.removeEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) => pending.future);
    await _pump(tester, repo);

    await _openAlternateDelete(tester, 502);
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '刪除'));
    await tester.pump();

    // 回應抵達前離開頁面。
    await tester.pumpWidget(const SizedBox.shrink());

    pending.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('下移備選 → reorderEntryAlternates', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.reorderEntryAlternates(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        order: any(named: 'order'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('alt-move-down-502')));
    await tester.pumpAndSettle();

    verify(
      () => repo.reorderEntryAlternates(
        tripId: 't1',
        entryId: 11,
        order: [503, 502],
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('編輯資訊 → 改備註 → 儲存呼叫 updateEntryPoi', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.updateEntryPoi(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        reservation: any(named: 'reservation'),
      ),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('poi-edit-master')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('poi-note')), '記得拍照');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('poi-save')));
    await tester.pumpAndSettle();

    verify(
      () => repo.updateEntryPoi(
        tripId: 't1',
        entryId: 11,
        poiId: 501,
        note: '記得拍照',
        poiType: 'attraction',
        reservation: any(named: 'reservation'),
      ),
    ).called(1);
  });

  testWidgets('編輯資訊使用 form sheet，pending 鎖定且失敗保留全部輸入', (tester) async {
    final repo = _MockTripRepository();
    final firstAttempt = Completer<void>();
    var attempts = 0;
    when(
      () => repo.updateEntryPoi(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        reservation: any(named: 'reservation'),
      ),
    ).thenAnswer((_) {
      attempts++;
      return attempts == 1 ? firstAttempt.future : Future.value();
    });
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('poi-edit-master')));
    await tester.pumpAndSettle();
    expect(find.text('編輯地點資訊'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('poi-note')), '記得拍照');
    await tester.enterText(
      find.byKey(const ValueKey('poi-reservation')),
      'https://example.com/book',
    );
    await tester.tap(find.byKey(const ValueKey('poi-save')));
    await tester.pump();

    expect(find.byKey(const ValueKey('poi-info-progress')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const ValueKey('poi-note'))).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('poi-reservation')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('poi-cancel')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );

    firstAttempt.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    expect(find.text('編輯地點資訊'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('poi-note')))
          .controller!
          .text,
      '記得拍照',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('poi-reservation')))
          .controller!
          .text,
      'https://example.com/book',
    );
    expect(find.byKey(const ValueKey('poi-info-error')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('poi-save')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('編輯地點資訊'), findsNothing);
  });

  testWidgets('編輯資訊改後還原時 Save disabled，取消可直接關閉', (tester) async {
    final repo = _MockTripRepository();
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('poi-edit-master')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('poi-note')), '暫存內容');
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('poi-note')), '世界遺產');
    await tester.pump();

    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('poi-save')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('poi-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('編輯地點資訊'), findsNothing);
    expect(find.text('捨棄未儲存的變更？'), findsNothing);
  });

  testWidgets('加入備選 → 搜尋選結果 → addEntryAlternate', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    when(
      () => repo.addEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poi: any(named: 'poi'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const [PoiSearchResult(placeId: 'p9', name: '通堂拉麵')],
    );
    await _pump(tester, repo, poiRepo: poiRepo);

    await tester.tap(find.byKey(const ValueKey('add-alternate')));
    await tester.pumpAndSettle();
    expect(find.text('選擇地點'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('alt-search-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isFalse);
    await tester.enterText(
      find.byKey(const ValueKey('alt-search-field')),
      '拉麵',
    );
    expect(find.byKey(const ValueKey('alt-search-button')), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('alt-result-p9')), findsOneWidget);
    expect(
      tester
          .widgetList<ListView>(find.byType(ListView))
          .any(
            (list) =>
                list.keyboardDismissBehavior ==
                ScrollViewKeyboardDismissBehavior.onDrag,
          ),
      isTrue,
    );
    await tester.enterText(find.byKey(const ValueKey('alt-search-field')), '');
    await tester.pump();
    expect(find.byKey(const ValueKey('alt-result-p9')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('alt-search-field')),
      '拉麵',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alt-result-p9')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryAlternate(
        tripId: 't1',
        entryId: 11,
        poi: any(named: 'poi'),
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('加入備選 pending 鎖定重複提交，失敗保留搜尋與選取供重試', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    final firstAttempt = Completer<void>();
    var attempts = 0;
    when(
      () => repo.addEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poi: any(named: 'poi'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) {
      attempts++;
      return attempts == 1 ? firstAttempt.future : Future.value();
    });
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const [PoiSearchResult(placeId: 'p9', name: '通堂拉麵')],
    );
    await _pump(tester, repo, poiRepo: poiRepo);

    await tester.tap(find.byKey(const ValueKey('add-alternate')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('alt-search-field')),
      '拉麵',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alt-result-p9')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('poi-picker-submit-progress')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('alt-result-p9')))
          .onTap,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(const ValueKey('app-selection-cancel')),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey('poi-picker-submit-progress')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .liveRegion,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('選擇地點'), findsOneWidget);
    expect(attempts, 1);

    firstAttempt.completeError(Exception('offline'));
    await tester.pumpAndSettle();

    expect(find.text('選擇地點'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('alt-search-field')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '拉麵',
    );
    expect(find.byKey(const ValueKey('alt-result-p9')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('poi-picker-submit-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('alt-result-p9')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('選擇地點'), findsNothing);
  });

  testWidgets('加入備選 → 收藏選結果 → addEntryAlternate(poiId)', (tester) async {
    final repo = _MockTripRepository();
    final favoritesRepo = _MockFavoritesRepository();
    when(
      () => repo.addEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    when(
      favoritesRepo.fetchFavorites,
    ).thenAnswer((_) async => const [_favorite]);
    await _pump(tester, repo, favoritesRepo: favoritesRepo);

    await tester.tap(find.byKey(const ValueKey('add-alternate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-picker-tab-favorites')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-picker-favorite-7')));
    await tester.pumpAndSettle();

    verify(
      () => repo.addEntryAlternate(
        tripId: 't1',
        entryId: 11,
        poiId: 701,
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('加入備選 → 自訂地點 → addEntryAlternate(customPoi)', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.addEntryAlternate(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        customPoi: any(named: 'customPoi'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async {});
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('add-alternate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-picker-tab-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('poi-picker-custom-name')),
      '秘密觀景台',
    );
    await tester.enterText(
      find.byKey(const ValueKey('poi-picker-custom-lat')),
      '26.2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('poi-picker-custom-lng')),
      '127.6',
    );
    await tester.tap(find.byKey(const ValueKey('poi-picker-custom-submit')));
    await tester.pumpAndSettle();

    final customPoi =
        verify(
              () => repo.addEntryAlternate(
                tripId: 't1',
                entryId: 11,
                customPoi: captureAny(named: 'customPoi'),
                entryPoisVersion: '4',
              ),
            ).captured.single
            as CustomEntryPoi;
    expect(customPoi.name, '秘密觀景台');
    expect(customPoi.lat, 26.2);
    expect(customPoi.lng, 127.6);
  });

  testWidgets('自訂地點已修改時取消會先確認捨棄', (tester) async {
    final repo = _MockTripRepository();
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('add-alternate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-picker-tab-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('poi-picker-custom-name')),
      '尚未儲存的地點',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('app-selection-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
    expect(find.text('離開後，本次修改不會保留。'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('取消'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('選擇地點'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-selection-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('捨棄'));
    await tester.pumpAndSettle();
    expect(find.text('選擇地點'), findsNothing);
  });

  testWidgets('置換正選 → 搜尋選結果 → changeEntryPoi', (tester) async {
    final repo = _MockTripRepository();
    final poiRepo = _MockPoiRepository();
    when(
      () => repo.changeEntryPoi(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poi: any(named: 'poi'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async => 701);
    when(
      () => poiRepo.searchPois(
        q: any(named: 'q'),
        limit: any(named: 'limit'),
        region: any(named: 'region'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer(
      (_) async => const [PoiSearchResult(placeId: 'p8', name: '波上宮')],
    );
    await _pump(tester, repo, poiRepo: poiRepo);

    await tester.tap(find.byKey(const ValueKey('change-master')));
    await tester.pumpAndSettle();
    expect(find.text('選擇地點'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('alt-search-field')),
      '波上',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('alt-result-p8')));
    await tester.pumpAndSettle();

    verify(
      () => repo.changeEntryPoi(
        tripId: 't1',
        entryId: 11,
        poi: any(named: 'poi'),
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('置換正選 → 收藏選結果 → changeEntryPoi(poiId)', (tester) async {
    final repo = _MockTripRepository();
    final favoritesRepo = _MockFavoritesRepository();
    when(
      () => repo.changeEntryPoi(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        poiId: any(named: 'poiId'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async => 701);
    when(
      favoritesRepo.fetchFavorites,
    ).thenAnswer((_) async => const [_favorite]);
    await _pump(tester, repo, favoritesRepo: favoritesRepo);

    await tester.tap(find.byKey(const ValueKey('change-master')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-picker-tab-favorites')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-picker-favorite-7')));
    await tester.pumpAndSettle();

    verify(
      () => repo.changeEntryPoi(
        tripId: 't1',
        entryId: 11,
        poiId: 701,
        entryPoisVersion: '4',
      ),
    ).called(1);
  });

  testWidgets('置換正選 → 自訂地點 → changeEntryPoi(customPoi)', (tester) async {
    final repo = _MockTripRepository();
    when(
      () => repo.changeEntryPoi(
        tripId: any(named: 'tripId'),
        entryId: any(named: 'entryId'),
        customPoi: any(named: 'customPoi'),
        entryPoisVersion: any(named: 'entryPoisVersion'),
      ),
    ).thenAnswer((_) async => 801);
    await _pump(tester, repo);

    await tester.tap(find.byKey(const ValueKey('change-master')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('poi-picker-tab-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('poi-picker-custom-name')),
      '海邊拍照點',
    );
    await tester.enterText(
      find.byKey(const ValueKey('poi-picker-custom-lat')),
      '26.21',
    );
    await tester.enterText(
      find.byKey(const ValueKey('poi-picker-custom-lng')),
      '127.68',
    );
    await tester.tap(find.byKey(const ValueKey('poi-picker-custom-submit')));
    await tester.pumpAndSettle();

    final customPoi =
        verify(
              () => repo.changeEntryPoi(
                tripId: 't1',
                entryId: 11,
                customPoi: captureAny(named: 'customPoi'),
                entryPoisVersion: '4',
              ),
            ).captured.single
            as CustomEntryPoi;
    expect(customPoi.name, '海邊拍照點');
    expect(customPoi.lat, 26.21);
    expect(customPoi.lng, 127.68);
    expect(customPoi.poiType, 'attraction');
  });
}
