/// Data model used by the print/PDF document.
library;

import '../../models/day.dart';
import '../../models/entry.dart';
import '../../models/notes.dart';
import '../../models/segment.dart';
import '../../models/share.dart';
import '../../models/trip.dart';

/// 列印、PDF 與公開分享共用的交通摘要。
String formatTravelLine(Travel? travel) {
  if (travel == null) return '';
  if (travel.sameplace) return '不需計算路程';
  final rawType = travel.type.trim();
  final submode = travel.submode?.trim();
  final parts = <String>[
    if (submode?.isNotEmpty == true)
      travelMethodLabel('transit', submode)
    else if (rawType.isNotEmpty)
      _legacyTravelModeLabel(rawType),
    if (travel.min != null && travel.min! > 0) '${travel.min} 分',
    if (travel.distanceM != null && travel.distanceM! > 0)
      '${(travel.distanceM! / 1000).toStringAsFixed(1)}km',
  ];
  return parts.join(' · ');
}

String _legacyTravelModeLabel(String value) {
  return switch (value) {
    'driving' || 'car' || 'drive' => '開車',
    'walking' || 'walk' => '步行',
    'transit' => '大眾運輸',
    'bus' => '公車',
    'train' => '火車',
    'metro' || 'subway' => '捷運',
    'ferry' => '渡輪',
    'flight' || 'plane' => '飛機',
    _ => value,
  };
}

/// Aggregated trip, days, and notes used to render print/PDF documents.
class TripPrintData {
  const TripPrintData({
    required this.trip,
    required this.days,
    required this.notes,
  });

  factory TripPrintData.fromPublicShare(PublicTripShare share) {
    return TripPrintData(
      trip: Trip(
        id: 'public-share',
        name: share.name,
        title: share.title,
        countries: share.countries,
        destinations: [
          for (final destination in share.destinations)
            TripDestination(name: destination),
        ],
      ),
      days: share.days,
      notes: share.notes,
    );
  }

  final Trip trip;
  final List<TripDay> days;
  final TripNotes notes;

  /// User-facing trip title with fallback for untitled imported trips.
  String get displayTitle {
    final title = trip.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final name = trip.name.trim();
    return name.isEmpty ? '未命名行程' : name;
  }

  /// Destination summary shown below the document title.
  String get destinationsLabel {
    final destinations = trip.destinations
        .map((destination) => destination.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (destinations.isNotEmpty) return destinations.join(' · ');
    return trip.countries?.trim() ?? '';
  }

  /// First-to-last day date range, or an empty string when days are undated.
  String get dateRange {
    final datedDays = days
        .map((day) => day.date?.trim())
        .whereType<String>()
        .where((date) => date.isNotEmpty)
        .toList();
    if (datedDays.isEmpty) return '';
    final first = datedDays.first;
    final last = datedDays.last;
    return first == last ? first : '$first – $last';
  }

  /// Compact metadata line combining date range, destinations, and day count.
  String get metaLine {
    return [
      dateRange,
      destinationsLabel,
      days.isEmpty ? '' : '${days.length} 天',
    ].where((part) => part.trim().isNotEmpty).join(' · ');
  }

  /// Safe PDF filename based on trip title and generation date.
  String pdfFileName({DateTime? now}) {
    final date = now ?? DateTime.now();
    final datePart =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${_safeFileBase('$displayTitle-$datePart')}.pdf';
  }
}

String _safeFileBase(String raw) {
  final stripped = raw.replaceAll(RegExp(r'[\\/\x00-\x1F<>:"|?*]'), '_').trim();
  if (stripped.isEmpty) return 'trip';
  return stripped.length > 80 ? stripped.substring(0, 80) : stripped;
}
