import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/chat/chat_screen.dart';
import 'package:tripline/models/chat.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/theme/app_theme.dart';

class MockTripRepository extends Mock implements TripRepository {}

void main() {
  late MockTripRepository mockTripRepository;

  const trip = TripSummary(
    tripId: 'okinawa-trip-2026',
    name: 'okinawa-trip-2026',
    title: '沖繩家族旅行',
    totalDays: 3,
  );

  Widget buildApp() {
    return ProviderScope(
      overrides: [tripRepositoryProvider.overrideWithValue(mockTripRepository)],
      child: MaterialApp(theme: AppTheme.light(), home: const ChatScreen()),
    );
  }

  setUp(() {
    mockTripRepository = MockTripRepository();
    when(
      () => mockTripRepository.fetchMyTrips(),
    ).thenAnswer((_) async => const [trip]);
  });

  testWidgets('載入 active trip 的 request history 並渲染 user/assistant bubbles', (
    tester,
  ) async {
    when(
      () => mockTripRepository.fetchTripRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer(
      (_) async => const TripRequestPage(
        items: [
          TripRequest(
            id: 42,
            tripId: 'okinawa-trip-2026',
            message: '幫我安排晚餐',
            reply: '已幫你補上晚餐候選。',
            status: 'completed',
          ),
        ],
        hasMore: false,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('沖繩家族旅行'), findsOneWidget);
    expect(find.text('幫我安排晚餐'), findsOneWidget);
    expect(find.text('已幫你補上晚餐候選。'), findsOneWidget);
  });

  testWidgets('送出訊息後建立 request，pending bubble 由 polling 結果取代', (tester) async {
    when(
      () => mockTripRepository.fetchTripRequests(
        tripId: any(named: 'tripId'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => const TripRequestPage(items: [], hasMore: false));
    when(
      () => mockTripRepository.createTripRequest(
        tripId: any(named: 'tripId'),
        message: any(named: 'message'),
      ),
    ).thenAnswer(
      (_) async => const TripRequest(
        id: 99,
        tripId: 'okinawa-trip-2026',
        message: '第二天改輕鬆一點',
        status: 'open',
      ),
    );
    when(() => mockTripRepository.fetchTripRequest(99)).thenAnswer(
      (_) async => const TripRequest(
        id: 99,
        tripId: 'okinawa-trip-2026',
        message: '第二天改輕鬆一點',
        reply: '已把第二天調整成較輕鬆的節奏。',
        status: 'completed',
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('chat-input')),
      '第二天改輕鬆一點',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();

    verify(
      () => mockTripRepository.createTripRequest(
        tripId: 'okinawa-trip-2026',
        message: '第二天改輕鬆一點',
      ),
    ).called(1);
    expect(find.text('思考中...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('已把第二天調整成較輕鬆的節奏。'), findsOneWidget);
    verify(() => mockTripRepository.fetchTripRequest(99)).called(1);
  });
}
