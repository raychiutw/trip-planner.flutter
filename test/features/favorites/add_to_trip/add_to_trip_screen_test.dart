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
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

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
  Widget buildApp(AddToTripArgs args) {
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        favoritesRepositoryProvider.overrideWithValue(favRepo),
        poiRepositoryProvider.overrideWithValue(poiRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: AddToTripScreen(args: args),
      ),
    );
  }

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

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('午餐'), findsOneWidget); // conflict entry 標題
  });

  testWidgets('trips 為空 → 送出鈕 disabled（不靜默 return）', (tester) async {
    when(tripRepo.watchMyTrips).thenAnswer((_) => Stream.value(const []));

    await tester.pumpWidget(
      buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('add-to-trip-submit')),
    );
    expect(button.onPressed, isNull);
  });
}
