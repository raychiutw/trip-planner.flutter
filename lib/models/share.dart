/// 公開分享連結 models。
library;

import 'dart:convert';

import 'day.dart';
import 'notes.dart';

/// 後端允許公開切換的 notes section keys。
const List<String> kShareSectionKeys = [
  'flights',
  'lodgings',
  'reservations',
  'pretrip',
  'emergency',
];

/// 建立新分享連結時的安全預設：預訂與緊急聯絡預設不公開。
const List<String> kDefaultShareSectionKeys = [
  'flights',
  'lodgings',
  'pretrip',
];

/// `GET /trips/:id/shares` 回傳的分享連結 row。
class TripShareLink {
  const TripShareLink({
    required this.id,
    required this.label,
    required this.visibleSections,
    required this.expiresAt,
    required this.viewCount,
    required this.anonymous,
    required this.createdBy,
    required this.createdAt,
    required this.revokedAt,
  });

  factory TripShareLink.fromJson(Map<String, dynamic> json) {
    final visibleSectionsValue =
        json['visibleSections'] ?? json['visible_sections'];
    return TripShareLink(
      id: _int(json['id']),
      label: json['label']?.toString() ?? '',
      visibleSections: visibleSectionsValue is List
          ? jsonEncode(visibleSectionsValue)
          : visibleSectionsValue?.toString() ?? '[]',
      expiresAt: _intOrNull(json['expiresAt'] ?? json['expires_at']),
      viewCount: _int(json['viewCount'] ?? json['view_count']),
      anonymous: _boolInt(json['anonymous']),
      createdBy: (json['createdBy'] ?? json['created_by'])?.toString() ?? '',
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
      revokedAt: (json['revokedAt'] ?? json['revoked_at'])?.toString(),
    );
  }

  final int id;
  final String label;
  final String visibleSections;
  final int? expiresAt;
  final int viewCount;
  final int anonymous;
  final String createdBy;
  final String createdAt;
  final String? revokedAt;

  /// 以後端 allowlist 順序回傳可公開 notes section。
  List<String> get visibleSectionKeys {
    Object? raw;
    try {
      raw = jsonDecode(visibleSections);
    } on FormatException {
      return const [];
    }
    if (raw is! List) return const [];
    return sanitizeShareSectionKeys(raw.map((value) => value.toString()));
  }

  bool get isAnonymous => anonymous == 1;

  bool get isRevoked => revokedAt != null && revokedAt!.trim().isNotEmpty;

  bool get isExpired =>
      expiresAt != null && expiresAt! < DateTime.now().millisecondsSinceEpoch;

  String get displayLabel => label.trim().isEmpty ? '未命名連結' : label.trim();
}

/// `POST /trips/:id/shares` 或 rotate 回傳的一次性 raw token/url。
class CreatedTripShare {
  const CreatedTripShare({
    required this.id,
    required this.token,
    required this.url,
    required this.label,
    required this.visibleSections,
    required this.expiresAt,
    required this.anonymous,
  });

  factory CreatedTripShare.fromJson(Map<String, dynamic> json) {
    return CreatedTripShare(
      id: _int(json['id']),
      token: json['token']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      visibleSections: sanitizeShareSectionKeys(
        (json['visibleSections'] as List<dynamic>? ?? const []).map(
          (value) => value.toString(),
        ),
      ),
      expiresAt: _intOrNull(json['expiresAt']),
      anonymous: _boolInt(json['anonymous']),
    );
  }

  final int id;
  final String token;
  final String url;
  final String label;
  final List<String> visibleSections;
  final int? expiresAt;
  final int anonymous;

  bool get isAnonymous => anonymous == 1;
}

/// `GET /share/:token` 回傳的公開分享 payload。
class PublicTripShare {
  const PublicTripShare({
    required this.name,
    this.title,
    this.countries,
    this.sharedBy = '',
    this.destinations = const [],
    this.days = const [],
    this.notes = const TripNotes(),
  });

  factory PublicTripShare.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map
        ? Map<String, dynamic>.from(json['meta'] as Map)
        : <String, dynamic>{};
    return PublicTripShare(
      name: meta['name']?.toString() ?? '',
      title: _nullableString(meta['title']),
      countries: _nullableString(meta['countries']),
      sharedBy: _nullableString(meta['sharedBy'] ?? meta['shared_by']) ?? '',
      destinations: _destinationNames(meta['destinations']),
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((dayJson) => TripDay.fromJson(dayJson as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] is Map
          ? TripNotes.fromJson(Map<String, dynamic>.from(json['notes'] as Map))
          : const TripNotes(),
    );
  }

  final String name;
  final String? title;
  final String? countries;

  /// Owner display_name；anonymous share 會是空字串。
  final String sharedBy;
  final List<String> destinations;
  final List<TripDay> days;
  final TripNotes notes;

  String get displayTitle {
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      return trimmedTitle;
    }
    final trimmedName = name.trim();
    return trimmedName.isEmpty ? '未命名行程' : trimmedName;
  }

  String get destinationsLabel {
    if (destinations.isNotEmpty) return destinations.join(' · ');
    return countries?.trim() ?? '';
  }

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
}

/// 移除未知 section key 並維持 canonical 順序。
List<String> sanitizeShareSectionKeys(Iterable<String> input) {
  final requested = input.toSet();
  return kShareSectionKeys.where(requested.contains).toList();
}

List<String> _destinationNames(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item['name']?.toString().trim() ?? '')
      .where((name) => name.isNotEmpty)
      .toList();
}

String? _nullableString(Object? value) {
  final stringValue = value?.toString();
  if (stringValue == null || stringValue.trim().isEmpty) return null;
  return stringValue;
}

int _int(Object? value) => (value as num?)?.toInt() ?? 0;

int? _intOrNull(Object? value) => (value as num?)?.toInt();

int _boolInt(Object? value) {
  if (value == true) return 1;
  if (value == false) return 0;
  return (value as num?)?.toInt() ?? 0;
}
