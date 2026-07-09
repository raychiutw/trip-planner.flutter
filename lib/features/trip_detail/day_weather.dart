import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/day.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

typedef DayWeatherFetcher =
    Future<TripWeatherHourly> Function(TripWeatherRequest request);

final dayWeatherFetcherProvider = Provider<DayWeatherFetcher>((ref) {
  final fetcher = OpenMeteoDayWeatherFetcher();
  ref.onDispose(fetcher.dispose);
  return fetcher.fetch;
});

final dayWeatherProvider =
    FutureProvider.family<TripWeatherHourly, TripWeatherRequest>((
      ref,
      request,
    ) {
      return ref.watch(dayWeatherFetcherProvider)(request);
    });

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
    this.timezone = 'Asia/Tokyo',
  });

  final int dayId;
  final String dayDate;
  final TripWeatherDay weatherDay;
  final String? tripStart;
  final String? tripEnd;
  final String timezone;

  @override
  bool operator ==(Object other) {
    return other is TripWeatherRequest &&
        other.dayId == dayId &&
        other.dayDate == dayDate &&
        other.weatherDay == weatherDay &&
        other.tripStart == tripStart &&
        other.tripEnd == tripEnd &&
        other.timezone == timezone;
  }

  @override
  int get hashCode {
    return Object.hash(
      dayId,
      dayDate,
      weatherDay,
      tripStart,
      tripEnd,
      timezone,
    );
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
  return TripWeatherDay(
    label: day.title ?? day.label ?? day.date ?? 'DAY ${day.dayNum}',
    locations: locations,
  );
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
    final forecastEnd = today.add(const Duration(days: 16));
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
      await _fetchAndCache(missing, fetchStart, fetchEnd, request.timezone);
    }

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

  Future<void> _fetchAndCache(
    List<TripWeatherLocation> locations,
    DateTime start,
    DateTime end,
    String timezone,
  ) async {
    final response = await _dio.get<Object?>(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': locations.map((location) => location.lat).join(','),
        'longitude': locations.map((location) => location.lon).join(','),
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'start_date': _toDateStr(start),
        'end_date': _toDateStr(end),
        'timezone': timezone,
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
    this.timezone = 'Asia/Tokyo',
  });

  final TripDay day;
  final String? tripStart;
  final String? tripEnd;
  final String timezone;

  @override
  ConsumerState<DayWeatherCard> createState() => _DayWeatherCardState();
}

class _DayWeatherCardState extends ConsumerState<DayWeatherCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final dayDate = widget.day.date;
    final weatherDay = buildWeatherDay(widget.day);
    if (dayDate == null || weatherDay == null) {
      return const SizedBox.shrink();
    }

    final diff = _daysUntil(dayDate);
    final tooFarAway = diff != null && diff > 16;
    if (tooFarAway) {
      return const _WeatherMessageRow(
        icon: Icons.wb_sunny_outlined,
        text: '天氣預報將於出發前 16 天開放',
      );
    }

    final request = TripWeatherRequest(
      dayId: widget.day.id,
      dayDate: dayDate,
      weatherDay: weatherDay,
      tripStart: widget.tripStart,
      tripEnd: widget.tripEnd,
      timezone: widget.timezone,
    );

    return ref
        .watch(dayWeatherProvider(request))
        .when(
          loading: () => const _WeatherMessageRow(
            icon: Icons.hourglass_empty_rounded,
            text: '正在載入逐時天氣預報...',
          ),
          error: (error, stackTrace) => _WeatherMessageRow(
            icon: Icons.cloud_off_outlined,
            text: '天氣資料載入失敗',
            detail: error.toString(),
          ),
          data: (hourly) {
            if (!hourly.hasData) {
              return const _WeatherMessageRow(
                icon: Icons.cloud_queue_outlined,
                text: '超出預報範圍，暫無資料',
              );
            }
            final summary = _WeatherSummary.fromHourly(hourly);
            return _WeatherForecastPanel(
              dayNum: widget.day.dayNum,
              hourly: hourly,
              summary: summary,
              locationCount: weatherDay.locations
                  .map((location) => location.name)
                  .toSet()
                  .length,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            );
          },
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
    final tones = theme.extension<TpTones>()!;

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
                    color: tones.accent,
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
                    color: tones.accent,
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
    final tones = theme.extension<TpTones>()!;
    final rainy = rain >= 50;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s1,
        vertical: TpSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: rainy
            ? tones.accent.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(TpRadius.sm),
        border: Border.all(
          color: rainy
              ? tones.accent.withValues(alpha: 0.30)
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
          Icon(_weatherIcon(code), size: 18, color: tones.accent),
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
              color: rainy ? theme.colorScheme.onSurface : tones.accent,
              fontWeight: rainy ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMessageRow extends StatelessWidget {
  const _WeatherMessageRow({
    required this.icon,
    required this.text,
    this.detail,
  });

  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: TpSpacing.s3,
        vertical: TpSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: TpSpacing.s2),
          Expanded(
            child: Text(
              detail == null ? text : '$text：$detail',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
