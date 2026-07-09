import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/poi_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/favorites/explore/explore_controller.dart'
    show poiRepositoryProvider;
import 'package:tripline/features/trips/edit/edit_trip_screen.dart';
import 'package:tripline/models/destination_input.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepo extends Mock implements TripRepository {}

class _MockPoiRepo extends Mock implements PoiRepository {}

const _trip = Trip(
  id: 'okinawa',
  name: 'Okinawa',
  title: '原標題',
  description: '原描述',
  lang: 'zh-TW',
  published: true,
  dayCount: 5,
  startDate: '2026-04-23',
  endDate: '2026-04-27',
  destinations: [TripDestination(name: '那霸', lat: 26.2, lng: 127.6)],
);

void main() {
  setUpAll(() => registerFallbackValue(<DestinationInput>[]));

  late _MockTripRepo tripRepo;
  late _MockPoiRepo poiRepo;

  setUp(() {
    tripRepo = _MockTripRepo();
    poiRepo = _MockPoiRepo();
    when(() => tripRepo.fetchTrip(any())).thenAnswer((_) async => _trip);
    when(
      () => tripRepo.updateTrip(
        any(),
        name: any(named: 'name'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        dataSource: any(named: 'dataSource'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer((_) async {});
  });

  Widget buildApp() {
    final router = GoRouter(
      initialLocation: '/edit-trip/okinawa',
      routes: [
        GoRoute(
          path: '/edit-trip/:tripId',
          builder: (_, s) =>
              EditTripScreen(tripId: s.pathParameters['tripId']!),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepo),
        poiRepositoryProvider.overrideWithValue(poiRepo),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
  }

  testWidgets('帶入初值（標題/發布）', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    expect(find.text('原標題'), findsOneWidget);
    expect(find.text('那霸'), findsWidgets);
  });

  testWidgets('改標題 + 儲存 → updateTrip(title)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('edit-title')), '新標題');
    await tester.tap(find.byKey(const ValueKey('edit-save')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.updateTrip(
        'okinawa',
        title: '新標題',
        description: any(named: 'description'),
        lang: any(named: 'lang'),
        published: any(named: 'published'),
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
  });

  testWidgets('移除目的地 + 儲存 → updateTrip(destinations)', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close).first); // 移除「那霸」
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-save')));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.updateTrip(
        'okinawa',
        title: any(named: 'title'),
        description: any(named: 'description'),
        lang: any(named: 'lang'),
        published: any(named: 'published'),
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
  });

  testWidgets('平移出發日期 → shiftDays 並更新日期摘要', (tester) async {
    when(
      () => tripRepo.shiftDays(
        tripId: any(named: 'tripId'),
        startDate: any(named: 'startDate'),
      ),
    ).thenAnswer(
      (_) async => (
        newStartDate: '2026-05-01',
        newEndDate: '2026-05-05',
        daysShifted: 8,
      ),
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('2026-04-23 → 2026-04-27'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-shift-days')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-shift-start-date')),
      '2026-05-01',
    );
    await tester.tap(find.widgetWithText(FilledButton, '套用'));
    await tester.pumpAndSettle();

    verify(
      () => tripRepo.shiftDays(tripId: 'okinawa', startDate: '2026-05-01'),
    ).called(1);
    expect(find.text('2026-05-01 → 2026-05-05'), findsOneWidget);
    expect(find.text('出發日期已變更'), findsOneWidget);
  });
}
