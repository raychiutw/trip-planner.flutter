import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/day_weather.dart';
import 'package:tripline/models/day.dart';
import 'package:tripline/models/entry.dart';
import 'package:tripline/theme/app_theme.dart';

const _okinawaDay = TripDay(
  id: 1,
  dayNum: 1,
  date: '2026-04-23',
  title: '北部海岸線',
  version: 1,
  timeline: [
    TimelineEntry(
      id: 11,
      sortOrder: 0,
      startTime: '09:00',
      title: '美麗海水族館',
      version: 1,
      master: EntryPoiInfo(
        poiId: 101,
        name: '沖繩美麗海水族館',
        lat: 26.6942,
        lng: 127.8778,
      ),
    ),
    TimelineEntry(
      id: 12,
      sortOrder: 1,
      startTime: '13:30',
      title: '海人食堂',
      version: 1,
      master: EntryPoiInfo(
        poiId: 102,
        name: '海人食堂',
        lat: 26.6944,
        lng: 127.878,
      ),
    ),
    TimelineEntry(
      id: 13,
      sortOrder: 2,
      startTime: '16:00',
      title: '日落海灘',
      version: 1,
      master: EntryPoiInfo(
        poiId: 103,
        name: '日落海灘',
        lat: 26.3157,
        lng: 127.7571,
      ),
    ),
  ],
);

void main() {
  test('buildWeatherDay 使用 entry POI 產生去重後的取樣地點', () {
    final weatherDay = buildWeatherDay(_okinawaDay);

    expect(weatherDay, isNotNull);
    expect(weatherDay!.label, '2026-04-23');
    expect(weatherDay.locations, hasLength(2));
    expect(weatherDay.locations.first.name, '沖繩美麗海水族館');
    expect(weatherDay.locations.first.startHour, 9);
    expect(weatherDay.locations.last.name, '日落海灘');
    expect(weatherDay.locations.last.startHour, 16);
  });

  testWidgets('DayWeatherCard 顯示摘要並可展開逐時預報', (tester) async {
    final hourly = TripWeatherHourly(
      temps: [for (var h = 0; h < 24; h++) 22.0 + h / 4],
      rains: [for (var h = 0; h < 24; h++) h < 12 ? 10 : 60],
      codes: [for (var h = 0; h < 24; h++) h < 12 ? 0 : 61],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue((request) async {
            expect(request.dayDate, '2026-04-23');
            expect(request.weatherDay.locations, hasLength(2));
            return hourly;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('天氣'), findsOneWidget);
    expect(find.text('22~28°C'), findsOneWidget);
    expect(find.text('降雨 10~60%'), findsOneWidget);
    expect(find.textContaining('逐時預報'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('day-weather-toggle-1')));
    await tester.pumpAndSettle();

    expect(find.text('逐時預報（2 個地點）'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('23:00'), findsOneWidget);
  });

  testWidgets(
    'DayWeatherCard keeps the labeled preview until live data arrives',
    (tester) async {
      final completer = Completer<TripWeatherHourly>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayWeatherFetcherProvider.overrideWithValue(
              (request) => completer.future,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('day-weather-preview-1')),
        findsOneWidget,
      );
      expect(find.text('天氣示意'), findsOneWidget);
      expect(find.text('正在更新預報'), findsOneWidget);

      completer.complete(
        TripWeatherHourly(
          temps: [for (var h = 0; h < 24; h++) 24],
          rains: [for (var h = 0; h < 24; h++) 20],
          codes: [for (var h = 0; h < 24; h++) 1],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('day-weather-live-1')), findsOneWidget);
      expect(find.text('天氣示意'), findsNothing);
    },
  );

  testWidgets('forecast outside the range stays explicitly labeled as sample', (
    tester,
  ) async {
    final date = DateTime.now().add(const Duration(days: 30));
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final day = TripDay(
      id: 99,
      dayNum: 3,
      date: dateText,
      version: 1,
      timeline: _okinawaDay.timeline,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: DayWeatherCard(day: day)),
        ),
      ),
    );

    expect(find.text('天氣示意'), findsOneWidget);
    expect(find.text('天氣預報將於出發前 16 天開放'), findsOneWidget);
  });

  testWidgets('provider failure stays in a labeled preview state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue(
            (request) => Future.error(StateError('forecast unavailable')),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('天氣示意'), findsOneWidget);
    expect(find.text('無法取得預報,請重試'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('取不到預報時只打一次 API,不被 riverpod 靜默重試', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue((request) async {
            calls++;
            throw const DayWeatherFailure(DayWeatherFailureKind.offline);
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // riverpod 3 的 defaultRetry 會把「非 Error」的失敗自動重試 10 次,
    // 期間 AsyncValue 停在 AsyncLoading(retrying),使用者只看得到載入態。
    expect(find.text('正在更新預報'), findsNothing);
    expect(find.text('無法連線,請確認網路後重試'), findsOneWidget);

    // 把假時鐘往前推超過預設退避總長(約 38 秒),確認沒有被靜默重打。
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(calls, 1);
  });

  testWidgets('離線失敗時給出可行動文案與重試鍵', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue(
            (request) => Future.error(
              const DayWeatherFailure(DayWeatherFailureKind.offline),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('無法連線,請確認網路後重試'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-weather-retry-1')), findsOneWidget);
  });

  testWidgets('按重試會重抓並顯示實際預報', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue((request) async {
            calls++;
            if (calls == 1) {
              throw const DayWeatherFailure(DayWeatherFailureKind.timeout);
            }
            return TripWeatherHourly(
              temps: [for (var h = 0; h < 24; h++) 24],
              rains: [for (var h = 0; h < 24; h++) 20],
              codes: [for (var h = 0; h < 24; h++) 1],
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('連線逾時,請重試'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('day-weather-retry-1')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(const ValueKey('day-weather-live-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-weather-retry-1')), findsNothing);
  });

  testWidgets('尚未開放與載入中的示意卡不給重試鍵', (tester) async {
    final completer = Completer<TripWeatherHourly>();
    addTearDown(() => completer.complete(TripWeatherHourly.empty()));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue(
            (request) => completer.future,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('正在更新預報'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-weather-retry-1')), findsNothing);
  });

  testWidgets('恰好 16 天後的行程日不打 API,維持既有的 16 天文案', (tester) async {
    final date = DateTime.now().add(const Duration(days: 16));
    final dateText =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final day = TripDay(
      id: 98,
      dayNum: 2,
      date: dateText,
      version: 1,
      timeline: _okinawaDay.timeline,
    );
    var calls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue((request) async {
            calls++;
            return TripWeatherHourly.empty();
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: DayWeatherCard(day: day)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('天氣預報將於出發前 16 天開放'), findsOneWidget);
  });

  testWidgets('empty hourly data never renders a misleading live forecast', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayWeatherFetcherProvider.overrideWithValue(
            (request) async => TripWeatherHourly.empty(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('天氣示意'), findsOneWidget);
    expect(find.text('目前沒有可用預報'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-weather-live-1')), findsNothing);
  });
}
