import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/auth_repository.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/auth/login_screen.dart';
import 'package:tripline/features/trip_detail/trip_notes_screen.dart';
import 'package:tripline/features/trip_detail/trip_timeline_screen.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/main.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/models/notes.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/user.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockTripRepository extends Mock implements TripRepository {}

/// 已登入的假 AuthNotifier(不打 API)。
class _LoggedInAuthNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'u1', email: 'ray@example.com', displayName: 'Ray');
}

const _trip = Trip(id: 'okinawa', name: 'okinawa', title: '沖繩家族之旅');
const _days = [
  TripDay(
    id: 1,
    dayNum: 1,
    title: '抵達那霸',
    version: 0,
    timeline: [
      TimelineEntry(
        id: 11,
        sortOrder: 0,
        version: 0,
        startTime: '10:00',
        title: '那霸機場',
      ),
    ],
  ),
];

void main() {
  testWidgets('A:未登入填表登入 → 進入行程清單', (tester) async {
    final mockAuth = _MockAuthRepository();
    final mockTrips = _MockTripRepository();
    when(() => mockAuth.currentUser()).thenAnswer((_) async => null);
    when(
      () => mockAuth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const UserInfo(id: 'u1', email: 'ray@example.com'),
    );
    when(
      mockTrips.watchMyTrips,
    ).thenAnswer((_) => Stream.value(const <TripSummary>[]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          tripRepositoryProvider.overrideWithValue(mockTrips),
          appNetworkAvailabilityProvider.overrideWithValue(
            const Stream.empty(),
          ),
        ],
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome-login-hero')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-email-field')),
      'ray@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password-field')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit-button')));
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
    verify(
      () => mockAuth.login(email: 'ray@example.com', password: 'secret'),
    ).called(1);
  });

  testWidgets('B:已登入 清單→點卡片→時間軸→點筆記→筆記頁', (tester) async {
    final mockTrips = _MockTripRepository();
    when(mockTrips.watchMyTrips).thenAnswer(
      (_) => Stream.value(const [
        TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 1,
        ),
      ]),
    );
    when(
      () => mockTrips.watchTrip('okinawa'),
    ).thenAnswer((_) => Stream.value(_trip));
    when(
      () => mockTrips.watchDays('okinawa'),
    ).thenAnswer((_) => Stream.value(_days));
    when(
      () => mockTrips.watchNotes('okinawa'),
    ).thenAnswer((_) => Stream.value(const TripNotes()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          tripRepositoryProvider.overrideWithValue(mockTrips),
          appNetworkAvailabilityProvider.overrideWithValue(
            const Stream.empty(),
          ),
        ],
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 清單
    expect(find.byType(TripsListScreen), findsOneWidget);
    expect(find.text('沖繩家族之旅'), findsOneWidget);

    // 點卡片 → 時間軸
    await tester.tap(find.text('沖繩家族之旅'));
    await tester.pumpAndSettle();
    expect(find.byType(TripTimelineScreen), findsOneWidget);
    expect(find.text('那霸機場'), findsOneWidget);

    // 單一行程的固定返回動作會回到行程列表。
    await tester.tap(find.byKey(const ValueKey('trip-timeline-back')));
    await tester.pumpAndSettle();
    expect(find.byType(TripsListScreen), findsOneWidget);

    // 再次進入行程，接續驗證功能選單流程。
    await tester.tap(find.text('沖繩家族之旅'));
    await tester.pumpAndSettle();
    expect(find.byType(TripTimelineScreen), findsOneWidget);

    // 從右上功能選單選筆記 → 筆記頁
    await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trip-action-notes')));
    await tester.pumpAndSettle();
    expect(find.byType(TripNotesScreen), findsOneWidget);
    expect(find.text('行程筆記'), findsOneWidget);
  });

  testWidgets('時間軸編輯撞 409 後保留草稿，確認新版才儲存並返回原行程', (tester) async {
    final mockTrips = _MockTripRepository();
    final entryChanges = StreamController<TimelineEntry>.broadcast();
    addTearDown(entryChanges.close);
    final submittedVersions = <int>[];
    when(mockTrips.watchMyTrips).thenAnswer(
      (_) => Stream.value(const [
        TripSummary(
          tripId: 'okinawa',
          name: 'okinawa',
          title: '沖繩家族之旅',
          totalDays: 1,
        ),
      ]),
    );
    when(
      () => mockTrips.watchTrip('okinawa'),
    ).thenAnswer((_) => Stream.value(_trip));
    when(
      () => mockTrips.watchDays('okinawa'),
    ).thenAnswer((_) => Stream.value(_days));
    when(
      () => mockTrips.watchEntry(tripId: 'okinawa', entryId: 11),
    ).thenAnswer((_) => entryChanges.stream);
    when(
      () => mockTrips.updateEntry(
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
      if (version == 0) {
        throw const ApiError(
          status: 409,
          code: 'STALE_ENTRY',
          message: 'stale',
        );
      }
    });
    when(
      () => mockTrips.recomputeTravel(tripId: 'okinawa'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(_LoggedInAuthNotifier.new),
          tripRepositoryProvider.overrideWithValue(mockTrips),
          appNetworkAvailabilityProvider.overrideWithValue(
            const Stream.empty(),
          ),
        ],
        child: const TriplineApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('沖繩家族之旅'));
    await tester.pumpAndSettle();
    expect(find.byType(TripTimelineScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-more-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('entry-edit-11')));
    await tester.pumpAndSettle();
    entryChanges.add(_days.single.timeline.single);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('entry-edit-desc')),
      '我的沖繩草稿',
    );
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(submittedVersions, [0]);

    entryChanges.add(
      const TimelineEntry(
        id: 11,
        sortOrder: 0,
        version: 1,
        startTime: '10:00',
        title: '那霸機場',
        description: '協作者的新備註',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '我的沖繩草稿'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    expect(find.text('保留你的版本？'), findsOneWidget);
    await tester.tap(find.text('繼續編輯'));
    await tester.pumpAndSettle();
    expect(submittedVersions, [0]);
    expect(find.widgetWithText(TextField, '我的沖繩草稿'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('entry-edit-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留我的版本'));
    await tester.pumpAndSettle();
    expect(submittedVersions, [0, 1]);
    verify(
      () => mockTrips.updateEntry(
        tripId: 'okinawa',
        entryId: 11,
        expectedVersion: 1,
        description: '我的沖繩草稿',
        startTime: '10:00',
        endTime: null,
      ),
    ).called(1);
    expect(find.byKey(const ValueKey('entry-edit-desc')), findsNothing);
    expect(find.byType(TripTimelineScreen), findsOneWidget);
    expect(find.text('那霸機場'), findsOneWidget);
  });
}
