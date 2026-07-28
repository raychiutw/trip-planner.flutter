/// 行程筆記 models（`GET /trips/:id/notes` 5 區聚合）。
/// 5 個 row class 共通欄位：id / sortOrder / version；文字欄位 DB 為
/// `NOT NULL DEFAULT ''`，缺漏時預設空字串。
library;

import 'note_section.dart';

/// 航班（trip_flights）。
class TripFlight {
  const TripFlight({
    required this.id,
    required this.sortOrder,
    required this.version,
    this.airline = '',
    this.flightNo = '',
    this.cabinClass = '',
    this.departAirport = '',
    this.arriveAirport = '',
    this.departAt = '',
    this.arriveAt = '',
    this.note = '',
  });

  final int id;
  final int sortOrder;
  final int version;
  final String airline;
  final String flightNo;
  final String cabinClass;
  final String departAirport;
  final String arriveAirport;

  /// ISO8601 local datetime 字串。
  final String departAt;
  final String arriveAt;
  final String note;

  factory TripFlight.fromJson(Map<String, dynamic> json) {
    return TripFlight(
      id: (json['id'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
      airline: json['airline'] as String? ?? '',
      flightNo: json['flightNo'] as String? ?? '',
      cabinClass: json['cabinClass'] as String? ?? '',
      departAirport: json['departAirport'] as String? ?? '',
      arriveAirport: json['arriveAirport'] as String? ?? '',
      departAt: json['departAt'] as String? ?? '',
      arriveAt: json['arriveAt'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toEditFields() => {
    'airline': airline,
    'flight_no': flightNo,
    'cabin_class': cabinClass,
    'depart_airport': departAirport,
    'arrive_airport': arriveAirport,
    'depart_at': departAt,
    'arrive_at': arriveAt,
    'note': note,
  };
}

/// 住宿（trip_lodgings）；dayId 在 link day 被刪後 SET NULL。
class TripLodging {
  const TripLodging({
    required this.id,
    required this.sortOrder,
    required this.version,
    this.dayId,
    this.name = '',
    this.address = '',
    this.checkInAt = '',
    this.checkOutAt = '',
    this.bookingNo = '',
    this.phone = '',
    this.note = '',
  });

  final int id;
  final int sortOrder;
  final int version;
  final int? dayId;
  final String name;
  final String address;
  final String checkInAt;
  final String checkOutAt;
  final String bookingNo;
  final String phone;
  final String note;

  factory TripLodging.fromJson(Map<String, dynamic> json) {
    return TripLodging(
      id: (json['id'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
      dayId: (json['dayId'] as num?)?.toInt(),
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      checkInAt: json['checkInAt'] as String? ?? '',
      checkOutAt: json['checkOutAt'] as String? ?? '',
      bookingNo: json['bookingNo'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toEditFields() => {
    'name': name,
    'address': address,
    'check_in_at': checkInAt,
    'check_out_at': checkOutAt,
    'booking_no': bookingNo,
    'phone': phone,
    'note': note,
  };
}

/// 預約（trip_reservations）；kind enum 預設 restaurant。
class TripReservation {
  const TripReservation({
    required this.id,
    required this.sortOrder,
    required this.version,
    this.kind = 'restaurant',
    this.title = '',
    this.reservedAt = '',
    this.partySize = 0,
    this.reservationNo = '',
    this.phone = '',
    this.note = '',
  });

  final int id;
  final int sortOrder;
  final int version;

  /// enum：restaurant | experience | ticket | transport | other。
  final String kind;
  final String title;
  final String reservedAt;
  final int partySize;
  final String reservationNo;
  final String phone;
  final String note;

  factory TripReservation.fromJson(Map<String, dynamic> json) {
    return TripReservation(
      id: (json['id'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
      kind: json['kind'] as String? ?? 'restaurant',
      title: json['title'] as String? ?? '',
      reservedAt: json['reservedAt'] as String? ?? '',
      partySize: (json['partySize'] as num?)?.toInt() ?? 0,
      reservationNo: json['reservationNo'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toEditFields() => {
    'kind': kind,
    'title': title,
    'reserved_at': reservedAt,
    'party_size': partySize,
    'reservation_no': reservationNo,
    'phone': phone,
    'note': note,
  };
}

/// 行前筆記（trip_pretrip_notes，AI 可生成）。
class TripPretripNote {
  const TripPretripNote({
    required this.id,
    required this.sortOrder,
    required this.version,
    this.section = '',
    this.title = '',
    this.content = '',
    this.aiGenerated = false,
  });

  final int id;
  final int sortOrder;
  final int version;
  final String section;
  final String title;

  /// markdown 內容。
  final String content;
  final bool aiGenerated;

  factory TripPretripNote.fromJson(Map<String, dynamic> json) {
    return TripPretripNote(
      id: (json['id'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
      section: json['section'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      aiGenerated: json['aiGenerated'] == 1 || json['aiGenerated'] == true,
    );
  }

  Map<String, dynamic> toEditFields() => {
    'section': section,
    'title': title,
    'content': content,
  };
}

/// 緊急聯絡人（trip_emergency_contacts，AI 可生成）；kind enum 預設 other。
class TripEmergencyContact {
  const TripEmergencyContact({
    required this.id,
    required this.sortOrder,
    required this.version,
    this.name = '',
    this.relationship = '',
    this.phone = '',
    this.email = '',
    this.kind = 'other',
    this.aiGenerated = false,
  });

  final int id;
  final int sortOrder;
  final int version;
  final String name;
  final String relationship;
  final String phone;
  final String email;

  /// enum：personal | embassy | police | medical | insurance | hotel | other。
  final String kind;
  final bool aiGenerated;

  factory TripEmergencyContact.fromJson(Map<String, dynamic> json) {
    return TripEmergencyContact(
      id: (json['id'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      kind: json['kind'] as String? ?? 'other',
      aiGenerated: json['aiGenerated'] == 1 || json['aiGenerated'] == true,
    );
  }

  Map<String, dynamic> toEditFields() => {
    'name': name,
    'relationship': relationship,
    'phone': phone,
    'email': email,
    'kind': kind,
  };
}

/// `GET /trips/:id/notes` 回應的 5 區聚合。
class TripNotes {
  const TripNotes({
    this.flights = const [],
    this.lodgings = const [],
    this.reservations = const [],
    this.pretripNotes = const [],
    this.emergencyContacts = const [],
  });

  final List<TripFlight> flights;
  final List<TripLodging> lodgings;
  final List<TripReservation> reservations;
  final List<TripPretripNote> pretripNotes;
  final List<TripEmergencyContact> emergencyContacts;

  factory TripNotes.fromJson(Map<String, dynamic> json) {
    return TripNotes(
      flights: (json['flights'] as List<dynamic>? ?? [])
          .map(
            (flightJson) =>
                TripFlight.fromJson(flightJson as Map<String, dynamic>),
          )
          .toList(),
      lodgings: (json['lodgings'] as List<dynamic>? ?? [])
          .map(
            (lodgingJson) =>
                TripLodging.fromJson(lodgingJson as Map<String, dynamic>),
          )
          .toList(),
      reservations: (json['reservations'] as List<dynamic>? ?? [])
          .map(
            (reservationJson) => TripReservation.fromJson(
              reservationJson as Map<String, dynamic>,
            ),
          )
          .toList(),
      pretripNotes: (json['pretripNotes'] as List<dynamic>? ?? [])
          .map(
            (pretripNoteJson) => TripPretripNote.fromJson(
              pretripNoteJson as Map<String, dynamic>,
            ),
          )
          .toList(),
      emergencyContacts: (json['emergencyContacts'] as List<dynamic>? ?? [])
          .map(
            (contactJson) => TripEmergencyContact.fromJson(
              contactJson as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// AI 生成 job 的狀態。
enum TripNoteAiJobStatus { pending, processing, completed, failed }

/// 解析 job status;未知字串當成還在跑,不誤判成終止態(比照 `parseRequestStatus`)。
TripNoteAiJobStatus parseTripNoteAiJobStatus(String? raw) => switch (raw) {
  'completed' => TripNoteAiJobStatus.completed,
  'failed' => TripNoteAiJobStatus.failed,
  'processing' => TripNoteAiJobStatus.processing,
  _ => TripNoteAiJobStatus.pending,
};

extension TripNoteAiJobStatusX on TripNoteAiJobStatus {
  /// 只有 completed / failed 是終止態。
  bool get isTerminal =>
      this == TripNoteAiJobStatus.completed ||
      this == TripNoteAiJobStatus.failed;
}

/// `POST /trips/:id/notes/:type/generate` 的回應（啟動一個 AI 生成 job）。
///
/// 全部欄位都給預設值:後端多回或少回欄位時解析不丟例外,契約變動的爆炸半徑
/// 關在這一層,畫面層不碰 json key 也不做型別 cast。
class TripNoteAiJob {
  const TripNoteAiJob({
    this.jobId = 0,
    this.requestId = 0,
    this.status = TripNoteAiJobStatus.pending,
    this.tripId = '',
    this.docType,
    this.generation = 0,
    this.createdAt,
    this.timeoutAt,
  });

  final int jobId;

  /// 對應 `trip_requests.id`;SSE 進度靠它訂閱。
  final int requestId;
  final TripNoteAiJobStatus status;
  final String tripId;

  /// 後端回的 doc type;值域未凍結,未知形解成 `null`（見 [parseNoteGenerationType]）。
  final NoteGenerationType? docType;

  /// job 的世代序號;同一份文件被重新生成時遞增。
  final int generation;

  /// ISO8601 字串;全專案慣例不轉 DateTime。
  final String? createdAt;

  /// job 的逾時時刻（ISO8601 字串）。
  final String? timeoutAt;

  factory TripNoteAiJob.fromJson(Map<String, dynamic> json) => TripNoteAiJob(
    jobId: (json['jobId'] as num?)?.toInt() ?? 0,
    requestId: (json['requestId'] as num?)?.toInt() ?? 0,
    status: parseTripNoteAiJobStatus(json['status'] as String?),
    tripId: json['tripId'] as String? ?? '',
    docType: parseNoteGenerationType(json['docType'] as String?),
    generation: (json['generation'] as num?)?.toInt() ?? 0,
    createdAt: json['createdAt'] as String?,
    timeoutAt: json['timeoutAt'] as String?,
  );
}
