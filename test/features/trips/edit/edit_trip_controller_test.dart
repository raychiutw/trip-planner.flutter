import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/providers.dart';
import 'package:tripline/api/trip_repository.dart';
import 'package:tripline/features/trips/edit/edit_trip_controller.dart';
import 'package:tripline/models/destination_input.dart';
import 'package:tripline/models/trip.dart';

class _MockTripRepo extends Mock implements TripRepository {}

const _trip = Trip(
  id: 'okinawa',
  name: 'Okinawa',
  title: '原標題',
  description: '原描述',
  lang: 'zh-TW',
  published: true,
  destinations: [TripDestination(name: '那霸', lat: 26.2, lng: 127.6)],
);

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() => registerFallbackValue(<DestinationInput>[]));

  late _MockTripRepo repo;
  setUp(() => repo = _MockTripRepo());

  ProviderContainer makeC([Trip trip = _trip]) {
    // 表單種子走一次性 fetchTrip(非 SWR stream)。
    when(() => repo.fetchTrip(any())).thenAnswer((_) async => trip);
    final c = ProviderContainer(
      overrides: [tripRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<EditTripController> loaded(ProviderContainer c) async {
    // 持續 listener 讓 autoDispose controller 撐過 async _load。
    c.listen(editTripControllerProvider('okinawa'), (_, _) {});
    final ctrl = c.read(editTripControllerProvider('okinawa').notifier);
    await _flush();
    return ctrl;
  }

  test('build 帶入初值', () async {
    final c = makeC();
    await loaded(c);
    final s = c.read(editTripControllerProvider('okinawa'));
    expect(s.loading, isFalse);
    expect(s.title, '原標題');
    expect(s.description, '原描述');
    expect(s.published, isTrue);
    expect(s.destinations.single.name, '那霸');
  });

  test('改 title → save 送 diff(只 title)', () async {
    when(
      () => repo.updateTrip(
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

    final c = makeC();
    final ctrl = await loaded(c);
    ctrl.setTitle('新標題');
    await ctrl.save();

    expect(c.read(editTripControllerProvider('okinawa')).saved, isTrue);
    verify(
      () => repo.updateTrip(
        'okinawa',
        title: '新標題',
        description: null, // 未改 → 不送(diff-only)
        lang: null,
        published: null,
        destinations: null,
      ),
    ).called(1);
  });

  test('改回原值 → hasChanges false、save 不打 API', () async {
    final c = makeC();
    final ctrl = await loaded(c);
    ctrl.setTitle('改了');
    ctrl.setTitle('原標題'); // 改回原值
    await ctrl.save();
    expect(c.read(editTripControllerProvider('okinawa')).saved, isTrue);
    verifyNever(
      () => repo.updateTrip(
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
    );
  });

  test('destinations 改 → save 送 destinations', () async {
    when(
      () => repo.updateTrip(
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

    final c = makeC();
    final ctrl = await loaded(c);
    ctrl.addDestination(const DestinationInput(name: '石垣島'));
    await ctrl.save();

    verify(
      () => repo.updateTrip(
        'okinawa',
        title: any(named: 'title'),
        description: any(named: 'description'),
        lang: any(named: 'lang'),
        published: any(named: 'published'),
        destinations: any(named: 'destinations'),
      ),
    ).called(1);
  });

  test('無變更 → save 不打 API,直接 saved', () async {
    final c = makeC();
    final ctrl = await loaded(c);
    await ctrl.save();

    expect(c.read(editTripControllerProvider('okinawa')).saved, isTrue);
    verifyNever(
      () => repo.updateTrip(
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
    );
  });
}
