import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/features/trip_detail/day_weather.dart';

/// 模擬 Open-Meteo forecast endpoint 的**日期範圍契約**。
///
/// 真實 API 於 2026-07-27 實測:`end_date` 只接受到 today+15,
/// 超過即回 HTTP 400 `{"error":true,"reason":"Parameter 'end_date' is out of
/// allowed range from 2026-04-25 to 2026-08-11"}`。
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

    final latitudes = query['latitude']!.split(',');
    final payload = [
      for (var i = 0; i < latitudes.length; i++) _forecast(start, end, i),
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

  Map<String, Object?> _forecast(DateTime start, DateTime end, int index) {
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
        temps.add(20.0 + index + hour / 8);
        rains.add(10 + index);
        codes.add(index);
      }
    }
    return {
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

TripWeatherRequest _requestFor(DateTime target) {
  return TripWeatherRequest(
    dayId: 1,
    dayDate: _fmt(target),
    weatherDay: const TripWeatherDay(
      label: 'D1',
      locations: [
        TripWeatherLocation(
          name: '沖繩美麗海水族館',
          lat: 26.6942,
          lon: 127.8778,
          startHour: 9,
        ),
        TripWeatherLocation(
          name: '日落海灘',
          lat: 26.3157,
          lon: 127.7571,
          startHour: 16,
        ),
      ],
    ),
  );
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
