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
    this.origin = NoteMaintainer.human,
    this.managedBy = NoteMaintainer.human,
    this.semanticKey,
  });

  final int id;
  final int sortOrder;
  final int version;
  final String section;
  final String title;

  /// markdown 內容。
  final String content;
  final bool aiGenerated;

  /// 這一列**當初**由誰產生。
  final NoteMaintainer origin;

  /// 這一列**現在**由誰維護。使用者編輯內容後由後端翻成 [NoteMaintainer.human]。
  final NoteMaintainer managedBy;

  /// 後端用來判斷「同一則」的語意鍵;去重與排除靠它。
  final String? semanticKey;

  /// 要不要在列上顯示「AI」標記 —— 看的是**現在誰維護**,不是當初誰產生。
  bool get showsAiBadge => managedBy == NoteMaintainer.ai;

  /// 能不能交還給 AI 維護。只有「原本 AI 產生、目前人工維護」這種可以;
  /// 純人工建立的永遠不行(後端會回 `NOTES_AI_NOT_REASSIGNABLE`)。
  bool get canReassignToAi =>
      origin == NoteMaintainer.ai && managedBy == NoteMaintainer.human;

  factory TripPretripNote.fromJson(Map<String, dynamic> json) {
    return TripPretripNote(
      id: (json['id'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 0,
      section: json['section'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      aiGenerated: json['aiGenerated'] == 1 || json['aiGenerated'] == true,
      origin: parseNoteMaintainer(json['origin']),
      managedBy: parseNoteMaintainer(json['managedBy']),
      semanticKey: json['semanticKey'] as String?,
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
    this.origin = NoteMaintainer.human,
    this.managedBy = NoteMaintainer.human,
    this.semanticKey,
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

  /// 這一列**當初**由誰產生。
  final NoteMaintainer origin;

  /// 這一列**現在**由誰維護。使用者編輯內容後由後端翻成 [NoteMaintainer.human]。
  final NoteMaintainer managedBy;

  /// 後端用來判斷「同一則」的語意鍵;去重與排除靠它。
  final String? semanticKey;

  /// 要不要在列上顯示「AI」標記 —— 看的是**現在誰維護**,不是當初誰產生。
  bool get showsAiBadge => managedBy == NoteMaintainer.ai;

  /// 能不能交還給 AI 維護。只有「原本 AI 產生、目前人工維護」這種可以;
  /// 純人工建立的永遠不行(後端會回 `NOTES_AI_NOT_REASSIGNABLE`)。
  bool get canReassignToAi =>
      origin == NoteMaintainer.ai && managedBy == NoteMaintainer.human;

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
      origin: parseNoteMaintainer(json['origin']),
      managedBy: parseNoteMaintainer(json['managedBy']),
      semanticKey: json['semanticKey'] as String?,
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
/// 一列筆記的來源與目前維護者。
///
/// 後端 migration 0091 對 `trip_pretrip_notes` 與 `trip_emergency_contacts`
/// 各加了 `origin` 與 `managed_by`(皆 NOT NULL DEFAULT `'human'`)。
///
/// **缺漏一律預設 [human]** —— 這是安全側:離線樂觀寫入建立的列不帶這兩個
/// 欄位,誤判成 AI 會讓使用者手寫的內容在下次生成被覆蓋。
enum NoteMaintainer { human, ai }

NoteMaintainer parseNoteMaintainer(Object? raw) =>
    raw == 'ai' ? NoteMaintainer.ai : NoteMaintainer.human;

/// job 狀態。契約以後端 `#1216`/`#1217` 原始碼為準:除了 issue 描述的五種,
/// 實際還會回 `idle`(這種 docType 從沒生成過);`timed_out` 由 server 轉成
/// `timedOut` 才送出。
enum TripNoteAiJobStatus {
  idle,
  pending,
  processing,
  completed,
  failed,
  timedOut,
}

/// 解析 job status;未知字串當成還在跑,不誤判成終止態(比照 `parseRequestStatus`)。
TripNoteAiJobStatus parseTripNoteAiJobStatus(String? raw) => switch (raw) {
  'completed' => TripNoteAiJobStatus.completed,
  'failed' => TripNoteAiJobStatus.failed,
  'timedOut' => TripNoteAiJobStatus.timedOut,
  'processing' => TripNoteAiJobStatus.processing,
  'idle' => TripNoteAiJobStatus.idle,
  _ => TripNoteAiJobStatus.pending,
};

extension TripNoteAiJobStatusX on TripNoteAiJobStatus {
  /// 走到底了沒。`idle` 是「還沒開始」不是「結束」,所以不算終止。
  bool get isTerminal => switch (this) {
    TripNoteAiJobStatus.completed ||
    TripNoteAiJobStatus.failed ||
    TripNoteAiJobStatus.timedOut => true,
    TripNoteAiJobStatus.idle ||
    TripNoteAiJobStatus.pending ||
    TripNoteAiJobStatus.processing => false,
  };

  /// 有沒有一個正在跑的 job 值得接上進度通道。
  bool get isActive =>
      this == TripNoteAiJobStatus.pending ||
      this == TripNoteAiJobStatus.processing;
}

/// `POST /trips/:id/notes/:type/generate` 的回應（啟動一個 AI 生成 job）。
///
/// 契約已凍結（後端 `raychiutw/trip-planner#1216` 已上線）:回應是
/// `jobId`、`requestId`、`status`、`generation`、`timeoutAt`、`tripId`、`docType`
/// —— **沒有 `createdAt`**（上游 issue 的範例有,三個實際回傳點都沒帶）。
///
/// 全部欄位仍給預設值:後端多回或少回欄位時解析不丟例外,契約變動的爆炸半徑
/// 關在這一層,畫面層不碰 json key 也不做型別 cast。
class TripNoteAiJob {
  const TripNoteAiJob({
    this.jobId = 0,
    this.requestId = 0,
    this.status = TripNoteAiJobStatus.pending,
    this.tripId = '',
    this.docType,
    this.generation = 0,
    this.timeoutAt,
    this.startedAt,
    this.completedAt,
    this.errorCode,
    this.errorMessage,
    this.insertedCount = 0,
    this.replacedCount = 0,
    this.preservedManualCount = 0,
    this.duplicateExcludedCount = 0,
    this.suppressedCount = 0,
    this.exclusionCount = 0,
  });

  final int jobId;

  /// 對應 `trip_requests.id`;SSE 進度靠它訂閱。
  final int requestId;
  final TripNoteAiJobStatus status;
  final String tripId;

  /// 後端回的 doc type;未知形解成 `null`（見 [parseNoteGenerationType]）。
  final NoteGenerationType? docType;

  /// job 的世代序號;同一份文件被重新生成時遞增。
  final int generation;

  /// job 的逾時時刻（ISO8601 字串;全專案慣例不轉 DateTime）。
  final String? timeoutAt;
  final String? startedAt;
  final String? completedAt;

  /// 失敗原因;契約拆成 code 與 message 兩欄,不是單一 error 物件。
  final String? errorCode;
  final String? errorMessage;

  /// 完成摘要的五個 count —— 攤平在 job 上,契約沒有 `summary` 那一層。
  final int insertedCount;
  final int replacedCount;
  final int preservedManualCount;
  final int duplicateExcludedCount;
  final int suppressedCount;

  /// 這一種 docType 目前被排除的項目數。
  final int exclusionCount;

  factory TripNoteAiJob.fromJson(Map<String, dynamic> json) => TripNoteAiJob(
    jobId: (json['jobId'] as num?)?.toInt() ?? 0,
    requestId: (json['requestId'] as num?)?.toInt() ?? 0,
    status: parseTripNoteAiJobStatus(json['status'] as String?),
    tripId: json['tripId'] as String? ?? '',
    docType: parseNoteGenerationType(json['docType'] as String?),
    generation: (json['generation'] as num?)?.toInt() ?? 0,
    timeoutAt: json['timeoutAt'] as String?,
    startedAt: json['startedAt'] as String?,
    completedAt: json['completedAt'] as String?,
    errorCode: json['errorCode'] as String?,
    errorMessage: json['errorMessage'] as String?,
    insertedCount: (json['insertedCount'] as num?)?.toInt() ?? 0,
    replacedCount: (json['replacedCount'] as num?)?.toInt() ?? 0,
    preservedManualCount: (json['preservedManualCount'] as num?)?.toInt() ?? 0,
    duplicateExcludedCount:
        (json['duplicateExcludedCount'] as num?)?.toInt() ?? 0,
    suppressedCount: (json['suppressedCount'] as num?)?.toInt() ?? 0,
    exclusionCount: (json['exclusionCount'] as num?)?.toInt() ?? 0,
  );
}

/// `GET /trips/:tripId/notes/ai-state` 的整包回應。
///
/// **契約與 issue 描述有出入,以後端原始碼為準**:回應只有 `jobs` 一個 key、
/// 永遠回三筆(三種 docType 各一,沒生成過也會回一筆 `idle`);五個 count 是
/// 攤平在 job 上的,沒有 `summary` 那一層;錯誤拆成 `errorCode` 與
/// `errorMessage` 兩欄;排除數量是每筆 job 上的 `exclusionCount`,頂層沒有
/// `exclusionCounts` 物件。
class TripNoteAiState {
  const TripNoteAiState({this.jobs = const []});

  final List<TripNoteAiJob> jobs;

  /// 取某一種 docType 的 job;沒有就回 null。
  TripNoteAiJob? jobFor(NoteGenerationType type) {
    for (final job in jobs) {
      if (job.docType == type) return job;
    }
    return null;
  }

  /// 目前有正在跑的 job 的那幾種。
  Iterable<TripNoteAiJob> get activeJobs =>
      jobs.where((job) => job.docType != null && job.status.isActive);

  factory TripNoteAiState.fromJson(Map<String, dynamic> json) =>
      TripNoteAiState(
        jobs: ((json['jobs'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => TripNoteAiJob.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
