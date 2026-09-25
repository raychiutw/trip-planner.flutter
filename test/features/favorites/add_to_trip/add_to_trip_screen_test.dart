import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/add_to_trip/add_to_trip_screen.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/models/add_to_trip.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/place_details.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';
import 'package:tripline/ui/tp_app_bar.dart';

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

class _MockPoiRepository extends Mock implements PoiRepository {}

const _trips = [TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩')];
const _days = [TripDay(id: 1, dayNum: 1, title: '第一天', version: 0)];

void main() {
  late _MockFavoritesRepository favRepo;
  late _MockTripRepository tripRepo;
  late _MockPoiRepository poiRepo;

  setUp(() {
    favRepo = _MockFavoritesRepository();
    tripRepo = _MockTripRepository();
    poiRepo = _MockPoiRepository();
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(_trips));
    when(
      () => tripRepo.watchDays('okinawa'),
    ).thenAnswer((_) => Stream.value(_days));
  });

  group('isAddToTripTimeValid', () {
    test('end > start → true', () {
      expect(
        isAddToTripTimeValid(
          const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 11, minute: 0),
        ),
        isTrue,
      );
    });
    test('end == start → false', () {
      expect(
        isAddToTripTimeValid(
          const TimeOfDay(hour: 10, minute: 0),
          const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
    });
    test('end < start → false', () {
      expect(
        isAddToTripTimeValid(
          const TimeOfDay(hour: 12, minute: 0),
          const TimeOfDay(hour: 11, minute: 30),
        ),
        isFalse,
      );
    });
  });

  // 統一 override tripRepositoryProvider（myTripsProvider/tripDaysProvider 皆走它,
  // 避免 family instance override 語法不確定）。
  Widget buildScoped(Widget home, {double textScale = 1}) {
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        favoritesRepositoryProvider.overrideWithValue(favRepo),
        poiRepositoryProvider.overrideWithValue(poiRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    );
  }

  Widget buildApp(AddToTripArgs args) =>
      buildScoped(AddToTripScreen(args: args));

  testWidgets('預設重試期間行程讀取失敗仍可原地重試並選擇日期', (tester) async {
    final recoveredTrips = StreamController<List<TripSummary>>.broadcast();
    addTearDown(recoveredTrips.close);
    var tripReads = 0;
    when(tripRepo.watchMyTrips).thenAnswer((_) {
      tripReads++;
      return tripReads == 1
          ? Stream.error(Exception('network unavailable'))
          : recoveredTrips.stream;
    });
    when(
      () => favRepo.addFavoriteToTrip(
        favoriteId: any(named: 'favoriteId'),
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tripRepo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    // 使用正式 ProviderScope 預設 retry；在第一個 200ms 自動重試前操作。
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(tripReads, 1);
    expect(find.text('無法載入行程清單'), findsOneWidget);
    expect(find.textContaining('network unavailable'), findsNothing);
    await tester.tap(find.text('重試'));
    await tester.pump();
    recoveredTrips.add(_trips);
    await tester.pumpAndSettle();

    expect(find.text('沖繩'), findsWidgets);
    expect(find.text('DAY 1 · Day 1'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();
    verify(
      () => favRepo.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'okinawa',
        dayNum: 1,
        startTime: '10:00',
        endTime: '11:00',
      ),
    ).called(1);
    expect(tripReads, 2);
  });

  testWidgets('日期讀取失敗只重試所選行程並保留上游選擇', (tester) async {
    const trips = [
      ..._trips,
      TripSummary(tripId: 'tokyo', name: 'tokyo', title: '東京'),
    ];
    const tokyoDays = [TripDay(id: 2, dayNum: 2, version: 0)];
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(trips));
    var dayReads = 0;
    final recoveredDays = StreamController<List<TripDay>>.broadcast();
    addTearDown(recoveredDays.close);
    when(() => tripRepo.watchDays('tokyo')).thenAnswer((_) {
      dayReads++;
      return dayReads == 1
          ? Stream.error(Exception('days unavailable'))
          : recoveredDays.stream;
    });
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('東京').last);
    // 不推進自動重試計時器，觀察第一個失敗。
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.text('無法載入日期'), findsOneWidget);
    expect(find.textContaining('days unavailable'), findsNothing);
    expect(dayReads, 1);
    await tester.tap(find.text('重試'));
    await tester.pump();
    recoveredDays.add(tokyoDays);
    await tester.pumpAndSettle();
    expect(find.text('東京'), findsWidgets);
    expect(find.text('DAY 2 · Day 2'), findsWidgets);
    verify(tripRepo.watchMyTrips).called(1);
    verify(() => tripRepo.watchDays('okinawa')).called(1);
    expect(dayReads, 2);
  });

  testWidgets('已選行程與日期在兩層更新失敗及恢復後仍保留', (tester) async {
    const trips = [
      ..._trips,
      TripSummary(tripId: 'tokyo', name: 'tokyo', title: '東京'),
    ];
    const days = [
      TripDay(id: 2, dayNum: 1, version: 0),
      TripDay(id: 3, dayNum: 2, version: 0),
    ];
    final tripUpdates = StreamController<List<TripSummary>>.broadcast();
    final dayUpdates = StreamController<List<TripDay>>.broadcast();
    addTearDown(tripUpdates.close);
    addTearDown(dayUpdates.close);
    var tripReads = 0;
    var dayReads = 0;
    when(tripRepo.watchMyTrips).thenAnswer((_) {
      tripReads++;
      return tripReads == 1 ? tripUpdates.stream : Stream.value(trips);
    });
    when(() => tripRepo.watchDays('tokyo')).thenAnswer((_) {
      dayReads++;
      return dayReads == 1 ? dayUpdates.stream : Stream.value(days);
    });
    when(
      () => favRepo.addFavoriteToTrip(
        favoriteId: any(named: 'favoriteId'),
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tripRepo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    tripUpdates.add(trips);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('東京').last);
    // selection sheet 完成關閉後才回傳選擇，日期 stream 此時仍等待資料。
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    dayUpdates.add(days);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 2 · Day 2').last);
    await tester.pumpAndSettle();

    dayUpdates.addError(Exception('days update failed'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('add-to-trip-day')), findsOneWidget);
    expect(find.text('無法載入日期'), findsOneWidget);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(tripReads, 1);

    tripUpdates.addError(Exception('trips update failed'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('add-to-trip-trip')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-to-trip-day')), findsOneWidget);
    expect(find.text('無法載入行程清單'), findsOneWidget);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();
    verify(
      () => favRepo.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'tokyo',
        dayNum: 2,
        startTime: '10:00',
        endTime: '11:00',
      ),
    ).called(1);
    expect(dayReads, 2);
    expect(tripReads, 2);
  });

  for (final size in [const Size(320, 568), const Size(1024, 768)]) {
    testWidgets('$size 最大字級可讀取完整長行程名稱並選擇末項日期', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final trips = [
        for (var i = 1; i <= 8; i++)
          TripSummary(tripId: 'trip-$i', name: '東京親子自由行博物館公園美食探訪第 $i 組'),
      ];
      const days = [
        TripDay(id: 1, dayNum: 1, date: '2026-09-25', version: 0),
        TripDay(id: 2, dayNum: 2, date: '2026-09-26', version: 0),
      ];
      when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(trips));
      when(
        () => tripRepo.watchDays(any()),
      ).thenAnswer((_) => Stream.value(days));
      when(
        () => favRepo.addFavoriteToTrip(
          favoriteId: any(named: 'favoriteId'),
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => tripRepo.recomputeTravel(
          tripId: any(named: 'tripId'),
          day: any(named: 'day'),
        ),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(
        buildScoped(
          const AddToTripScreen(
            args: AddToTripFavorite(favoriteId: 7, displayName: '首里城'),
          ),
          textScale: 3.2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('add-to-trip-trip')));
      await tester.pumpAndSettle();
      final lastTrip = find.text('東京親子自由行博物館公園美食探訪第 8 組');
      await tester.scrollUntilVisible(
        lastTrip,
        200,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 50,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(lastTrip);
      await tester.pumpAndSettle();
      final dayPicker = find.byKey(const ValueKey('add-to-trip-day'));
      await tester.ensureVisible(dayPicker);
      await tester.tap(dayPicker);
      await tester.pumpAndSettle();
      final lastDay = find.text('DAY 2 · 2026-09-26');
      await tester.scrollUntilVisible(
        lastDay,
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(lastDay);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
      await tester.pumpAndSettle();
      verify(
        () => favRepo.addFavoriteToTrip(
          favoriteId: 7,
          tripId: 'trip-8',
          dayNum: 2,
          startTime: '10:00',
          endTime: '11:00',
        ),
      ).called(1);
    });
  }

  testWidgets('未手動操作時兩層讀取仍可依預設政策自動恢復', (tester) async {
    var tripReads = 0;
    var dayReads = 0;
    when(tripRepo.watchMyTrips).thenAnswer((_) {
      tripReads++;
      return tripReads == 1
          ? Stream.error(Exception('trips unavailable'))
          : Stream.value(_trips);
    });
    when(() => tripRepo.watchDays('okinawa')).thenAnswer((_) {
      dayReads++;
      return dayReads == 1
          ? Stream.error(Exception('days unavailable'))
          : Stream.value(_days);
    });
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.text('無法載入行程清單'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 201));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(find.text('無法載入日期'), findsOneWidget);
    expect(find.text('沖繩'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 201));
    await tester.pumpAndSettle();
    expect(find.text('DAY 1 · Day 1'), findsOneWidget);
    expect(find.text('重試'), findsNothing);
    expect(tripReads, 2);
    expect(dayReads, 2);
  });

  testWidgets('日期重試未完成時切換行程不接受舊行程遲到結果', (tester) async {
    const trips = [
      ..._trips,
      TripSummary(tripId: 'tokyo', name: 'tokyo', title: '東京'),
    ];
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(trips));
    final lateDays = StreamController<List<TripDay>>.broadcast();
    addTearDown(lateDays.close);
    var dayReads = 0;
    when(() => tripRepo.watchDays('tokyo')).thenAnswer((_) {
      dayReads++;
      return dayReads == 1
          ? Stream.error(Exception('days unavailable'))
          : lateDays.stream;
    });
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('東京'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('重試'));
    await tester.pump();
    expect(lateDays.hasListener, isTrue);
    await tester.tap(find.byKey(const ValueKey('add-to-trip-trip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('沖繩'));
    await tester.pumpAndSettle();
    lateDays.add(const [TripDay(id: 99, dayNum: 9, version: 0)]);
    await tester.pumpAndSettle();
    expect(find.text('沖繩'), findsOneWidget);
    expect(find.text('DAY 1 · Day 1'), findsOneWidget);
    expect(find.text('DAY 9 · Day 9'), findsNothing);
    expect(find.text('無法載入日期'), findsNothing);
    expect(dayReads, 2);
  });

  testWidgets('重新載入已移除所選日期時顯示並提交仍存在的第一天', (tester) async {
    final updates = StreamController<List<TripDay>>.broadcast();
    addTearDown(updates.close);
    when(() => tripRepo.watchDays('okinawa')).thenAnswer((_) => updates.stream);
    when(
      () => favRepo.addFavoriteToTrip(
        favoriteId: any(named: 'favoriteId'),
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tripRepo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    updates.add(const [..._days, TripDay(id: 2, dayNum: 2, version: 0)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 2 · Day 2'));
    await tester.pumpAndSettle();
    updates.add(_days);
    await tester.pumpAndSettle();
    expect(find.text('DAY 1 · Day 1'), findsOneWidget);
    expect(find.text('尚無日期'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();
    verify(
      () => favRepo.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'okinawa',
        dayNum: 1,
        startTime: '10:00',
        endTime: '11:00',
      ),
    ).called(1);
  });

  testWidgets('重新載入已移除所選行程時使用新行程自己的第一天', (tester) async {
    final updates = StreamController<List<TripSummary>>.broadcast();
    addTearDown(updates.close);
    when(tripRepo.watchMyTrips).thenAnswer((_) => updates.stream);
    const days = [..._days, TripDay(id: 2, dayNum: 2, version: 0)];
    when(() => tripRepo.watchDays(any())).thenAnswer((_) => Stream.value(days));
    when(
      () => favRepo.addFavoriteToTrip(
        favoriteId: any(named: 'favoriteId'),
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tripRepo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    updates.add(const [
      TripSummary(tripId: 'tokyo', name: 'tokyo', title: '東京'),
      ..._trips,
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DAY 2 · Day 2'));
    await tester.pumpAndSettle();
    updates.add(_trips);
    await tester.pumpAndSettle();
    expect(find.text('沖繩'), findsOneWidget);
    expect(find.text('DAY 1 · Day 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();
    verify(
      () => favRepo.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'okinawa',
        dayNum: 1,
        startTime: '10:00',
        endTime: '11:00',
      ),
    ).called(1);
  });

  for (final emptyTrips in [true, false]) {
    testWidgets('${emptyTrips ? '行程' : '日期'}重新載入為空後不能提交原選擇', (tester) async {
      final trips = StreamController<List<TripSummary>>.broadcast();
      final days = StreamController<List<TripDay>>.broadcast();
      addTearDown(trips.close);
      addTearDown(days.close);
      when(tripRepo.watchMyTrips).thenAnswer((_) => trips.stream);
      when(() => tripRepo.watchDays('okinawa')).thenAnswer((_) => days.stream);
      await tester.pumpWidget(
        buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
      );
      trips.add(_trips);
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }
      days.add(const [..._days, TripDay(id: 2, dayNum: 2, version: 0)]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-to-trip-day')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DAY 2 · Day 2'));
      await tester.pumpAndSettle();
      if (emptyTrips) {
        trips.add(const []);
      } else {
        days.add(const []);
      }
      await tester.pumpAndSettle();
      expect(find.text(emptyTrips ? '尚無行程' : '尚無日期'), findsOneWidget);
      final button = tester.widget<TpToolbarTextButton>(
        find.byKey(const ValueKey('add-to-trip-submit')),
      );
      expect(button.onPressed, isNull);
      verifyNever(
        () => favRepo.addFavoriteToTrip(
          favoriteId: any(named: 'favoriteId'),
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      );
    });
  }

  testWidgets('route loader：favorite id 深連結會從收藏清單還原 args', (tester) async {
    when(favRepo.fetchFavorites).thenAnswer(
      (_) async => const [
        PoiFavorite(
          id: 7,
          userId: 'user-1',
          poiId: 700,
          favoritedAt: '2026-07-09T10:00:00Z',
          poiName: '首里城',
        ),
      ],
    );

    await tester.pumpWidget(
      buildScoped(
        AddToTripRouteScreen(
          favoriteMode: true,
          favoriteId: 7,
          uri: Uri.parse('/favorites/7/add-to-trip'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加入行程：首里城'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('加入'), findsOneWidget);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
    verify(favRepo.fetchFavorites).called(1);
  });

  testWidgets('route loader：direct query 會建立 direct mode args', (tester) async {
    final uri = Uri(
      path: '/favorites/add-to-trip',
      queryParameters: const {
        'place_id': 'p1',
        'name': '美麗海水族館',
        'lat': '26.69',
        'lng': '127.87',
        'address': '沖繩縣本部町石川424',
        'category': 'aquarium',
      },
    );

    await tester.pumpWidget(buildScoped(AddToTripRouteScreen(uri: uri)));
    await tester.pumpAndSettle();

    expect(find.text('加入行程：美麗海水族館'), findsOneWidget);
  });

  testWidgets('route loader：direct query 缺資料時顯示明確錯誤', (tester) async {
    await tester.pumpWidget(
      buildScoped(
        AddToTripRouteScreen(uri: Uri.parse('/favorites/add-to-trip')),
      ),
    );
    await tester.pump();

    expect(find.text('景點資料缺漏，請從探索頁重新進入'), findsOneWidget);
  });

  testWidgets('favorite mode：選 trip/day(預設)→ 送出呼叫 addFavoriteToTrip', (
    tester,
  ) async {
    when(
      () => favRepo.addFavoriteToTrip(
        favoriteId: any(named: 'favoriteId'),
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tripRepo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    verify(
      () => favRepo.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'okinawa',
        dayNum: 1,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).called(1);
    verify(
      () => tripRepo.recomputeTravel(tripId: 'okinawa', day: '1'),
    ).called(1);
  });

  testWidgets('direct mode：送出呼叫 addEntryToDay(poiType 經映射)', (tester) async {
    when(() => poiRepo.resolvePlace('p1')).thenAnswer(
      (_) async => const PlaceDetails(
        placeId: 'p1',
        hours:
            '星期一: 09:00-18:00 星期二: 09:00-18:00 星期三: 09:00-18:00 星期四: 09:00-18:00 星期五: 09:00-18:00 星期六: 09:00-18:00 星期日: 09:00-18:00',
        priceLevel: 'PRICE_LEVEL_MODERATE',
      ),
    );
    when(
      () => tripRepo.addEntryToDay(
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        title: any(named: 'title'),
        note: any(named: 'note'),
        poiType: any(named: 'poiType'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: any(named: 'source'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tripRepo.recomputeTravel(
        tripId: any(named: 'tripId'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      buildApp(
        const AddToTripDirect(
          poi: PoiSearchResult(
            placeId: 'p1',
            name: '美麗海水族館',
            category: 'aquarium',
            address: '沖繩縣本部町石川424',
            lat: 26.69,
            lng: 127.87,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.addEntryToDay(
        tripId: 'okinawa',
        dayNum: 1,
        title: '美麗海水族館',
        note: '營業 09:00-18:00\n消費 ￥￥\n沖繩縣本部町石川424',
        poiType:
            'activity', // aquarium → activity（mapGooglePrimaryTypeToPoiType）
        lat: 26.69,
        lng: 127.87,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
        source: 'google',
      ),
    ).called(1);
    verify(
      () => tripRepo.recomputeTravel(tripId: 'okinawa', day: '1'),
    ).called(1);
  });

  testWidgets('favorite mode：409 → 顯示 ConflictDialog', (tester) async {
    when(
      () => favRepo.addFavoriteToTrip(
        favoriteId: any(named: 'favoriteId'),
        tripId: any(named: 'tripId'),
        dayNum: any(named: 'dayNum'),
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'),
      ),
    ).thenThrow(
      const ApiError(
        status: 409,
        code: 'CONFLICT',
        message: 'CONFLICT',
        payload: {
          'conflictWith': {
            'entryId': 5,
            'time': '10:00-11:00',
            'title': '午餐',
            'dayNum': 1,
          },
        },
      ),
    );

    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.textContaining('午餐'), findsOneWidget); // conflict entry 標題
  });

  testWidgets('起訖時間就地展開，兩顆不會同時展開', (tester) async {
    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-to-trip-start')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('add-to-trip-start-group')),
        matching: find.byType(CupertinoDatePicker),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('add-to-trip-end')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('add-to-trip-end-group')),
        matching: find.byType(CupertinoDatePicker),
      ),
      findsOneWidget,
    );
  });

  testWidgets('trips 為空 → 送出鈕 disabled（不靜默 return）', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(const []));

    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<TpToolbarTextButton>(
      find.byKey(const ValueKey('add-to-trip-submit')),
    );
    expect(button.onPressed, isNull);
  });
}
