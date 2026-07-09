/// Trip document models (`trip_docs`).
library;

enum TripDocType { flights, checklist, backup, suggestions, emergency }

String tripDocTypeKey(TripDocType type) => type.name;

TripDocType parseTripDocType(String value) => switch (value) {
  'flights' => TripDocType.flights,
  'checklist' => TripDocType.checklist,
  'backup' => TripDocType.backup,
  'suggestions' => TripDocType.suggestions,
  'emergency' => TripDocType.emergency,
  _ => throw FormatException('Unknown trip doc type: $value'),
};

class TripDocEntry {
  const TripDocEntry({
    this.id,
    required this.sortOrder,
    required this.section,
    required this.title,
    required this.content,
  });

  final int? id;
  final int sortOrder;
  final String section;
  final String title;
  final String content;

  factory TripDocEntry.fromJson(Map<String, dynamic> json) => TripDocEntry(
    id: (json['id'] as num?)?.toInt(),
    sortOrder:
        (json['sortOrder'] as num?)?.toInt() ??
        (json['sort_order'] as num?)?.toInt() ??
        0,
    section: json['section'] as String? ?? '',
    title: json['title'] as String? ?? '',
    content: json['content'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'sort_order': sortOrder,
    'section': section,
    'title': title,
    'content': content,
  };
}

class TripDoc {
  const TripDoc({
    required this.type,
    required this.title,
    required this.entries,
    this.updatedAt,
  });

  final TripDocType type;
  final String title;
  final List<TripDocEntry> entries;
  final String? updatedAt;

  factory TripDoc.fromJson(Map<String, dynamic> json) => TripDoc(
    type: parseTripDocType(json['doc_type'] as String? ?? ''),
    title: json['title'] as String? ?? '',
    updatedAt: json['updated_at'] as String?,
    entries: (json['entries'] as List<dynamic>? ?? [])
        .map((entry) => TripDocEntry.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );
}

class TripDocs {
  const TripDocs({required this.docs});

  final Map<TripDocType, TripDoc?> docs;

  TripDoc? operator [](TripDocType type) => docs[type];

  factory TripDocs.fromJson(Map<String, dynamic> json) {
    final rawDocs = json['docs'] as Map<String, dynamic>? ?? const {};
    return TripDocs(
      docs: {
        for (final type in TripDocType.values)
          type: rawDocs[tripDocTypeKey(type)] == null
              ? null
              : TripDoc.fromJson(
                  rawDocs[tripDocTypeKey(type)] as Map<String, dynamic>,
                ),
      },
    );
  }
}
