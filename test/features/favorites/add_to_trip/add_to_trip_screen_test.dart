import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/add_to_trip/add_to_trip_screen.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/models/add_to_trip.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/poi_search_result.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

const _trips = [TripSummary(tripId: 'okinawa', name: 'okinawa', title: '沖繩')];
const _days = [TripDay(id: 1, dayNum: 1, title: '第一天', version: 0)];

void main() {
  late _MockFavoritesRepository favRepo;
  late _MockTripRepository tripRepo;

  setUp(() {
    favRepo = _MockFavoritesRepository();
    tripRepo = _MockTripRepository();
    when(tripRepo.fetchMyTrips).thenAnswer((_) async => _trips);
    when(() => tripRepo.fetchDays('okinawa')).thenAnswer((_) async => _days);
  });

  // 統一 override tripRepositoryProvider（myTripsProvider/tripDaysProvider 皆走它,
  // 避免 family instance override 語法不確定）。
  Widget buildApp(AddToTripArgs args) {
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        favoritesRepositoryProvider.overrideWithValue(favRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: AddToTripScreen(args: args),
      ),
    );
  }

  testWidgets('favorite mode：選 trip/day(預設)→ 送出呼叫 addFavoriteToTrip',
      (tester) async {
    when(() => favRepo.addFavoriteToTrip(
          favoriteId: any(named: 'favoriteId'),
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenAnswer((_) async => const AddToTripResult(
        ok: true, entryId: 11, dayId: 1, sortOrder: 0,
        startTime: '10:00', endTime: '11:00'));

    await tester.pumpWidget(
        buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    verify(() => favRepo.addFavoriteToTrip(
        favoriteId: 7,
        tripId: 'okinawa',
        dayNum: 1,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'))).called(1);
  });

  testWidgets('direct mode：送出呼叫 addEntryToDay(poiType 經映射)', (tester) async {
    when(() => tripRepo.addEntryToDay(
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          title: any(named: 'title'),
          poiType: any(named: 'poiType'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenAnswer((_) async {});

    await tester.pumpWidget(buildApp(const AddToTripDirect(
        poi: PoiSearchResult(
            placeId: 'p1', name: '美麗海水族館',
            category: 'aquarium', lat: 26.69, lng: 127.87))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    verify(() => tripRepo.addEntryToDay(
        tripId: 'okinawa',
        dayNum: 1,
        title: '美麗海水族館',
        poiType: 'activity', // aquarium → activity（mapGooglePrimaryTypeToPoiType）
        lat: 26.69,
        lng: 127.87,
        startTime: any(named: 'startTime'),
        endTime: any(named: 'endTime'))).called(1);
  });

  testWidgets('favorite mode：409 → 顯示 ConflictDialog', (tester) async {
    when(() => favRepo.addFavoriteToTrip(
          favoriteId: any(named: 'favoriteId'),
          tripId: any(named: 'tripId'),
          dayNum: any(named: 'dayNum'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenThrow(const ApiError(
      status: 409, code: 'CONFLICT', message: 'CONFLICT',
      payload: {
        'conflictWith': {'entryId': 5, 'time': '10:00-11:00', 'title': '午餐', 'dayNum': 1}
      },
    ));

    await tester.pumpWidget(
        buildApp(const AddToTripFavorite(favoriteId: 7, displayName: '首里城')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-trip-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('午餐'), findsOneWidget); // conflict entry 標題
  });
}
