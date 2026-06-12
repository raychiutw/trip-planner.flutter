import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/api_error.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/create/create_trip_controller.dart';
import 'package:tripline/models/destination_input.dart';

class _MockTripRepo extends Mock implements TripRepository {}

void main() {
  setUpAll(() => registerFallbackValue(<DestinationInput>[]));

  late _MockTripRepo repo;
  setUp(() => repo = _MockTripRepo());

  ProviderContainer makeC() {
    final c = ProviderContainer(
      overrides: [tripRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  CreateTripController ctrl(ProviderContainer c) {
    c.listen(
      createTripControllerProvider,
      (_, _) {},
    ); // keep alive (autoDispose)
    return c.read(createTripControllerProvider.notifier);
  }

  test('加/移除/排序目的地', () {
    final c = makeC();
    final t = ctrl(c);
    t.addDestination(const DestinationInput(name: 'A'));
    t.addDestination(const DestinationInput(name: 'B'));
    expect(
      c
          .read(createTripControllerProvider)
          .destinations
          .map((d) => d.name)
          .toList(),
      ['A', 'B'],
    );
    t.reorderDestination(0, 1); // 移 A 到 1 → [B,A]
    expect(
      c
          .read(createTripControllerProvider)
          .destinations
          .map((d) => d.name)
          .toList(),
      ['B', 'A'],
    );
    t.removeDestination(0);
    expect(
      c
          .read(createTripControllerProvider)
          .destinations
          .map((d) => d.name)
          .toList(),
      ['A'],
    );
  });

  test('彈性模式衍生日期', () {
    final c = makeC();
    final t = ctrl(c);
    t.setDateMode(TripDateMode.flexible);
    t.setFlexMonth(2026, 7);
    t.setFlexDayCount(5);
    final s = c.read(createTripControllerProvider);
    expect(s.startDate, '2026-07-01');
    expect(s.endDate, '2026-07-05');
    expect(s.totalDays, 5);
  });

  test('canSubmit：需 ≥1 目的地 + 有效日期', () {
    final c = makeC();
    final t = ctrl(c);
    t.setDateMode(TripDateMode.flexible);
    t.setFlexMonth(2026, 7);
    expect(c.read(createTripControllerProvider).canSubmit, isFalse); // 無目的地
    t.addDestination(const DestinationInput(name: 'A'));
    expect(c.read(createTripControllerProvider).canSubmit, isTrue);
  });

  test('submit：衍生 name/countries + 呼叫 createTrip → 回 tripId', () async {
    when(
      () => repo.createTrip(
        id: any(named: 'id'),
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        dataSource: any(named: 'dataSource'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenAnswer(
      (_) async => (tripId: 'a-b-x', daysCreated: 5, destinationsCreated: 2),
    );

    final c = makeC();
    final t = ctrl(c);
    t.setDateMode(TripDateMode.flexible);
    t.setFlexMonth(2026, 7);
    t.addDestination(const DestinationInput(name: 'A', country: 'JP'));
    t.addDestination(const DestinationInput(name: 'B', country: 'KR'));

    final id = await t.submit();
    expect(id, 'a-b-x');
    verify(
      () => repo.createTrip(
        id: any(named: 'id'),
        name: 'A、B',
        startDate: '2026-07-01',
        endDate: '2026-07-05',
        description: any(named: 'description'),
        countries: 'JP,KR',
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
  });

  test('submit 409 → error,submitting false', () async {
    when(
      () => repo.createTrip(
        id: any(named: 'id'),
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        countries: any(named: 'countries'),
        published: any(named: 'published'),
        dataSource: any(named: 'dataSource'),
        lang: any(named: 'lang'),
        destinations: any(named: 'destinations'),
      ),
    ).thenThrow(
      const ApiError(status: 409, code: 'DATA_CONFLICT', message: 'exists'),
    );

    final c = makeC();
    final t = ctrl(c);
    t.setDateMode(TripDateMode.flexible);
    t.setFlexMonth(2026, 7);
    t.addDestination(const DestinationInput(name: 'A'));

    final id = await t.submit();
    expect(id, isNull);
    expect(c.read(createTripControllerProvider).error, isNotNull);
    expect(c.read(createTripControllerProvider).submitting, isFalse);
  });

  test('autoDispose：無 listener 後重建 → state 重置（不殘留上次輸入）', () async {
    final c = makeC();
    final sub = c.listen(createTripControllerProvider, (_, _) {});
    c
        .read(createTripControllerProvider.notifier)
        .addDestination(const DestinationInput(name: 'A'));
    expect(c.read(createTripControllerProvider).destinations, hasLength(1));

    sub.close(); // 最後 listener 移除 → autoDispose
    await Future<void>.delayed(Duration.zero);

    final sub2 = c.listen(createTripControllerProvider, (_, _) {});
    expect(c.read(createTripControllerProvider).destinations, isEmpty);
    sub2.close();
  });
}
