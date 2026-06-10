# Models 參考(`lib/models/`)

所有 model 都是手寫的 immutable Dart class:`const` 建構子 + named 參數 + `factory fromJson(Map<String, dynamic>)`,不用 build_runner(理由見[架構說明](explanation-architecture.md#為什麼手寫-fromjson))。

> 欄位來源是 trip-planner web 後端,原始調查報告在 [`discovery/models.md`](discovery/models.md)。本文件以 `lib/models/` 實際程式碼為準。

## 通用解析規則

所有 `fromJson` 一律遵守(每條都有 model 測試覆蓋,見 `test/models/`):

| 規則 | 寫法 |
|---|---|
| wire format 是 **camelCase**(server `deepCamel()` 已轉) | 直接讀 camelCase key,不做 snake_case 轉換 |
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
| `totalDays` | `int?` | |

顯示名稱用 `trip_card.dart` 的 extension:`displayTitle` = `title`(trim 後非空)→ 否則 `name`。

### TripDestination — 行程目的地(trip_destinations JOIN)

`destOrder: int?`、`name: String`(必填)、`lat: double?`、`lng: double?`。

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

### TripDay — `GET /trips/:id/days?all=1` item

| 欄位 | 型別 | 備註 |
|---|---|---|
| `id`、`dayNum` | `int` | 必填 |
| `date` | `String?` | `"YYYY-MM-DD"` |
| `dayOfWeek`、`label`、`title` | `String?` | |
| `version` | `int` | OCC 版本號,缺漏 → 0 |
| `hotel` | `DayHotel?` | |
| `timeline` | `List<TimelineEntry>` | 預設 `[]` |

getter `displayTitle`:`title ?? label ?? 'Day $dayNum'`。

## entry.dart

### Travel — 移動段(server 由 trip_segments 組裝)

| 欄位 | 型別 | 備註 |
|---|---|---|
| `type` | `String` | 必填(walk/drive/transit…) |
| `desc`、`source` | `String?` | |
| `min` | `int?` | 分鐘 |
| `distanceM` | `int?` | 公尺 |

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
| `description`、`note` | `String?` | |
| `version` | `int` | OCC,缺漏 → 0 |
| `travel` | `Travel?` | 到達此 entry 的移動段 |
| `master` | `EntryPoiInfo?` | 主 POI |
| `alternates` | `List<EntryPoiInfo>` | 備選 POI,預設 `[]` |

## notes.dart

`GET /trips/:id/notes` 回應的 5 區聚合。5 個 row class 共通欄位:`id: int`、`sortOrder: int`、`version: int`;文字欄位 DB 為 `NOT NULL DEFAULT ''`,缺漏一律預設 `''`(非 null)。

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
