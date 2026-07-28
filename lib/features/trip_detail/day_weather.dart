import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/day.dart';
import '../../theme/tokens.dart';

/// Open-Meteo forecast endpoint 允許的預報天數上限(自今天起算的**額外**天數)。
///
/// 免費 forecast API 最多給 16 天,且**含今天**,亦即 `end_date` 最多到 today+15。
/// 多帶一天整包會被打回 HTTP 400
/// `Parameter 'end_date' is out of allowed range from ... to ...`,
/// 於 2026-07-27 對 `api.open-meteo.com` 實測確認。
const int kWeatherForecastHorizonDays = 15;

/// 取不到預報的原因分類 —— 決定使用者看到的下一步。
enum DayWeatherFailureKind { offline, timeout, rejected, unknown }

/// 帶「使用者看得懂的下一步」的預報失敗。
class DayWeatherFailure implements Exception {
  const DayWeatherFailure(this.kind, {this.statusCode, this.detail});

  final DayWeatherFailureKind kind;
  final int? statusCode;
  final String? detail;

  /// 給使用者看的文案 —— 一律要講得出下一步。
  String get message => switch (kind) {
    DayWeatherFailureKind.offline => '無法連線,請確認網路後重試',
    DayWeatherFailureKind.timeout => '連線逾時,請重試',
    DayWeatherFailureKind.rejected =>
      '預報服務回應異常(HTTP ${statusCode ?? '?'}),請稍後再試',
    DayWeatherFailureKind.unknown => '無法取得預報,請重試',
  };

  /// 把任意錯誤收斂成分類明確的失敗。
  factory DayWeatherFailure.from(Object error) {
    if (error is DayWeatherFailure) return error;
    if (error is! DioException) {
      return DayWeatherFailure(
        DayWeatherFailureKind.unknown,
        detail: error.toString(),
      );
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => DayWeatherFailure(
        DayWeatherFailureKind.timeout,
        detail: error.message,
      ),
      DioExceptionType.connectionError => DayWeatherFailure(
        DayWeatherFailureKind.offline,
        detail: error.message,
      ),
      DioExceptionType.badResponse => DayWeatherFailure(
        DayWeatherFailureKind.rejected,
        statusCode: error.response?.statusCode,
        detail: error.response?.data?.toString(),
      ),
      _ => DayWeatherFailure(
        DayWeatherFailureKind.unknown,
        detail: error.message,
      ),
    };
  }

  @override
  String toString() => 'DayWeatherFailure($kind, $statusCode, $detail)';
}

typedef DayWeatherFetcher =
    Future<TripWeatherHourly> Function(TripWeatherRequest request);

final dayWeatherFetcherProvider = Provider<DayWeatherFetcher>((ref) {
  final fetcher = OpenMeteoDayWeatherFetcher();
  ref.onDispose(fetcher.dispose);
  return fetcher.fetch;
});

/// 預報失敗一律立刻讓使用者看到原因與重試鍵,不走自動重試。
///
/// riverpod 3 的 `ProviderContainer.defaultRetry` 只跳過 `Error`,其餘一律指數
/// 退避重試 10 次;實測失敗會被重打 11 次、橫跨約 38 秒,期間 `AsyncValue` 停在
/// `AsyncLoading(retrying)`,畫面一直是「正在更新預報」。天氣是可有可無的輔助
/// 資訊,寧可馬上說清楚失敗原因,把要不要再試交給使用者。
Duration? _noAutoRetry(int retryCount, Object error) => null;

final dayWeatherProvider =
    FutureProvider.family<TripWeatherHourly, TripWeatherRequest>((
      ref,
      request,
    ) {
      return ref.watch(dayWeatherFetcherProvider)(request);
    }, retry: _noAutoRetry);

class TripWeatherLocation {
  const TripWeatherLocation({
    required this.name,
    required this.lat,
    required this.lon,
    required this.startHour,
  });

  final String name;
  final double lat;
  final double lon;
  final int startHour;

  @override
  bool operator ==(Object other) {
    return other is TripWeatherLocation &&
        other.name == name &&
        other.lat == lat &&
        other.lon == lon &&
        other.startHour == startHour;
  }

  @override
  int get hashCode => Object.hash(name, lat, lon, startHour);
}

class TripWeatherDay {
  const TripWeatherDay({required this.label, required this.locations});

  final String label;
  final List<TripWeatherLocation> locations;

  @override
  bool operator ==(Object other) {
    return other is TripWeatherDay &&
        other.label == label &&
        _listEquals(other.locations, locations);
  }

  @override
  int get hashCode => Object.hash(label, Object.hashAll(locations));
}

class TripWeatherHourly {
  TripWeatherHourly({
    required List<double> temps,
    required List<int> rains,
    required List<int> codes,
  }) : temps = _padDoubles(temps),
       rains = _padInts(rains),
       codes = _padInts(codes);

  factory TripWeatherHourly.empty() {
    return TripWeatherHourly(
      temps: List.filled(24, 0),
      rains: List.filled(24, 0),
      codes: List.filled(24, 0),
    );
  }

  final List<double> temps;
  final List<int> rains;
  final List<int> codes;

  bool get hasData => temps.any((temp) => temp != 0);
}

class TripWeatherRequest {
  const TripWeatherRequest({
    required this.dayId,
    required this.dayDate,
    required this.weatherDay,
    this.tripStart,
    this.tripEnd,
  });

  final int dayId;
  final String dayDate;
  final TripWeatherDay weatherDay;
  final String? tripStart;
  final String? tripEnd;

  @override
  bool operator ==(Object other) {
    return other is TripWeatherRequest &&
        other.dayId == dayId &&
        other.dayDate == dayDate &&
        other.weatherDay == weatherDay &&
        other.tripStart == tripStart &&
        other.tripEnd == tripEnd;
  }

  @override
  int get hashCode {
    return Object.hash(dayId, dayDate, weatherDay, tripStart, tripEnd);
  }
}

TripWeatherDay? buildWeatherDay(TripDay day) {
  final locations = <TripWeatherLocation>[];
  for (final entry in day.timeline) {
    final poi = entry.master;
    final lat = poi?.lat;
    final lon = poi?.lng;
    if (lat == null || lon == null) continue;

    final previous = locations.isEmpty ? null : locations.last;
    if (previous != null &&
        (previous.lat - lat).abs() < 0.01 &&
        (previous.lon - lon).abs() < 0.01) {
      continue;
    }

    final parsedHour = _parseHour(entry.startTime ?? entry.time);
    locations.add(
      TripWeatherLocation(
        name: (poi?.name?.trim().isNotEmpty ?? false)
            ? poi!.name!.trim()
            : entry.title.trim(),
        lat: lat,
        lon: lon,
        startHour: parsedHour ?? 0,
      ),
    );
  }
  if (locations.isEmpty) return null;
  return TripWeatherDay(label: day.displayTitle, locations: locations);
}

bool hasWeatherDay(TripDay day) {
  return day.date != null && buildWeatherDay(day) != null;
}

class OpenMeteoDayWeatherFetcher {
  OpenMeteoDayWeatherFetcher({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final Dio _dio;
  final Map<String, _CachedWeather> _cache = {};

  Future<TripWeatherHourly> fetch(TripWeatherRequest request) async {
    if (request.weatherDay.locations.isEmpty) {
      return TripWeatherHourly.empty();
    }

    final targetDate = _parseDateOnly(request.dayDate);
    if (targetDate == null) return TripWeatherHourly.empty();

    final today = _dateOnly(DateTime.now());
    final forecastEnd = today.add(
      const Duration(days: kWeatherForecastHorizonDays),
    );
    final tripStart = _parseDateOnly(request.tripStart);
    final tripEnd = _parseDateOnly(request.tripEnd);
    final fetchStart = tripStart != null && tripStart.isAfter(today)
        ? tripStart
        : today;
    final fetchEnd = tripEnd != null && tripEnd.isBefore(forecastEnd)
        ? tripEnd
        : forecastEnd;

    if (targetDate.isBefore(fetchStart) || targetDate.isAfter(fetchEnd)) {
      return TripWeatherHourly.empty();
    }

    final locations = _uniqueLocations(request.weatherDay.locations);
    final missing = locations
        .where((location) => !_cache.containsKey(_locationKey(location)))
        .toList();
    if (missing.isNotEmpty) {
      try {
        await _fetchAndCache(missing, fetchStart, fetchEnd);
      } catch (error) {
        throw DayWeatherFailure.from(error);
      }
    }

    // 每格取「該時段所在地點」的當地時間預報 —— 因為 `timezone=auto` 是逐座標解析
    // (見 [_fetchAndCache])。單一時區的一天(目前所有行程)整排就是當地時間;
    // 跨時區的一天則是各段落各自對齊自己的當地時間,與使用者手機到當地會自動換時
    // 區、行程表上的時間本來就是當地時間一致。代價是時區交界那格的絕對時間會小幅
    // 重疊或跳過,但比整排硬套單一時區、讓其中一段整個錯開來得可讀。
    final temps = <double>[];
    final rains = <int>[];
    final codes = <int>[];
    final dateKey = _toDateStr(targetDate);
    for (var hour = 0; hour < 24; hour++) {
      final location = _locationForHour(request.weatherDay.locations, hour);
      final cached = _cache[_locationKey(location)];
      final value = cached?.at(dateKey, hour);
      temps.add(value?.temp ?? 0);
      rains.add(value?.rain ?? 0);
      codes.add(value?.code ?? 0);
    }

    return TripWeatherHourly(temps: temps, rains: rains, codes: codes);
  }

  void dispose() {
    _dio.close(force: true);
  }

  /// 逐時預報一律以**當地時間**回傳,時區交給 Open-Meteo 從座標解析。
  ///
  /// `timezone=auto` 在多組座標下是**每組各自解析**,不是取第一組 ——
  /// 2026-07-28 對 `api.open-meteo.com` 實測:
  ///
  /// ```
  /// curl -s "https://api.open-meteo.com/v1/forecast?latitude=26.21,25.01\
  /// &longitude=127.68,121.46&hourly=temperature_2m&timezone=auto&forecast_days=1"
  /// [{"latitude":26.18629,...,"utc_offset_seconds":32400,"timezone":"Asia/Tokyo",...},
  ///  {"latitude":24.99121,...,"utc_offset_seconds":28800,"timezone":"Asia/Taipei",...}]
  /// ```
  ///
  /// 所以每組座標的 `hourly.time` 標籤就是該地當地時間,新增目的地不必維護任何
  /// 時區對照表。快取以座標為鍵([_locationKey]),與時區一對一,不會互相污染。
  Future<void> _fetchAndCache(
    List<TripWeatherLocation> locations,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _dio.get<Object?>(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': locations.map((location) => location.lat).join(','),
        'longitude': locations.map((location) => location.lon).join(','),
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'start_date': _toDateStr(start),
        'end_date': _toDateStr(end),
        'timezone': 'auto',
      },
    );

    final decoded = switch (response.data) {
      final String body => jsonDecode(body),
      final Object? body => body,
    };
    final items = decoded is List ? decoded : [decoded];
    for (var i = 0; i < locations.length; i++) {
      final item = i < items.length ? items[i] : null;
      _cache[_locationKey(locations[i])] = _CachedWeather.fromJson(item);
    }

    while (_cache.length > 20) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class DayWeatherCard extends ConsumerStatefulWidget {
  const DayWeatherCard({
    super.key,
    required this.day,
    this.tripStart,
    this.tripEnd,
  });

  final TripDay day;
  final String? tripStart;
  final String? tripEnd;

  @override
  ConsumerState<DayWeatherCard> createState() => _DayWeatherCardState();
}

/// 真實預報尚未可用時顯示的明確示意狀態。
class DayWeatherPreview extends StatelessWidget {
  const DayWeatherPreview({
    super.key,
    required this.dayNum,
    this.statusText,
    this.onRetry,
  });

  final int dayNum;
  final String? statusText;

  /// 只有「重試有意義」的失敗狀態才給,載入中與尚未開放不給。
  final VoidCallback? onRetry;

  ({String temperature, String condition, String rain, IconData icon})
  get _sample => switch ((dayNum - 1) % 4) {
    0 => (
      temperature: '28°C',
      condition: '晴時多雲',
      rain: '降雨 20%',
      icon: CupertinoIcons.cloud_sun_fill,
    ),
    1 => (
      temperature: '27°C',
      condition: '多雲',
      rain: '降雨 30%',
      icon: CupertinoIcons.cloud_fill,
    ),
    2 => (
      temperature: '29°C',
      condition: '晴朗',
      rain: '降雨 10%',
      icon: CupertinoIcons.sun_max_fill,
    ),
    _ => (
      temperature: '26°C',
      condition: '短暫陣雨',
      rain: '降雨 40%',
      icon: CupertinoIcons.cloud_rain_fill,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sample = _sample;
    return Container(
      key: ValueKey('day-weather-preview-$dayNum'),
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s3,
        vertical: TpSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(TpRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            sample.icon,
            size: 22,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: TpSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '天氣示意',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Wrap(
                  spacing: TpSpacing.s2,
                  children: [
                    Text(
                      sample.condition,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      sample.rain,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (statusText != null)
                  Text(
                    statusText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (onRetry != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey('day-weather-retry-$dayNum'),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('重試'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TpSpacing.s2,
                        ),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            sample.temperature,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayWeatherCardState extends ConsumerState<DayWeatherCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dayDate = widget.day.date;
    final weatherDay = buildWeatherDay(widget.day);
    if (dayDate == null || weatherDay == null) {
      return DayWeatherPreview(
        dayNum: widget.day.dayNum,
        statusText: '尚無可用預報位置',
      );
    }

    // 上限與 [kWeatherForecastHorizonDays] 一致 —— 否則會送出注定 400 的請求,
    // 使用者看到的是錯誤而不是「尚未開放」。
    final diff = _daysUntil(dayDate);
    if (diff != null && diff > kWeatherForecastHorizonDays) {
      return DayWeatherPreview(
        dayNum: widget.day.dayNum,
        statusText: '天氣預報將於出發前 16 天開放',
      );
    }

    final request = TripWeatherRequest(
      dayId: widget.day.id,
      dayDate: dayDate,
      weatherDay: weatherDay,
      tripStart: widget.tripStart,
      tripEnd: widget.tripEnd,
    );

    final content = ref
        .watch(dayWeatherProvider(request))
        .when<Widget>(
          loading: () => DayWeatherPreview(
            dayNum: widget.day.dayNum,
            statusText: '正在更新預報',
          ),
          error: (error, stackTrace) => DayWeatherPreview(
            dayNum: widget.day.dayNum,
            statusText: DayWeatherFailure.from(error).message,
            onRetry: () => ref.invalidate(dayWeatherProvider(request)),
          ),
          data: (hourly) {
            if (!hourly.hasData) {
              return DayWeatherPreview(
                dayNum: widget.day.dayNum,
                statusText: '目前沒有可用預報',
              );
            }
            final summary = _WeatherSummary.fromHourly(hourly);
            return KeyedSubtree(
              key: ValueKey('day-weather-live-${widget.day.dayNum}'),
              child: _WeatherForecastPanel(
                dayNum: widget.day.dayNum,
                hourly: hourly,
                summary: summary,
                locationCount: weatherDay.locations
                    .map((location) => location.name)
                    .toSet()
                    .length,
                expanded: _expanded,
                onToggle: () => setState(() => _expanded = !_expanded),
              ),
            );
          },
        );

    return AnimatedSwitcher(
      duration: TpMotion.resolve(context, const Duration(milliseconds: 200)),
      switchInCurve: TpMotion.appleEase,
      switchOutCurve: TpMotion.appleEase,
      child: content,
    );
  }
}

class _WeatherForecastPanel extends StatelessWidget {
  const _WeatherForecastPanel({
    required this.dayNum,
    required this.hourly,
    required this.summary,
    required this.locationCount,
    required this.expanded,
    required this.onToggle,
  });

  final int dayNum;
  final TripWeatherHourly hourly;
  final _WeatherSummary summary;
  final int locationCount;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('day-weather-toggle-$dayNum'),
            borderRadius: BorderRadius.circular(TpRadius.md),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TpSpacing.s3,
                vertical: TpSpacing.s2,
              ),
              child: Row(
                children: [
                  Icon(
                    _weatherIcon(summary.code),
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: TpSpacing.s2),
                  Text(
                    '天氣',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: TpSpacing.s3),
                  Text(
                    '${summary.minTemp}~${summary.maxTemp}°C',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: TpSpacing.s3),
                  Icon(
                    Icons.water_drop_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: TpSpacing.s1),
                  Text(
                    '降雨 ${summary.minRain}~${summary.maxRain}%',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(TpSpacing.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '逐時預報（$locationCount 個地點）',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: TpSpacing.s2),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var hour = 0; hour < 24; hour++)
                          Padding(
                            padding: EdgeInsets.only(
                              right: hour == 23 ? 0 : TpSpacing.s2,
                            ),
                            child: _HourlyWeatherTile(
                              hour: hour,
                              temp: hourly.temps[hour].round(),
                              rain: hourly.rains[hour],
                              code: hourly.codes[hour],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HourlyWeatherTile extends StatelessWidget {
  const _HourlyWeatherTile({
    required this.hour,
    required this.temp,
    required this.rain,
    required this.code,
  });

  final int hour;
  final int temp;
  final int rain;
  final int code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rainy = rain >= 50;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s1,
        vertical: TpSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: rainy
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(TpRadius.sm),
        border: Border.all(
          color: rainy
              ? theme.colorScheme.primary.withValues(alpha: 0.30)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$hour:00',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: TpSpacing.s1),
          Icon(_weatherIcon(code), size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: TpSpacing.s1),
          Text(
            '$temp°',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '$rain%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: rainy
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.primary,
              fontWeight: rainy ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherSummary {
  const _WeatherSummary({
    required this.minTemp,
    required this.maxTemp,
    required this.minRain,
    required this.maxRain,
    required this.code,
  });

  factory _WeatherSummary.fromHourly(TripWeatherHourly hourly) {
    var minTemp = 99;
    var maxTemp = -99;
    var minRain = 100;
    var maxRain = 0;
    final codeCounts = <int, int>{};

    for (var hour = 0; hour < 24; hour++) {
      final temp = hourly.temps[hour].round();
      final rain = hourly.rains[hour];
      final code = hourly.codes[hour];
      minTemp = math.min(minTemp, temp);
      maxTemp = math.max(maxTemp, temp);
      minRain = math.min(minRain, rain);
      maxRain = math.max(maxRain, rain);
      codeCounts[code] = (codeCounts[code] ?? 0) + 1;
    }

    var bestCode = 0;
    var bestCount = 0;
    for (final entry in codeCounts.entries) {
      if (entry.value > bestCount) {
        bestCode = entry.key;
        bestCount = entry.value;
      }
    }

    return _WeatherSummary(
      minTemp: minTemp,
      maxTemp: maxTemp,
      minRain: minRain,
      maxRain: maxRain,
      code: bestCode,
    );
  }

  final int minTemp;
  final int maxTemp;
  final int minRain;
  final int maxRain;
  final int code;
}

class _CachedWeather {
  const _CachedWeather({required this.hourly});

  factory _CachedWeather.fromJson(Object? json) {
    if (json is! Map) return const _CachedWeather(hourly: {});
    final hourly = json['hourly'];
    if (hourly is! Map) return const _CachedWeather(hourly: {});

    final times = (hourly['time'] as List?) ?? const [];
    final temps = (hourly['temperature_2m'] as List?) ?? const [];
    final rains = (hourly['precipitation_probability'] as List?) ?? const [];
    final codes = (hourly['weather_code'] as List?) ?? const [];
    final values = <String, _CachedHour>{};

    for (var i = 0; i < times.length; i++) {
      final time = times[i]?.toString();
      if (time == null) continue;
      values[time] = _CachedHour(
        temp: (i < temps.length ? temps[i] as num? : null)?.toDouble() ?? 0,
        rain: (i < rains.length ? rains[i] as num? : null)?.round() ?? 0,
        code: (i < codes.length ? codes[i] as num? : null)?.round() ?? 0,
      );
    }

    return _CachedWeather(hourly: values);
  }

  final Map<String, _CachedHour> hourly;

  _CachedHour? at(String dateKey, int hour) {
    return hourly['${dateKey}T${hour.toString().padLeft(2, '0')}:00'];
  }
}

class _CachedHour {
  const _CachedHour({
    required this.temp,
    required this.rain,
    required this.code,
  });

  final double temp;
  final int rain;
  final int code;
}

IconData _weatherIcon(int code) {
  return switch (code) {
    0 => Icons.wb_sunny_outlined,
    1 || 2 || 3 => Icons.wb_cloudy_outlined,
    45 || 48 => Icons.foggy,
    51 || 53 || 55 || 56 || 57 => Icons.grain_outlined,
    61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => Icons.water_drop_outlined,
    71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_outlined,
    95 || 96 || 99 => Icons.thunderstorm_outlined,
    _ => Icons.help_outline_rounded,
  };
}

int? _parseHour(String? value) {
  if (value == null) return null;
  final match = RegExp(r'(\d{1,2}):').firstMatch(value);
  final hour = int.tryParse(match?.group(1) ?? '');
  if (hour == null) return null;
  return hour.clamp(0, 23);
}

int? _daysUntil(String dayDate) {
  final target = _parseDateOnly(dayDate);
  if (target == null) return null;
  return target.difference(_dateOnly(DateTime.now())).inDays;
}

DateTime? _parseDateOnly(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return _dateOnly(parsed);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _toDateStr(DateTime value) {
  return [
    value.year.toString().padLeft(4, '0'),
    value.month.toString().padLeft(2, '0'),
    value.day.toString().padLeft(2, '0'),
  ].join('-');
}

String _locationKey(TripWeatherLocation location) {
  return '${location.lat.toStringAsFixed(4)},${location.lon.toStringAsFixed(4)}';
}

List<TripWeatherLocation> _uniqueLocations(
  List<TripWeatherLocation> locations,
) {
  final seen = <String>{};
  final result = <TripWeatherLocation>[];
  for (final location in locations) {
    final key = _locationKey(location);
    if (seen.add(key)) result.add(location);
  }
  return result;
}

TripWeatherLocation _locationForHour(
  List<TripWeatherLocation> locations,
  int hour,
) {
  var current = locations.first;
  for (final location in locations) {
    if (location.startHour <= hour) current = location;
  }
  return current;
}

List<double> _padDoubles(List<double> values) {
  return [for (var i = 0; i < 24; i++) i < values.length ? values[i] : 0];
}

List<int> _padInts(List<int> values) {
  return [for (var i = 0; i < 24; i++) i < values.length ? values[i] : 0];
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
