# Models 參考(`lib/models/`)

所有 model 都是手寫的 immutable Dart class:`const` 建構子 + named 參數 + `factory fromJson(Map<String, dynamic>)`,不用 build_runner(理由見[架構說明](explanation-architecture.md#為什麼手寫-fromjson))。

> 欄位來源是 trip-planner web 後端,原始調查報告在 [`discovery/models.md`](discovery/models.md)。本文件以 `lib/models/` 實際程式碼為準。

## 通用解析規則

所有 `fromJson` 一律遵守(每條都有 model 測試覆蓋,見 `test/models/`):

| 規則 | 寫法 |
|---|---|
| wire format 多數是 **camelCase**(server `deepCamel()` 已轉) | 直接讀 camelCase key；少數 endpoint 仍回 snake_case 時在該 model 明確相容 |
| 數字可能是 int 或 double | `(json['x'] as num?)?.toDouble()` / `?.toInt()` |
| bool flag server 回 `0`/`1` 或 `true`/`false` | `json['published'] == 1 \|\| json['published'] == true` |
| 日期時間全是**字串**,不存 DateTime | 顯示層需要時再 parse;entry 的 `startTime`/`endTime` 是 `"HH:MM"`、day 的 `date` 是 `"YYYY-MM-DD"` |
| list 欄位缺漏 → 空 list | `(json['xs'] as List<dynamic>? ?? []).map(...).toList()` |
| `sortOrder`/`version` 缺漏 → `0` | `(json['sortOrder'] as num?)?.toInt() ?? 0` |

## trip.dart

### TripSummary — `GET /my-trips` 清單項目

| 欄位 | 型別 | 備註 |
|---|---|---|
| `tripId` | `String` | 必填 |
| `name` | `String` | 必填(機器名) |
| `title` | `String?` | 人類可讀標題 |
| `owner`、`ownerDisplayName`、`ownerUserId` | `String?` | owner email / 顯示名稱 / user id |
| `role` | `String?` | `owner` / `member` / `viewer`;TripsList 分類 tabs 以此區分我的/共編 |
| `countries` | `String?` | 搜尋 haystack 會納入國家字串 |
| `startDate`、`endDate` | `String?` | `"YYYY-MM-DD"`；排序「出發日近」使用 `startDate` 升冪 |
| `updatedAt` | `String?` | API 預設順序視為「最新編輯」順序 |
| `totalDays` | `int?` | |
| `memberCount` | `int?` | 成員數 |
| `archivedAt` | `String?` | 非空表示已歸檔；TripsList「全部/我的/共編」會排除 archived |

顯示名稱用 `trip_card.dart` 的 extension:`displayTitle` = `title`(trim 後非空)→ 否則 `name`。

### TripDestination — 行程目的地(trip_destinations JOIN)

`destOrder: int?`、`name: String`(必填)、`lat: double?`、`lng: double?`、`dayQuota: int?`、`subAreas: List<String>`。

### TripDestinationInput — 建立/編輯行程 destinations payload

`POST /trips` 與 `PUT /trips/:id` 使用。Dart 欄位為 `name`、`lat`、`lng`、`dayQuota`、`subAreas`;送出時轉成後端欄位 `name`、`lat`、`lng`、`day_quota`、`sub_areas`。空白 `name` 會在 repository payload 過濾掉。

### Trip — `GET /trips`(list item)與 `GET /trips/:id`(detail)共用

兩個 endpoint 欄位密度不同,所以除 `id`/`name` 外全部 nullable(寬鬆解析)。

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id` | `String` | **來源 `json['tripId'] ?? json['id']`**(API 同時存在兩種 key) |
| `name` | `String` | 必填 |
| `owner`、`ownerDisplayName`、`title`、`description`、`countries`、`lang` | `String?` | |
| `published` | `bool` | 0/1 bool,預設 `false` |
| `dayCount`、`memberCount` | `int?` | |
| `startDate`、`endDate` | `String?` | `"YYYY-MM-DD"` |
| `destinations` | `List<TripDestination>` | 預設 `[]` |

## chat.dart

### TripRequest — `GET /requests` / `POST /requests` / `GET /requests/:id`

AI request queue row。wire format 是 server `deepCamel()` 後的 camelCase；日期時間仍保留字串。

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id` | `int` | request row id |
| `tripId` | `String` | 所屬行程 |
| `message` | `String` | 使用者送出的訊息；缺漏預設 `''` |
| `reply` | `String?` | AI 回覆；空白時 `displayReply` 回 `null` |
| `status` | `String` | 預設 `open`;常見值 `open` / `processing` / `completed` / `failed` |
| `submittedBy`、`submittedByDisplayName`、`processedBy` | `String?` | 使用者/處理者資訊 |
| `createdAt`、`updatedAt` | `String?` | ISO datetime 字串 |

helper：`isInflight` = `open` 或 `processing`；`isCompleted` = `completed`；`isFailed` = `failed`；`displayReply` 會 trim 空白。

### TripRequestPage — `GET /requests` paginated response

`items: List<TripRequest>`、`hasMore: bool`。repository 也相容 legacy array response,會包成 `TripRequestPage(hasMore: false)`。

## health.dart

### TripHealthReport — `GET/POST /trips/:id/health-check`

AI 行程健檢最新報告。GET 回 wrapper `{report}`，其中 `report` 可為 `null`；POST 正常回 pending report。wire format 是 camelCase，日期時間仍保留字串。

| 欄位 | 型別 | 備註 |
|---|---|---|
| `tripId` | `String` | 所屬行程 |
| `userId` | `String` | 觸發健檢的使用者 id |
| `status` | `String` | `pending` / `completed` / `failed` |
| `requestId` | `int?` | 對應 `trip_requests.id` |
| `findings` | `List<TripHealthFinding>` | 缺漏 → `[]` |
| `errorMessage` | `String?` | failed 狀態顯示用 |
| `createdAt` | `String` | datetime 字串；缺漏時預設 `''` |
| `completedAt` | `String?` | datetime 字串 |

helper：`isPending`、`isCompleted`、`isFailed`、`severityCount(severity)`、`findingsForSeverity(severity)`。

### TripHealthFinding / TripHealthActionTarget

`TripHealthFinding` 欄位：`severity: String`（high/medium/low）、`title: String`、`description: String`、`dimension: String?`（timing/distance/meals/sights/hotel）、`suggestion: String?`、`actionTarget: TripHealthActionTarget?`。helper `severityLabel`、`severityHeading`、`dimensionLabel` 回 zh-TW 顯示文案。

`TripHealthActionTarget` 欄位：`day: int?`、`entryId: int?`。parser 同時相容 camelCase `entryId` 與舊 snake_case `entry_id`。

## collab.dart

### TripPermission — `GET /permissions?tripId=...`

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id` | `int` | permission row id |
| `email` | `String` | 成員 email；缺漏預設 `''` |
| `displayName` | `String?` | 使用者顯示名稱 |
| `tripId` | `String` | 所屬行程 |
| `role` | `String` | `owner` / `member` / `viewer`，缺漏預設 `viewer` |
| `userId` | `String?` | 後端 join 使用者 id |

helper：`isOwner`、`isViewer`、`roleLabel`（擁有者/共編成員/檢視者）、`displayLabel`（displayName 非空優先,否則 email）。

### PermissionInviteResult — `POST /permissions`

`ok: bool`、`status: String`、`email: String`、`id: int?`、`expiresAt: String?`。後端為防止 email enumeration,既有使用者與新邀請都可能回 `status: invitation_sent`。

### PermissionRoleUpdateResult — `PATCH /permissions/:id`

`ok: bool`、`role: String?`、`unchanged: bool`。role update 只允許 `member` / `viewer`;若送同一個角色,後端可回 `{ok:true, unchanged:true}` 且不寫 audit log。

### PendingInvitation / PendingInvitationPage — `GET /invitations?tripId=...`

`PendingInvitation` 欄位：`id: String`（token hash）、`invitedEmail: String`、`createdAt: String?`、`expiresAt: String?`、`daysRemaining: int?`、`isExpired: bool`。helper `statusLabel` 會顯示「已過期」「待接受」或「剩 N 天」。

`PendingInvitationPage` 目前只有 `items: List<PendingInvitation>`。

### InvitationPreview — `GET /invitations?token=...`

公開邀請預覽（不需登入）：`tripId: String`、`tripTitle: String`、`invitedEmail: String`、`inviterDisplayName: String?`、`inviterEmail: String`、`expiresAt: String`。helper `inviterLabel` 以 displayName 非空優先,否則 inviter email。

### InvitationAcceptResult — `POST /invitations/accept`

`ok: bool`、`tripId: String`、`tripTitle: String`。成功後 `InviteScreen` 導向 `/trips/:tripId`。

## day.dart

### TripLocation — 座標(server 合成,全 nullable)

`name: String?`、`lat: double?`、`lng: double?`。

### DayHotel — 當日飯店(每日至多一間)

| 欄位 | 型別 |
|---|---|
| `id` | `int`(必填) |
| `name` | `String`(必填) |
| `checkout`、`note` | `String?` |
| `location` | `TripLocation?` |

### TripDay — `GET /trips/:id/days?all=1` item / `POST /trips/:id/days` 回傳 day

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id`、`dayNum` | `int` | 必填；`dayNum` 同時相容 `day_num` |
| `date` | `String?` | `"YYYY-MM-DD"` |
| `dayOfWeek`、`label`、`title` | `String?` | `dayOfWeek` 同時相容 `day_of_week` |
| `version` | `int` | OCC 版本號,缺漏 → 0 |
| `hotel` | `DayHotel?` | |
| `timeline` | `List<TimelineEntry>` | 預設 `[]` |

getter `displayTitle`:`title ?? label ?? 'Day $dayNum'`。

### TripDayDeleteResult / TripDaysShiftResult — day management mutation result

`TripDayDeleteResult` 對應 `DELETE /trips/:id/days/:num`:`ok: bool`、`removedEntryCount: int`。`removedEntryCount` 是後端實際 cascade 刪掉的 entry 數量。

`TripDaysShiftResult` 對應 `POST /trips/:id/days/shift`:`ok: bool`、`newStartDate: String`、`newEndDate: String?`、`daysShifted: int`。日期仍以 `"YYYY-MM-DD"` 字串保存。

## entry.dart

### Travel — 移動段(server 由 trip_segments 組裝)

| 欄位 | 型別 | 備註 |
|---|---|---|
| `type` | `String` | 必填(walk/drive/transit…) |
| `desc`、`source` | `String?` | |
| `min` | `int?` | 分鐘 |
| `distanceM` | `int?` | 公尺 |

### TripSegment — `GET /trips/:id/segments`

`trip_segments` source of truth。後端目前回 snake_case row,model 同時相容 camelCase 以便未來 `deepCamel()` 後不需再改 UI。`TripTimelineScreen` 以 from/to entry pair 對應 timeline entry 之間的 travel pill。

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id` | `int` | segment row id |
| `tripId` | `String` | 來源 `trip_id` / `tripId` |
| `fromEntryId`、`toEntryId` | `int` | 來源 `from_entry_id` / `to_entry_id` |
| `mode` | `String` | `driving` / `walking` / `transit` |
| `min` | `int?` | 分鐘；driving/walking 重算失敗時可保留舊值 |
| `distanceM` | `int?` | 公尺；transit 為 null |
| `source` | `String?` | `google` / `manual` |
| `computedAt`、`updatedAt` | `int?` | epoch milliseconds；`computedAt == null` 表示 stale |
| `version` | `int` | PATCH `/segments/:sid` 的 OCC token |

helper：`isStale`、`toTravel()`。`toTravel()` 會把 `mode/min/distanceM/source` 轉成 timeline pill 顯示用的 `Travel`。

### EntryPoiInfo — entry 掛載的 POI(trip_entry_pois JOIN pois)

除 `poiId: int` 外全 nullable:`name`、`lat: double?`、`lng: double?`、`type`(poi_type enum 字串:`hotel`/`restaurant`/`shopping`/`parking`/`attraction`/`transport`/`activity`/`other`)、`category`、`hours`、`rating: double?`、`price`、`note`、`sortOrder: int?`。

`type` 決定 UI 三色 tone,對照表見 [Theme 參考](reference-theme.md#poi-type--tone-對照)。

### TimelineEntry — 時間軸停留點(trip_entries)

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id` | `int` | 必填 |
| `dayId` | `int?` | |
| `sortOrder` | `int` | 缺漏 → 0 |
| `time`、`startTime`、`endTime` | `String?` | `startTime`/`endTime` 是 `"HH:MM"` |
| `title` | `String` | 必填 |
| `description`、`note`、`source` | `String?` | |
| `version` | `int` | OCC,缺漏 → 0 |
| `entryPoisVersion` | `String?` | entry POI 關聯的 OCC token |
| `travel` | `Travel?` | 到達此 entry 的移動段 |
| `master` | `EntryPoiInfo?` | 主 POI |
| `alternates` | `List<EntryPoiInfo>` | 備選 POI,預設 `[]` |

### EntryPoisMutationResult — `trip_entry_pois` 變更結果

`POST /trips/:id/entries/:entryId/alternates` 與 `DELETE /trips/:id/entries/:entryId/alternates/:poiId` 回傳的 POI 關聯變更結果:`entryId: int`、`poiId: int`、`sortOrder: int?`、`entryPoisVersion: String?`。`entryPoisVersion` 是下一次 POI 變更要帶的 OCC token。

### EntryAlternatesReorderResult — 備選排序結果

`PATCH /trips/:id/entries/:entryId/alternates/reorder` 回傳:`entryId: int`、`order: List<int>`、`entryPoisVersion: String?`。`order` 是不含 master 的 alternate `poiId` 新順序。

## poi.dart

### PoiFavoriteUsage — 收藏出現在哪些行程

`tripId: String`、`tripName: String`、`dayNum: int?`、`dayDate: String?`、`entryId: int?`。

### PoiFavorite — `GET /poi-favorites`

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id` | `int` | 收藏 row id |
| `userId` | `String` | owner user id |
| `poiId` | `int` | pois table id |
| `favoritedAt` | `String` | ISO datetime 字串 |
| `note` | `String?` | 收藏備註 |
| `poiName`、`poiAddress`、`poiType` | `String?` | JOIN pois 欄位 |
| `poiLat`、`poiLng`、`poiRating` | `double?` | 數字走 `num?.toDouble()` |
| `usages` | `List<PoiFavoriteUsage>` | 缺漏 → `[]` |

getter `displayName`: `poiName` trim 後非空 → 否則 `POI #$poiId`。

### PoiSearchResult — `GET /poi-search`

此 endpoint 是少數仍回 snake_case 的 wire shape:`place_id`、`country_name`、`business_status`。Dart 欄位為 `placeId`、`countryName`、`businessStatus`。

必填欄位:`placeId`、`name`、`lat`、`lng`;選填欄位:`address`、`category`、`country`、`countryName`、`rating`、`businessStatus`。

### PoiFavoriteAddToTripResult — `POST /poi-favorites/:id/add-to-trip`

`ok: bool`、`entryId: int`、`dayId: int`、`sortOrder: int`、`startTime: String`、`endTime: String`、`note: String?`。

helper `mapPoiCategoryToType` 會把 Google primaryType / 既有 `poiType` 映射到後端白名單:`hotel`、`restaurant`、`shopping`、`parking`、`attraction`、`transport`、`activity`、`other`。`poiTypeLabel` 回 zh-TW 類型文案。

## notes.dart

`GET /trips/:id/notes` 回應的 5 區聚合。5 個 row class 共通欄位:`id: int`、`sortOrder: int`、`version: int`;文字欄位 DB 為 `NOT NULL DEFAULT ''`,缺漏一律預設 `''`(非 null)。

`TripNoteSection` 對應 row mutation path segment:`flights`、`lodgings`、`reservations`、`pretrip`、`emergency`;repository 的 `deleteTripNoteRow` 使用此 enum 避免手寫 path 字串。

| Class | 專屬欄位 |
|---|---|
| `TripFlight`(航班) | `airline`、`flightNo`、`cabinClass`、`departAirport`、`arriveAirport`、`departAt`、`arriveAt`(ISO8601 local datetime 字串)、`note` |
| `TripLodging`(住宿) | `dayId: int?`(link day 被刪後 SET NULL)、`name`、`address`、`checkInAt`、`checkOutAt`、`bookingNo`、`phone`、`note` |
| `TripReservation`(預約) | `kind`(enum:`restaurant`/`experience`/`ticket`/`transport`/`other`,預設 `restaurant`)、`title`、`reservedAt`、`partySize: int`(預設 0)、`reservationNo`、`phone`、`note` |
| `TripPretripNote`(行前筆記) | `section`、`title`、`content`(markdown)、`aiGenerated: bool`(0/1 bool) |
| `TripEmergencyContact`(緊急聯絡人) | `name`、`relationship`、`phone`、`email`、`kind`(enum:`personal`/`embassy`/`police`/`medical`/`insurance`/`hotel`/`other`,預設 `other`)、`aiGenerated: bool` |

```dart
class TripNotes {
  final List<TripFlight> flights;
  final List<TripLodging> lodgings;
  final List<TripReservation> reservations;
  final List<TripPretripNote> pretripNotes;
  final List<TripEmergencyContact> emergencyContacts;
}
```

### TripNoteAiGenerationJob — `POST /trips/:id/notes/:docType/generate`

`jobId: int`、`requestId: int`、`status: String`、`tripId: String`、`docType: String`。`TripNotesScreen` 會用 `requestId` polling `GET /requests/:id`;完成後重新整理 `tripNotesProvider`。

## auth.dart

### SignupResult — `POST /oauth/signup`

註冊成功回應：`ok: bool`、`userId: String`、`email: String`、`requiresVerification: bool`、`joinedTrip: SignupJoinedTrip?`、`invitationError: String?`。`joinedTrip` 只有 signup body 帶 `invitationToken` 且後端接受邀請成功時才會存在。

### SignupJoinedTrip

`id: String`、`title: String`。Signup 成功且直接加入共編行程時,`SignupScreen` 會導向 `/trips/:id`。

### AuthMessageResult

`POST /oauth/forgot-password`、`POST /oauth/reset-password`、`POST /oauth/send-verification` 共用 `{ok, message}` shape:`ok: bool`、`message: String`。

## user.dart

### UserInfo — `GET /oauth/userinfo` 回應

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id` | `String` | 32-char hex uuid |
| `email` | `String` | 必填 |
| `emailVerified` | `bool` | 0/1 bool,預設 `false` |
| `displayName`、`avatarUrl`、`createdAt` | `String?` | |

### AccountStats — `GET /account/stats` 回應(帳號頁 hero 3 統計)

`tripCount: int`、`totalDays: int`、`collaboratorCount: int` — 全部缺漏預設 `0`。

## 相關文件

- [API 層參考](reference-api.md) — 哪個 repository 方法回哪個 model
- [How to 新增 API endpoint](howto-add-endpoint.md) — 新增 model + fromJson 測試的步驟
- [`discovery/models.md`](discovery/models.md) — 來源 SPA 的欄位調查報告
