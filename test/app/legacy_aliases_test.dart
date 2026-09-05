import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/app/legacy_aliases.dart';
import 'package:tripline/features/trip_detail/entry_add_route_screen.dart';

void main() {
  const trip = {'tripId': 'trip-1'};
  const stop = {'tripId': 'trip-1', 'entryId': '11'};

  test('行程層 alias:/trip/:id 與子頁改寫到 /trips/:id', () {
    expect(tripAlias(trip), '/trips/trip-1');
    expect(tripAlias(trip, suffix: '/notes'), '/trips/trip-1/notes');
    expect(tripAlias({'tripId': 'a b'}), '/trips/a%20b');
    expect(outsideTripAlias(trip, prefix: '/collab'), '/collab/trip-1');
  });

  test('停留點 alias:entry 帶進 query,子頁改到 /entries/:id/*', () {
    expect(
      entryTimelineAlias(stop, Uri.parse('/x?day=2')),
      '/trips/trip-1?day=2&entry=11',
    );
    expect(entryMapAlias(stop, Uri.parse('/x')), '/trips/trip-1/map?entry=11');
    expect(entrySubpageAlias(stop, 'edit'), '/trips/trip-1/entries/11/edit');
    expect(entrySubpageAlias(stop, 'pois'), '/trips/trip-1/entries/11/pois');
  });

  test('新增停留點 alias:tab 換成 mode,其餘 query 保留', () {
    expect(
      newEntryAlias(
        trip,
        Uri.parse('/x?tab=favorites&day=1'),
        mode: 'favorites',
      ),
      '/trips/trip-1/entries/new?day=1&mode=favorites',
    );
    expect(entryAddModeFromQuery('favorites', fallback: 'search'), 'favorites');
    expect(entryAddModeFromQuery('bogus', fallback: 'search'), 'search');
  });

  test('mode 字串集合與 features 層的 EntryAddMode 同步', () {
    expect(entryAddModes, EntryAddMode.values.map((m) => m.name).toSet());
  });

  test('/trips?selected=… 改到行程頁,focus 變 entry;不合法的 selected 不改寫', () {
    expect(
      selectedTripAlias(Uri.parse('/trips?selected=trip-1')),
      '/trips/trip-1',
    );
    expect(
      selectedTripAlias(Uri.parse('/trips?selected=trip-1&focus=11')),
      '/trips/trip-1?entry=11',
    );
    expect(selectedTripAlias(Uri.parse('/trips?selected=../x')), isNull);
    expect(selectedTripAlias(Uri.parse('/trips')), isNull);
  });

  test('root map alias 把 tripId 放進 query', () {
    expect(
      rootMapAlias(trip, Uri.parse('/x?day=3')),
      '/map?day=3&tripId=trip-1',
    );
  });

  test('帳號 sheet:來源頁 + account=page;去掉 account 就回來源頁', () {
    expect(
      accountSheetLocation(
        '/favorites?q=1',
        Uri.parse('/account/sessions'),
        'sessions',
      ),
      '/favorites?q=1&account=sessions',
    );
    expect(
      withoutAccount(Uri.parse('/favorites?q=1&account=sessions')),
      '/favorites?q=1',
    );
    expect(withoutAccount(Uri.parse('/trips?account=root')), '/trips');
  });

  test('alias 表:每個舊路徑都有對應改寫,帳號類另列', () {
    expect(
      redirectAliases.keys,
      containsAll([
        '/admin',
        '/manage',
        '/trips/new',
        '/explore',
        '/add-to-trip',
        '/trip/:tripId/stop/:entryId/edit',
      ]),
    );
    expect(redirectAliases['/admin']!(const {}, Uri.parse('/admin')), '/trips');
    expect(
      redirectAliases['/add-to-trip']!(
        const {},
        Uri.parse('/add-to-trip?place_id=p1'),
      ),
      '/favorites/add-to-trip?place_id=p1',
    );
    expect(
      accountAliases['/settings/developer-apps/new'],
      'developer-apps/new',
    );
    expect(accountAliases['/developer/apps'], 'developer-apps');
    expect(
      accountAliases.keys.toSet().intersection(redirectAliases.keys.toSet()),
      isEmpty,
    );
  });
}
