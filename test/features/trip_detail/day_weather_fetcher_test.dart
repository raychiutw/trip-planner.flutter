import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/day_weather.dart';

/// 測試座標對應的真實時區 —— 模擬 Open-Meteo `timezone=auto` 的座標解析。
///
/// key 是 `lat,lon` 各取小數點後兩位。查不到就讓測試大聲失敗,避免新增 fixture
/// 時默默拿到錯的時區。
const _fixtureZones = <String, ({String name, int offsetHours})>{
  '26.69,127.88': (name: 'Asia/Tokyo', offsetHours: 9), // 沖繩美麗海水族館
  '26.32,127.76': (name: 'Asia/Tokyo', offsetHours: 9), // 沖繩日落海灘
  '34.99,135.78': (name: 'Asia/Tokyo', offsetHours: 9), // 京都清水寺
  '25.01,121.46': (name: 'Asia/Taipei', offsetHours: 8), // 板橋車站
};

const _namedZoneOffsets = <String, int>{'Asia/Tokyo': 9, 'Asia/Taipei': 8};

/// 模擬 Open-Meteo forecast endpoint 的**日期範圍**與**時區解析**契約。
///
/// 日期範圍:真實 API 於 2026-07-27 實測,`end_date` 只接受到 today+15,
/// 超過即回 HTTP 400 `{"error":true,"reason":"Parameter 'end_date' is out of
/// allowed range from 2026-04-25 to 2026-08-11"}`。
///
/// 時區:`timezone=auto` 對**每組座標各自解析**(不是取第一組),
/// 2026-07-28 實測:
///
/// ```
/// curl -s "https://api.open-meteo.com/v1/forecast?latitude=26.21,25.01\
/// &longitude=127.68,121.46&hourly=temperature_2m&timezone=auto&forecast_days=1"
/// [{"latitude":26.18629,...,"utc_offset_seconds":32400,"timezone":"Asia/Tokyo",...},
///  {"latitude":24.99121,...,"utc_offset_seconds":28800,"timezone":"Asia/Taipei",...}]
/// ```
///
/// 因此回傳的 `hourly.time` 標籤是**該組座標的當地時間**。這裡把每小時的氣溫
/// 訂為「該時刻的 UTC 小時 + 20」,時區一旦對錯,取到的值就會整排位移。
class _OpenMeteoContractAdapter implements HttpClientAdapter {
  _OpenMeteoContractAdapter({required this.today});

  final DateTime today;
  final List<Map<String, String>> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final query = options.uri.queryParameters;
    requests.add(query);

    final start = DateTime.parse(query['start_date']!);
    final end = DateTime.parse(query['end_date']!);
    final lastAllowed = today.add(const Duration(days: 15));
    if (end.isAfter(lastAllowed)) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': true,
          'reason':
              "Parameter 'end_date' is out of allowed range from "
              '${_fmt(today.subtract(const Duration(days: 92)))} to '
              '${_fmt(lastAllowed)}',
        }),
        400,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    final requestedZone = query['timezone']!;
    final latitudes = query['latitude']!.split(',');
    final longitudes = query['longitude']!.split(',');
    final payload = [
      for (var i = 0; i < latitudes.length; i++)
        _forecast(
          start,
          end,
          i,
          _resolveZone(requestedZone, latitudes[i], longitudes[i]),
        ),
    ];
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  ({String name, int offsetHours}) _resolveZone(
    String requestedZone,
    String latitude,
    String longitude,
  ) {
    if (requestedZone == 'auto') {
      final key =
          '${double.parse(latitude).toStringAsFixed(2)},'
          '${double.parse(longitude).toStringAsFixed(2)}';
      final zone = _fixtureZones[key];
      if (zone == null) {
        throw StateError('fixture 缺少 $key 的時區,請補進 _fixtureZones');
      }
      return zone;
    }
    final offset = _namedZoneOffsets[requestedZone];
    if (offset == null) {
      throw StateError('fixture 缺少 $requestedZone 的 offset');
    }
    return (name: requestedZone, offsetHours: offset);
  }

  Map<String, Object?> _forecast(
    DateTime start,
    DateTime end,
    int index,
    ({String name, int offsetHours}) zone,
  ) {
    final times = <String>[];
    final temps = <double>[];
    final rains = <int>[];
    final codes = <int>[];
    for (
      var date = start;
      !date.isAfter(end);
      date = date.add(const Duration(days: 1))
    ) {
      for (var hour = 0; hour < 24; hour++) {
        times.add('${_fmt(date)}T${hour.toString().padLeft(2, '0')}:00');
        temps.add(20.0 + (hour - zone.offsetHours) % 24);
        rains.add(10 + index);
        codes.add(index);
      }
    }
    return {
      'timezone': zone.name,
      'utc_offset_seconds': zone.offsetHours * 3600,
      'hourly': {
        'time': times,
        'temperature_2m': temps,
        'precipitation_probability': rains,
        'weather_code': codes,
      },
    };
  }
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.error);

  final Object error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw error;
  }

  @override
  void close({bool force = false}) {}
}

String _fmt(DateTime value) {
  return [
    value.year.toString().padLeft(4, '0'),
    value.month.toString().padLeft(2, '0'),
    value.day.toString().padLeft(2, '0'),
  ].join('-');
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// 該小時的當地時間標籤對應到的氣溫 —— 時區對了才會相符。
double _tempAtUtcHour(int utcHour) => 20.0 + utcHour;

const _okinawaAquarium = TripWeatherLocation(
  name: '沖繩美麗海水族館',
  lat: 26.6942,
  lon: 127.8778,
  startHour: 9,
);
const _okinawaSunsetBeach = TripWeatherLocation(
  name: '日落海灘',
  lat: 26.3157,
  lon: 127.7571,
  startHour: 16,
);
const _kyotoKiyomizu = TripWeatherLocation(
  name: '清水寺',
  lat: 34.9948,
  lon: 135.7800,
  startHour: 9,
);
const _banqiaoStation = TripWeatherLocation(
  name: '板橋車站',
  lat: 25.0100,
  lon: 121.4600,
  startHour: 9,
);

TripWeatherRequest _requestWith(
  DateTime target,
  List<TripWeatherLocation> locations, {
  int dayId = 1,
}) {
  return TripWeatherRequest(
    dayId: dayId,
    dayDate: _fmt(target),
    weatherDay: TripWeatherDay(label: 'D$dayId', locations: locations),
  );
}

TripWeatherRequest _requestFor(DateTime target) {
  return _requestWith(target, const [_okinawaAquarium, _okinawaSunsetBeach]);
}

void main() {
  test('請求的 end_date 落在 Open-Meteo 允許範圍內,行程日才拿得到實際預報', () async {
    final today = _dateOnly(DateTime.now());
    final adapter = _OpenMeteoContractAdapter(today: today);
    final fetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(fetcher.dispose);

    final hourly = await fetcher.fetch(
      _requestFor(today.add(const Duration(days: 3))),
    );

    expect(
      adapter.requests.single['end_date'],
      _fmt(today.add(const Duration(days: 15))),
      reason: 'Open-Meteo 只接受到 today+15,多一天整包 400',
    );
    expect(hourly.hasData, isTrue);
    expect(hourly.temps[9], greaterThan(0));
  });

  test('預報範圍最後一天(today+15)仍抓得到資料', () async {
    final today = _dateOnly(DateTime.now());
    final adapter = _OpenMeteoContractAdapter(today: today);
    final fetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(fetcher.dispose);

    final hourly = await fetcher.fetch(
      _requestFor(today.add(const Duration(days: 15))),
    );

    expect(hourly.hasData, isTrue);
  });

  test('板橋的一天,逐時預報對齊台北當地時間而非東京時間', () async {
    final today = _dateOnly(DateTime.now());
    final adapter = _OpenMeteoContractAdapter(today: today);
    final fetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(fetcher.dispose);

    final hourly = await fetcher.fetch(
      _requestWith(today.add(const Duration(days: 1)), const [_banqiaoStation]),
    );

    expect(
      adapter.requests.single['timezone'],
      'auto',
      reason: '時區交給 Open-Meteo 從座標解析,不硬編目的地',
    );
    expect(
      hourly.temps[15],
      _tempAtUtcHour(7),
      reason: '台北 15:00 是 UTC 07:00;沿用東京時間會拿到 UTC 06:00 的值,整排差一小時',
    );
    expect(hourly.temps[0], _tempAtUtcHour(16));
  });

  test('timezone=auto 對多組座標各自解析,跨時區的一天各段落各自對齊當地時間', () async {
    final today = _dateOnly(DateTime.now());
    final adapter = _OpenMeteoContractAdapter(today: today);
    final fetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(fetcher.dispose);

    // 上午在板橋(UTC+8),16:00 起飛抵沖繩(UTC+9)。
    final hourly = await fetcher.fetch(
      _requestWith(today.add(const Duration(days: 2)), const [
        TripWeatherLocation(
          name: '板橋車站',
          lat: 25.0100,
          lon: 121.4600,
          startHour: 0,
        ),
        _okinawaSunsetBeach,
      ]),
    );

    expect(
      hourly.temps[9],
      _tempAtUtcHour(1),
      reason: '板橋時段用台北時間:09:00 = UTC 01:00',
    );
    expect(hourly.rains[9], 10, reason: '09:00 取第一組座標(板橋)的預報');
    expect(
      hourly.temps[18],
      _tempAtUtcHour(9),
      reason: '沖繩時段用東京時間:18:00 = UTC 09:00',
    );
    expect(hourly.rains[18], 11, reason: '18:00 取第二組座標(沖繩)的預報');
  });

  test('沖繩與京都(UTC+9)的顯示結果不因改用 auto 而改變', () async {
    final today = _dateOnly(DateTime.now());
    final target = today.add(const Duration(days: 4));

    final okinawaAdapter = _OpenMeteoContractAdapter(today: today);
    final okinawaFetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = okinawaAdapter,
    );
    addTearDown(okinawaFetcher.dispose);
    final okinawa = await okinawaFetcher.fetch(_requestFor(target));

    expect(okinawa.temps[9], _tempAtUtcHour(0), reason: '東京 09:00 = UTC 00:00');
    expect(okinawa.temps[23], _tempAtUtcHour(14));

    final kyotoAdapter = _OpenMeteoContractAdapter(today: today);
    final kyotoFetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = kyotoAdapter,
    );
    addTearDown(kyotoFetcher.dispose);
    final kyoto = await kyotoFetcher.fetch(
      _requestWith(target, const [_kyotoKiyomizu]),
    );

    expect(kyoto.temps[9], _tempAtUtcHour(0));
    expect(kyoto.temps[23], _tempAtUtcHour(14));
  });

  test('快取以座標為鍵:同一天不同地點不互相污染,重複查詢不重打 API', () async {
    final today = _dateOnly(DateTime.now());
    final adapter = _OpenMeteoContractAdapter(today: today);
    final fetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = adapter,
    );
    addTearDown(fetcher.dispose);

    final request = _requestWith(today.add(const Duration(days: 2)), const [
      TripWeatherLocation(
        name: '板橋車站',
        lat: 25.0100,
        lon: 121.4600,
        startHour: 0,
      ),
      _okinawaSunsetBeach,
    ]);

    final first = await fetcher.fetch(request);
    final again = await fetcher.fetch(request);

    expect(adapter.requests, hasLength(1), reason: '兩組座標都已快取,第二次不再打 API');
    expect(first.temps[9], again.temps[9]);
    expect(again.temps[9], _tempAtUtcHour(1), reason: '板橋仍是台北時間,沒被沖繩的快取蓋掉');
    expect(again.temps[18], _tempAtUtcHour(9), reason: '沖繩仍是東京時間');
  });

  test('連線失敗時丟出帶可行動文案的 DayWeatherFailure', () async {
    final fetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()
        ..httpClientAdapter = _ThrowingAdapter(
          DioException.connectionError(
            requestOptions: RequestOptions(),
            reason: 'network is unreachable',
          ),
        ),
    );
    addTearDown(fetcher.dispose);

    await expectLater(
      fetcher.fetch(_requestFor(_dateOnly(DateTime.now()))),
      throwsA(
        isA<DayWeatherFailure>()
            .having((e) => e.kind, 'kind', DayWeatherFailureKind.offline)
            .having((e) => e.message, 'message', contains('重試')),
      ),
    );
  });

  test('伺服器回非 2xx 時保留狀態碼,文案指向稍後再試', () async {
    final today = _dateOnly(DateTime.now());
    final fetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()
        ..httpClientAdapter = _ThrowingAdapter(
          DioException.badResponse(
            statusCode: 400,
            requestOptions: RequestOptions(),
            response: Response<Object?>(
              requestOptions: RequestOptions(),
              statusCode: 400,
              data: {'error': true, 'reason': 'bad range'},
            ),
          ),
        ),
    );
    addTearDown(fetcher.dispose);

    await expectLater(
      fetcher.fetch(_requestFor(today.add(const Duration(days: 1)))),
      throwsA(
        isA<DayWeatherFailure>()
            .having((e) => e.kind, 'kind', DayWeatherFailureKind.rejected)
            .having((e) => e.message, 'message', contains('400'))
            .having((e) => e.message, 'message', contains('稍後')),
      ),
    );
  });

  test('逾時與未知錯誤各自對應到不同的可行動文案', () async {
    final today = _dateOnly(DateTime.now());

    final timeoutFetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()
        ..httpClientAdapter = _ThrowingAdapter(
          DioException.receiveTimeout(
            timeout: const Duration(seconds: 8),
            requestOptions: RequestOptions(),
          ),
        ),
    );
    addTearDown(timeoutFetcher.dispose);

    await expectLater(
      timeoutFetcher.fetch(_requestFor(today.add(const Duration(days: 1)))),
      throwsA(
        isA<DayWeatherFailure>().having(
          (e) => e.kind,
          'kind',
          DayWeatherFailureKind.timeout,
        ),
      ),
    );

    final brokenFetcher = OpenMeteoDayWeatherFetcher(
      dio: Dio()..httpClientAdapter = _ThrowingAdapter(StateError('boom')),
    );
    addTearDown(brokenFetcher.dispose);

    await expectLater(
      brokenFetcher.fetch(_requestFor(today.add(const Duration(days: 1)))),
      throwsA(
        isA<DayWeatherFailure>()
            .having((e) => e.kind, 'kind', DayWeatherFailureKind.unknown)
            .having((e) => e.message, 'message', contains('重試')),
      ),
    );
  });
}
