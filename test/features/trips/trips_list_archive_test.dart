import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/trip_card.dart';
import 'package:tripline/features/trips/trips_list_screen.dart';
import 'package:tripline/models/trip.dart';
import 'package:tripline/models/user.dart';
import 'package:tripline/theme/app_theme.dart';

class _MockTripRepository extends Mock implements TripRepository {}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserInfo?> build() async =>
      const UserInfo(id: 'me', email: 'me@example.com');
}

TripSummary _trip(String id, {String? owner, String? archivedAt}) =>
    TripSummary(
      tripId: id,
      name: id,
      title: '行程-$id',
      ownerUserId: owner,
      archivedAt: archivedAt,
    );

const _archivedAt = '2026-11-01 08:00:00';

void main() {
  late _MockTripRepository repository;
  late List<TripSummary> server;

  setUp(() {
    repository = _MockTripRepository();
    server = [
      _trip('mine-active', owner: 'me'),
      _trip('mine-archived', owner: 'me', archivedAt: _archivedAt),
      _trip('shared-active', owner: 'amy'),
      _trip('shared-archived', owner: 'amy', archivedAt: _archivedAt),
    ];
    when(
      () => repository.watchMyTrips(),
    ).thenAnswer((_) => Stream.value(List.of(server)));
  });

  Future<void> pumpList(WidgetTester tester, {Size? size}) async {
    await tester.binding.setSurfaceSize(size ?? const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TripsListScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(repository),
          authStateProvider.overrideWith(_FakeAuthNotifier.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Set<String> shownTripIds(WidgetTester tester) => tester
      .widgetList<TripCard>(find.byType(TripCard))
      .map((card) => card.trip.tripId)
      .toSet();

  Future<void> selectFilter(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String tripId) async {
    await tester.tap(find.byKey(ValueKey('trip-card-more-$tripId')));
    await tester.pumpAndSettle();
  }

  group('篩選算法', () {
    testWidgets('全部／我的／共編只算未歸檔，已歸檔列出所有角色的已歸檔行程', (tester) async {
      await pumpList(tester);

      expect(shownTripIds(tester), {'mine-active', 'shared-active'});

      await selectFilter(tester, '我的');
      expect(shownTripIds(tester), {'mine-active'});

      await selectFilter(tester, '共編');
      expect(shownTripIds(tester), {'shared-active'});

      await selectFilter(tester, '已歸檔');
      expect(shownTripIds(tester), {'mine-archived', 'shared-archived'});
    });

    testWidgets('已歸檔沒有行程：顯示空狀態文案', (tester) async {
      server = [_trip('mine-active', owner: 'me')];
      await pumpList(tester);

      await selectFilter(tester, '已歸檔');

      expect(find.text('目前沒有已歸檔行程。歸檔行程會在這裡顯示。'), findsOneWidget);
      expect(find.byType(TripCard), findsNothing);
    });
  });

  group('選單', () {
    testWidgets('擁有者：未歸檔看到「歸檔行程」，已歸檔看到「取消歸檔」', (tester) async {
      await pumpList(tester);

      await openMenu(tester, 'mine-active');
      expect(find.text('歸檔行程'), findsOneWidget);
      expect(find.text('取消歸檔'), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      await selectFilter(tester, '已歸檔');
      await openMenu(tester, 'mine-archived');
      expect(find.text('取消歸檔'), findsOneWidget);
      expect(find.text('歸檔行程'), findsNothing);
    });

    testWidgets('旅伴：選單沒有歸檔也沒有取消歸檔', (tester) async {
      await pumpList(tester);
      await openMenu(tester, 'shared-active');
      expect(find.text('歸檔行程'), findsNothing);
      expect(find.text('取消歸檔'), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();

      await selectFilter(tester, '已歸檔');
      await openMenu(tester, 'shared-archived');
      expect(find.text('歸檔行程'), findsNothing);
      expect(find.text('取消歸檔'), findsNothing);
    });

    testWidgets('窄版（390 寬）同樣看得到歸檔動作', (tester) async {
      await pumpList(tester, size: const Size(390, 844));

      await openMenu(tester, 'mine-active');
      expect(find.text('歸檔行程'), findsOneWidget);
    });
  });

  group('歸檔流程', () {
    testWidgets('確認對話框：文案照抄、確認鈕非破壞性；確認後 PUT、回饋並即時從清單移除', (tester) async {
      when(() => repository.archiveTrip('mine-active')).thenAnswer((_) async {
        server = [
          for (final t in server)
            t.tripId == 'mine-active'
                ? _trip('mine-active', owner: 'me', archivedAt: _archivedAt)
                : t,
        ];
        return _archivedAt;
      });
      await pumpList(tester);

      await openMenu(tester, 'mine-active');
      await tester.tap(find.text('歸檔行程'));
      await tester.pumpAndSettle();

      expect(find.text('歸檔行程？'), findsOneWidget);
      expect(
        find.text('「行程-mine-active」會移到所有旅伴的「已歸檔」；旅伴仍可開啟詳情。你正在閱讀的詳情會保持開啟。'),
        findsOneWidget,
      );
      final confirm = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, '歸檔'),
      );
      expect(confirm.isDestructiveAction, isFalse);
      verifyNever(() => repository.archiveTrip(any()));

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '歸檔'));
      await tester.pumpAndSettle();

      verify(() => repository.archiveTrip('mine-active')).called(1);
      expect(find.text('已歸檔「行程-mine-active」'), findsOneWidget);
      expect(shownTripIds(tester), {'shared-active'});
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    testWidgets('取消對話框：不呼叫 API', (tester) async {
      await pumpList(tester);

      await openMenu(tester, 'mine-active');
      await tester.tap(find.text('歸檔行程'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.archiveTrip(any()));
      expect(shownTripIds(tester), contains('mine-active'));
    });

    testWidgets('取消歸檔：文案、DELETE、回饋，並移出已歸檔', (tester) async {
      when(() => repository.unarchiveTrip('mine-archived')).thenAnswer((
        _,
      ) async {
        server = [
          for (final t in server)
            t.tripId == 'mine-archived'
                ? _trip('mine-archived', owner: 'me')
                : t,
        ];
        return null;
      });
      await pumpList(tester);
      await selectFilter(tester, '已歸檔');

      await openMenu(tester, 'mine-archived');
      await tester.tap(find.text('取消歸檔'));
      await tester.pumpAndSettle();

      expect(find.text('取消歸檔行程？'), findsOneWidget);
      expect(find.text('「行程-mine-archived」會回到所有旅伴的「全部」清單。'), findsOneWidget);
      final confirm = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, '取消歸檔'),
      );
      expect(confirm.isDestructiveAction, isFalse);

      await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消歸檔'));
      await tester.pumpAndSettle();

      verify(() => repository.unarchiveTrip('mine-archived')).called(1);
      expect(find.text('已取消歸檔「行程-mine-archived」'), findsOneWidget);
      expect(shownTripIds(tester), {'shared-archived'});
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    Future<void> archiveAndExpectError(
      WidgetTester tester,
      String message,
    ) async {
      await pumpList(tester);
      await openMenu(tester, 'mine-active');
      await tester.tap(find.text('歸檔行程'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '歸檔'));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.text('已歸檔「行程-mine-active」'), findsNothing);
      // 失敗時清單不變
      expect(shownTripIds(tester), {'mine-active', 'shared-active'});
    }

    testWidgets('403：只有行程擁有者能變更歸檔狀態。', (tester) async {
      when(() => repository.archiveTrip(any())).thenThrow(
        const ApiError(status: 403, code: 'PERM_DENIED', message: 'forbidden'),
      );
      await archiveAndExpectError(tester, '只有行程擁有者能變更歸檔狀態。');
    });

    testWidgets('其他錯誤：更新歸檔狀態失敗，請再試一次。', (tester) async {
      when(
        () => repository.archiveTrip(any()),
      ).thenThrow(const ApiError(status: 500, code: 'SYS', message: 'boom'));
      await archiveAndExpectError(tester, '更新歸檔狀態失敗，請再試一次。');
    });

    testWidgets('離線（連線錯誤）：同樣顯示一般錯誤，不假裝成功', (tester) async {
      when(() => repository.archiveTrip(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/trips/x/archive'),
          type: DioExceptionType.connectionError,
        ),
      );
      await archiveAndExpectError(tester, '更新歸檔狀態失敗，請再試一次。');
    });
  });
}
