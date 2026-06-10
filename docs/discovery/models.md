# trip-planner 資料模型調查報告（for Flutter Dart Models）

## 0. 全域慣例（設計 Dart model 前必讀）

| 項目 | 結論 |
|---|---|
| **JSON key 大小寫** | **API wire format 是 camelCase，不是 snake_case**。`functions/api/_utils.ts` 的 `json()` 經 `deepCamel()` 把 DB snake_case 全部遞迴轉 camelCase 後才回傳。Dart `json_serializable` 應 map camelCase key（例外：OAuth token endpoint 用 `rawJson` 維持 RFC 6749 snake_case，如 `access_token`；POI 搜尋結果 `place_id`/`country_name`/`business_status` 是 snake_case 直出） |
| **id 格式** | `trips.id` = TEXT slug（如 `okinawa-trip-2026-Ray`）；`users.id` = TEXT 32-char hex uuid；其餘（day/entry/poi/segment/notes/permission/favorite）= INTEGER autoincrement |
| **日期時間** | 全部字串、無 epoch，**唯一例外** `trip_segments.computed_at`/`updated_at` 是 INTEGER epoch。`created_at`/`updated_at` = SQLite `datetime('now')` → `"YYYY-MM-DD HH:MM:SS"`（UTC）；`trip_days.date` = `"YYYY-MM-DD"`；entry `startTime`/`endTime` = `"HH:MM"`；flight `departAt`/`arriveAt` = ISO8601 local datetime 字串 |
| **OCC 樂觀鎖** | `trip_days.version`、`trip_entries.version`、`trip_segments.version`、5 個 notes table `version` 皆 INTEGER counter；PATCH 帶 `expectedVersion` 不符回 409 `STALE_*`。`Entry.entryPoisVersion` 在 JSON 中**序列化為 string** |
| **巢狀結構** | Trip **不內嵌** days。`GET /api/trips/:id` → Trip + `destinations[]`；`GET /api/trips/:id/days` → DaySummary[]（輕量）；`GET /api/trips/:id/days/:num` → Day 內嵌 `hotel` + `timeline: Entry[]`；Entry 內嵌 `travel`（由 trip_segments 組裝）、`master`/`alternates`/`stopPois`（由 trip_entry_pois JOIN pois 組裝）、`shopping[]`；`GET /api/trips/:id/notes` → 5 section 聚合 `{flights, lodgings, reservations, pretripNotes, emergencyContacts}` |

來源檔：`src/types/trip.ts`、`src/types/api.ts`、`src/types/timeline.ts`、`src/types/poi.ts`、`functions/api/_types.ts`、`migrations/0073_trip_notes.sql`、`0053_trip_segments.sql`、`0032_users_auth_identities.sql`、`0057_trip_entry_pois.sql`

---

## 1. Trip（`GET /api/trips/:id`）

| JSON key | DB column | 型別 | nullable | 備註 |
|---|---|---|---|---|
| id / tripId | id | String | 否 | slug；API 同時回兩個 key |
| name | name | String | 否 | |
| owner | owner_user_id（JOIN 顯示） | String | 否 | DB 已 cutover 為 owner_user_id FK |
| title | title | String | 是 | |
| description | description | String | 是 | |
| countries | countries | String | 是 | 預設 'JP' |
| published | published | int (0/1) | 是 | **無 trip status enum，只有 published flag** |
| dataSource | data_source | String | 是 | |
| lang | lang | String | 是 | |
| destinations | （JOIN trip_destinations） | List\<TripDestination> | 是 | |
| createdAt / updatedAt | created_at / updated_at | String | 是 | `"YYYY-MM-DD HH:MM:SS"` |

**TripDestination**：`destOrder` int、`name` String、`lat`/`lng` double?、`dayQuota` int?、`subAreas` List\<String>?（JSON-parsed）

**TripListItem**（`GET /api/trips`）：tripId, name, owner, title?, countries?, published, dataSource?, lang? — 無 destinations。

## 2. Day（`GET /api/trips/:id/days/:num`）

| JSON key | DB column (trip_days) | 型別 | nullable | 備註 |
|---|---|---|---|---|
| id | id | int | 否 | |
| dayNum | day_num | int | 否 | |
| date | date | String | 是 | `"YYYY-MM-DD"` |
| dayOfWeek | day_of_week | String | 是 | |
| label | label | String | 是 | |
| title | title | String | 是 | fallback chain: title ‖ label ‖ `Day N` |
| version | version | int | 否 | OCC |
| updatedAt | updated_at | String | 是 | |
| hotel | （hotel_poi_id JOIN pois 合成） | Hotel? | 是 | 每日至多一間 |
| timeline | （JOIN trip_entries） | List\<Entry> | 否 | |

**Hotel**（合成 view，非獨立表）：id int、dayId int?、name String、checkout String?、source?、description?、breakfast `{included: bool?, note: String?}`?、note?、parking `{info?,name?,price?,note?,maps?}`?、location Location?、shopping List\<Shopping>

**Location**：name?、lat double?、lng double?、googleQuery?、appleQuery?、geocodeStatus? — 全 nullable

## 3. Entry（timeline stop，DB `trip_entries`）

| JSON key | DB column | 型別 | nullable | 備註 |
|---|---|---|---|---|
| id | id | int | 否 | |
| dayId | day_id | int | 是 | |
| sortOrder | sort_order | int | 否 | |
| time | （無 col，前端合成） | String | 是 | display fallback |
| startTime / endTime | start_time / end_time | String | 是 | `"HH:MM"` |
| title | title | String | 否 | |
| description | description | String | 是 | |
| source | source | String | 是 | |
| note | （migration 0078 後 = master POI 的 trip_entry_pois.note） | String | 是 | 編輯走 PATCH /entries/:eid/pois/:poiId |
| travel | （由 trip_segments 組裝） | Travel? | 是 | |
| master | （trip_entry_pois sort_order=1 JOIN pois） | EntryPoiInfo? | 是 | |
| alternates | （sort_order≥2） | List\<EntryPoiAlternate> | 是 | |
| stopPois | （全部 rows，首筆=master） | List\<EntryPoiAlternate> | 是 | canonical 清單 |
| entryPoisVersion | entry_pois_version | **String**（JSON）| 是 | OCC token，409 STALE_ENTRY |
| version | version | int | 否 | entry-level OCC |
| updatedAt | updated_at | String | 是 | |
| shopping | （shopping 表 parent_type='entry'） | List\<Shopping> | 否 | |

**EntryPoiInfo**（trip_entry_pois JOIN pois）：poiId int、name?、lat double?、lng double?、type?（= poi_type enum）、category?、hours?、rating double?、price?、reservation?、reservationUrl?、description?、note? — 除 poiId 外全 nullable。**EntryPoiAlternate** = EntryPoiInfo + `sortOrder` int。

**Travel**：type String、desc?、min int?、distanceM int?、source?（'google'/'error'）

**Shopping**：id、parentType（`'hotel'|'entry'`）、parentId、sortOrder、name 必填；category?、hours?、mustBuy?、note?、rating double?、maps?、source? nullable。

## 4. Poi（master 表 `pois`，跨 trip 共用）

| JSON key | DB column | 型別 | nullable |
|---|---|---|---|
| id | id | int | 否 |
| type | type | enum String | 否 |
| name | name | String | 否 |
| description / note / address / phone / email / website / hours | 同名 | String | 是 |
| googleRating | google_rating | double | 是 |
| category / maps | 同名 | String | 是 |
| lat / lng | lat / lng | double | 是 |
| country | country | String | 是（預設 'JP'）|
| source | source | String | 是（預設 'ai'）|
| createdAt / updatedAt | 同名 snake | String | 是 |

**poi_type enum（CHECK constraint）**：`hotel | restaurant | shopping | parking | attraction | transport | activity | other`

**PoiSearchResult**（Google Places，snake_case 直出）：`place_id` String（ChIJ...）、`name`、`address?`、`lat`/`lng` double、`category?`、`country?`（ISO alpha-2）、`country_name?`、`rating?` double、`business_status?` ∈ `OPERATIONAL|CLOSED_TEMPORARILY|CLOSED_PERMANENTLY`

## 5. PoiFavorite（`poi_favorites`，跨 trip 收藏池）

| JSON key | DB column | 型別 | nullable | 備註 |
|---|---|---|---|---|
| id | id | int | 否 | |
| userId | user_id | String | 否 | uuid |
| poiId | poi_id | int | 否 | FK pois |
| favoritedAt | favorited_at | String | 否 | ISO datetime |
| note | note | String | 是 | |
| poiName / poiAddress / poiType | （JOIN pois） | String | 是 | GET 才回 |
| poiLat / poiLng / poiRating | （JOIN pois） | double | 是 | |
| usages | （反查 hotel_poi_id ∪ trip_entry_pois） | List\<PoiFavoriteUsage> | 是 | |

**PoiFavoriteUsage**：tripId String、tripName String、dayNum int?、dayDate String?、entryId int?

## 6. TravelSegment（`trip_segments`）

| JSON key | DB column | 型別 | nullable | enum |
|---|---|---|---|---|
| id | id | int | 否 | |
| tripId | trip_id | String | 否 | |
| fromEntryId / toEntryId | from/to_entry_id | int | 否 | UNIQUE pair |
| mode | mode | String | 否 | `driving | walking | transit`（預設 driving）|
| modeSource | mode_source | String | 否 | `auto | user` |
| min | min | int | 是 | 分鐘 |
| distanceM | distance_m | int | 是 | 公尺 |
| source | source | String | 是 | `google | manual | haversine | error` |
| computedAt / updatedAt | computed_at / updated_at | **int（epoch）** | 是 | 全 schema 唯一 epoch |
| version | version | int | 否 | OCC |

## 7. Notes（5 表，`GET /api/trips/:id/notes` 聚合；皆有 id int、tripId String、sortOrder int、version int、createdAt/updatedAt String；文字欄 `NOT NULL DEFAULT ''` → **非 null、空字串**）

**TripFlight**（`trip_flights`，純手動）：airline、flightNo、cabinClass、departAirport、arriveAirport、departAt（ISO8601 local）、arriveAt、note — 全 String 非 null 預設 ''

**TripLodging**（`trip_lodgings`）：name、address、checkInAt、checkOutAt、bookingNo、phone、note（String 非 null ''）；`dayId` int? **nullable**（link day 被刪 SET NULL）

**TripReservation**（`trip_reservations`）：kind enum `restaurant | experience | ticket | transport | other`（預設 restaurant）、title、reservedAt、partySize int（預設 0）、reservationNo、phone、note

**TripPretripNote**（`trip_pretrip_notes`，AI 可生）：section（如 '貨幣'/'簽證'）、title、content（markdown）、aiGenerated int 0/1、aiSource String? ∈ `lodging-tips | general-tips`（null=manual）

**TripEmergencyContact**（`trip_emergency_contacts`，AI 可生）：name、relationship、phone、email、kind enum `personal | embassy | police | medical | insurance | hotel | other`（預設 other）、aiGenerated int 0/1

## 8. User / Profile（`users`）

| JSON key | DB column | 型別 | nullable | 備註 |
|---|---|---|---|---|
| id | id | String | 否 | 32-char hex uuid（app 層生成）|
| email | email | String | 否 | UNIQUE |
| emailVerifiedAt | email_verified_at | String | 是 | ISO；null=未驗證 |
| displayName | display_name | String | 是 | |
| avatarUrl | avatar_url | String | 是 | |
| status | status | String | 否 | `active | suspended` |
| createdAt / updatedAt | 同名 snake | String | 否 | |

**AuthData**（middleware context）：email String、userId String?（service-token 時 null）、isAdmin bool、isServiceToken bool、scopes List\<String>?、clientId String?

## 9. Permission / Member（`trip_permissions`）

| JSON key | DB column | 型別 | nullable | 備註 |
|---|---|---|---|---|
| id | id | int | 否 | |
| email | email | String | 否 | UNIQUE(email, trip_id) |
| displayName | （LEFT JOIN users.display_name） | String | 是 | |
| tripId | trip_id | String | 否 | `'*'` = 全部 trips |
| role | role | String | 否 | `owner | admin | member | viewer` |

（DB 另有 `user_id` TEXT? FK users）

## 10. Request（旅伴請求，`requests` 表）

id int、tripId String、message String、submittedBy String?（email）、reply String?、status enum `open | received | processing | completed`、createdAt String

## 11. 錯誤格式

API error 回 `{ code, message }`；ErrorCode 重要值：`AUTH_REQUIRED/AUTH_EXPIRED`、`PERM_DENIED`、`DATA_NOT_FOUND`、`STALE_ENTRY`（409 OCC）、`DUPLICATE_POI`、`MAPS_LOCKED`（配額）、`SYS_RATE_LIMIT`、invitation 系列 `INVITATION_*`、auth 流程 `LOGIN_*/SIGNUP_*/RESET_*`。完整清單在 `src/types/api.ts` L13-71。

## Dart 設計建議重點

1. `json_serializable` 不設 `fieldRename: snake`（wire 已是 camelCase）；PoiSearchResult 單獨用 `@JsonKey(name: 'place_id')` 等。
2. `entryPoisVersion` 宣告 String?；segments 的 `computedAt` 宣告 int?（epoch）。
3. Notes 欄位多為非 null 空字串，Dart 可用 `String` + `defaultValue: ''`。
4. enum 建議帶 `unknown` fallback（poi_type 歷經 migration 0079 backfill，防未來值）。
5. Hotel/travel/master/stopPois 都是 server 組裝 view —— Dart model 直接照 JSON 形狀建即可，不需自己 JOIN。