# 模組契約（跨 agent 實作介面，嚴格遵守）

> **狀態：P0 已實作完成，本檔為歷史契約。** 個別欄位以 `lib/` 程式碼與 [reference-models.md](reference-models.md)／[reference-api.md](reference-api.md) 為準。
> 已知與實作的偏差：`UserInfo` 多 `createdAt` 欄位、`AccountStats` 實際為 `tripCount`/`totalDays`/`collaboratorCount`、`sortOrder`/`version` 缺漏時預設 `0`。

> 所有平行實作的 agent 必須照此檔的檔案路徑、class 名、方法簽章實作。
> 若實作中發現契約有誤（如 API 欄位不符），以 `docs/discovery/*.md` 與 web repo 原始碼為準，並在最終回報中註明偏差。

## 通用解析規則

- wire format 是 **camelCase**（server `deepCamel()`）；`fromJson` 直接讀 camelCase key
- 數字一律 `(json['x'] as num?)?.toDouble()` / `?.toInt()`（server 可能回 int 或 double）
- bool flag（如 `published`）server 回 0/1：`json['published'] == 1 || json['published'] == true`
- 日期時間全是字串，不轉 DateTime 存放（顯示層再 parse）；entry `startTime`/`endTime` = `"HH:MM"`
- 所有 model：`const` 建構子 + named 參數 + `factory X.fromJson(Map<String, dynamic> json)`；list 欄位預設 `[]`

## lib/theme/

```dart
// tokens.dart — design token 常數（值來自 docs/discovery/design.md 的 tokens 表）
abstract final class TpColorsLight { static const background = Color(0xFFFFFBF5); /* accent, accentDeep, accentSubtle, accentBg, sage 4 階, pink 4 階, secondary, tertiary, hover, foreground, muted, accentForeground, border, lineStrong, destructive, destructiveBg, success, warning, disabled, overlay … */ }
abstract final class TpColorsDark { /* 同名 dark 值 */ }
abstract final class TpRadius { static const xs = 4.0; sm = 6.0; md = 8.0; lg = 12.0; xl = 16.0; }
abstract final class TpSpacing { /* 4px grid: s1=4 … s10=40; tapMin=44.0; navHeight=88.0 */ }
abstract final class TpMotion { static const fast = Duration(milliseconds: 150); normal = 250ms; slow = 350ms; static const appleEase = Cubic(0.2, 0.8, 0.2, 1); }

// app_theme.dart
class TpTones extends ThemeExtension<TpTones> { /* accent/sage/pink 各 4 階（base deep subtle bg）+ success warning */ }
abstract final class AppTheme {
  static ThemeData light();
  static ThemeData dark();
}
```

## lib/models/（檔案：trip.dart, day.dart, entry.dart, chat.dart, collab.dart, notes.dart, user.dart）

```dart
// trip.dart
class TripSummary { final String tripId; final String name; final String? title; final int? totalDays; }       // GET /my-trips
class TripDestination { final int? destOrder; final String name; final double? lat; final double? lng; final int? dayQuota; final List<String> subAreas; }
class TripDestinationInput { final String name; final double? lat; final double? lng; final int? dayQuota; final List<String> subAreas; Map<String, dynamic> toJson(); }
class Trip {            // GET /trips (list item) 與 GET /trips/:id（detail）共用，寬鬆 nullable
  final String id;      // 來源 json['tripId'] ?? json['id']
  final String name; final String? owner; final String? ownerDisplayName; final String? title;
  final String? description; final String? countries; final bool published; final String? lang;
  final int? dayCount; final String? startDate; final String? endDate; final int? memberCount;
  final List<TripDestination> destinations;
}

// day.dart
class TripLocation { final String? name; final double? lat; final double? lng; }
class DayHotel { final int id; final String name; final String? checkout; final String? note; final TripLocation? location; }
class TripDay {         // GET /trips/:id/days?all=1 item
  final int id; final int dayNum; final String? date; final String? dayOfWeek; final String? label;
  final String? title; final int version; final DayHotel? hotel; final List<TimelineEntry> timeline;
  String get displayTitle; // title ?? label ?? 'Day $dayNum'
}

// entry.dart
class Travel { final String type; final String? desc; final int? min; final int? distanceM; final String? source; }
class EntryPoiInfo {
  final int poiId; final String? name; final double? lat; final double? lng; final String? type; // poi_type enum 字串
  final String? category; final String? hours; final double? rating; final String? price; final String? note; final int? sortOrder;
}
class TimelineEntry {
  final int id; final int? dayId; final int sortOrder; final String? time; final String? startTime; final String? endTime;
  final String title; final String? description; final String? note; final String? source; final int version; final String? entryPoisVersion;
  final Travel? travel; final EntryPoiInfo? master; final List<EntryPoiInfo> alternates;
}
class EntryPoisMutationResult { final int entryId; final int poiId; final int? sortOrder; final String? entryPoisVersion; }
class EntryAlternatesReorderResult { final int entryId; final List<int> order; final String? entryPoisVersion; }

// chat.dart
class TripRequest {
  final int id; final String tripId; final String message; final String? reply; final String status;
  final String? submittedBy; final String? submittedByDisplayName; final String? processedBy;
  final String? createdAt; final String? updatedAt;
  bool get isInflight; bool get isCompleted; bool get isFailed; String? get displayReply;
}
class TripRequestPage { final List<TripRequest> items; final bool hasMore; }

// collab.dart
class TripPermission {
  final int id; final String email; final String tripId; final String role;
  final String? displayName; final String? userId;
  bool get isOwner; bool get isViewer; String get roleLabel; String get displayLabel;
}
class PermissionInviteResult { final bool ok; final String status; final String email; final int? id; final String? expiresAt; }
class PermissionRoleUpdateResult { final bool ok; final String? role; final bool unchanged; }
class PendingInvitation {
  final String id; final String invitedEmail; final String? createdAt; final String? expiresAt;
  final int? daysRemaining; final bool isExpired; String get statusLabel;
}
class PendingInvitationPage { final List<PendingInvitation> items; }
class InvitationPreview {
  final String tripId; final String tripTitle; final String invitedEmail;
  final String? inviterDisplayName; final String inviterEmail; final String expiresAt;
  String get inviterLabel;
}
class InvitationAcceptResult { final bool ok; final String tripId; final String tripTitle; }

// notes.dart — 5 個 row class 共通欄位：int id, int sortOrder, int version；文字欄位非 null 預設 ''
class TripFlight { airline, flightNo, cabinClass, departAirport, arriveAirport, departAt, arriveAt, note — 全 String }
class TripLodging { name, address, checkInAt, checkOutAt, bookingNo, phone, note — String; final int? dayId; }
class TripReservation { final String kind; title, reservedAt, reservationNo, phone, note — String; final int partySize; }
class TripPretripNote { section, title, content — String; final bool aiGenerated; }
class TripEmergencyContact { name, relationship, phone, email — String; final String kind; final bool aiGenerated; }
class TripNotes { final List<TripFlight> flights; final List<TripLodging> lodgings; final List<TripReservation> reservations; final List<TripPretripNote> pretripNotes; final List<TripEmergencyContact> emergencyContacts; }

// user.dart
class UserInfo { final String id; final String email; final bool emailVerified; final String? displayName; final String? avatarUrl; }
class AccountStats { /* 欄位以 web repo functions/api/account/stats.ts 實際輸出（camelCase 化）為準，實作前先讀該檔 */ }
```

## lib/api/

```dart
// api_error.dart
class ApiError implements Exception {
  final int status; final String code; final String message; final String? detail;
  // 解析優先序：{error:{code,message,detail}} → {error:"string"} → status fallback；OAuth 端點 {error, error_description}
  factory ApiError.fromResponse(int status, dynamic body);
}

// session_store.dart — 可注入測試替身
abstract class SessionStore { Future<String?> read(); Future<void> write(String token); Future<void> clear(); }
class SecureSessionStore implements SessionStore { /* flutter_secure_storage, key: 'tripline_session' */ }
class InMemorySessionStore implements SessionStore { /* 測試用 */ }

// api_client.dart
const String kTriplineOrigin = 'https://trip-planner-dby.pages.dev';
class ApiClient {
  ApiClient({required SessionStore sessionStore, Dio? dio, String origin = kTriplineOrigin});
  // base = '$origin/api'。行為規則（必含對應測試）：
  // 1. 每個 request 帶 Cookie: tripline_session=<token>（store 有值時）
  // 2. POST/PUT/PATCH/DELETE 帶 Origin: $origin header
  // 3. 非 2xx → throw ApiError；429 且 GET → 讀 Retry-After（cap 30s）retry 一次；mutation 不 retry
  // 4. 204 / 空 body → 回 null
  Future<dynamic> get(String path, {Map<String, dynamic>? query});
  Future<dynamic> post(String path, {Map<String, dynamic>? query, Object? body});
  Future<dynamic> put(String path, {Object? body});
  Future<dynamic> patch(String path, {Object? body});
  Future<dynamic> delete(String path);
  Dio get dio; // 供 auth repository 讀 set-cookie 用
}

// auth_repository.dart
class AuthRepository {
  AuthRepository({required ApiClient client, required SessionStore sessionStore});
  Future<UserInfo> login({required String email, required String password});
  // POST /oauth/login {email,password} → 解析 response set-cookie 中 tripline_session=<value>，寫入 store，再 GET /oauth/userinfo
  Future<void> logout();          // POST /oauth/logout（忽略失敗）+ store.clear()
  Future<UserInfo?> currentUser(); // GET /oauth/userinfo；401 → null（不 throw）
}

// trip_repository.dart
class TripRepository {
  TripRepository({required ApiClient client});
  Future<List<TripSummary>> fetchMyTrips();          // GET /my-trips
  Future<List<Trip>> fetchTrips();                   // GET /trips
  Future<Trip> fetchTrip(String id);                 // GET /trips/:id
  Future<List<TripPermission>> fetchTripPermissions(String tripId); // GET /permissions?tripId=...
  Future<PendingInvitationPage> fetchPendingInvitations(String tripId); // GET /invitations?tripId=...
  Future<PermissionInviteResult> createTripPermissionInvite({
    required String tripId,
    required String email,
    String role = 'member',
  });                                                // POST /permissions
  Future<void> revokeTripInvitation({
    required String tripId,
    required String email,
  });                                                // POST /invitations/revoke
  Future<PermissionRoleUpdateResult> updateTripPermissionRole({
    required int permissionId,
    required String role,
  });                                                // PATCH /permissions/:id
  Future<void> deleteTripPermission(int permissionId); // DELETE /permissions/:id
  Future<InvitationPreview> fetchInvitation(String token); // GET /invitations?token=...
  Future<InvitationAcceptResult> acceptInvitation(String token); // POST /invitations/accept
  Future<TripRequestPage> fetchTripRequests({
    required String tripId,
    int limit = 5,
    String sort = 'desc',
    String? before,
    int? beforeId,
  });                                                // GET /requests?tripId=...&limit=...&sort=...
  Future<TripRequest> createTripRequest({
    required String tripId,
    required String message,
  });                                                // POST /requests
  Future<TripRequest> fetchTripRequest(int id);      // GET /requests/:id
  Future<String> createTrip({
    required String id,
    required String name,
    required String? title,
    required String? description,
    required String startDate,
    required String endDate,
    String countries = 'JP',
    bool published = true,
    String lang = 'zh-TW',
    List<TripDestinationInput> destinations = const [],
  });                                                // POST /trips
  Future<void> updateTrip({
    required String id,
    required String? title,
    required String? description,
    required bool published,
    required String lang,
    required List<TripDestinationInput> destinations,
  });                                                // PUT /trips/:id
  Future<List<TripDay>> fetchDays(String id);        // GET /trips/:id/days?all=1
  Future<TimelineEntry> fetchEntry(String tripId, int entryId); // GET /trips/:id/entries/:entryId
  Future<TimelineEntry> updateEntry(
    String tripId,
    int entryId, {
    required int expectedVersion,
    required String? startTime,
    required String? endTime,
    required String? description,
  });                                                // PATCH /trips/:id/entries/:entryId
  Future<void> deleteEntry(String tripId, int entryId); // DELETE /trips/:id/entries/:entryId
  Future<TimelineEntry> copyEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
  });                                                // POST /trips/:id/entries/:entryId/copy
  Future<TimelineEntry> moveEntry({
    required String tripId,
    required int entryId,
    required int targetDayId,
    required int expectedVersion,
  });                                                // PATCH /trips/:id/entries/:entryId body day_id
  Future<void> replaceEntryMasterPoiFromSearchResult({
    required String tripId,
    required int entryId,
    required PoiSearchResult poi,
    required String? entryPoisVersion,
  });                                                // PUT /trips/:id/entries/:entryId/poi-id
  Future<void> replaceEntryMasterPoiWithPoiId({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  });                                                // PUT /trips/:id/entries/:entryId/poi-id
  Future<EntryPoisMutationResult> addEntryAlternateFromSearchResult({
    required String tripId,
    required int entryId,
    required PoiSearchResult poi,
    required String? entryPoisVersion,
  });                                                // POST /trips/:id/entries/:entryId/alternates
  Future<EntryPoisMutationResult> addEntryAlternateWithPoiId({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  });                                                // POST /trips/:id/entries/:entryId/alternates
  Future<EntryPoisMutationResult> deleteEntryAlternate({
    required String tripId,
    required int entryId,
    required int poiId,
    required String? entryPoisVersion,
  });                                                // DELETE /trips/:id/entries/:entryId/alternates/:poiId?entryPoisVersion=...
  Future<EntryAlternatesReorderResult> reorderEntryAlternates({
    required String tripId,
    required int entryId,
    required List<int> orderedPoiIds,
    required String? entryPoisVersion,
  });                                                // PATCH /trips/:id/entries/:entryId/alternates/reorder
  Future<TripNotes> fetchNotes(String id);           // GET /trips/:id/notes
  Future<void> deleteTrip(String id);
  Future<AccountStats> fetchStats();                 // GET /account/stats
  Future<UserInfo> updateProfile({String? displayName}); // PATCH /account/profile
  Future<void> createEntryFromPoiSearchResult({
    required String tripId,
    required int dayNum,
    required PoiSearchResult poi,
    required String startTime,
    required String endTime,
  });                                                // POST /trips/:id/days/:num/entries
  Future<void> createCustomEntry({
    required String tripId,
    required int dayNum,
    required String name,
    required String? note,
    required double lat,
    required double lng,
    required String poiType,
    required String startTime,
    required String endTime,
  });                                                // POST /trips/:id/days/:num/entries
  Future<void> recomputeTravel(String tripId, {int? dayNum}); // POST /trips/:id/recompute-travel?day=N
}

// providers.dart（riverpod 3.x 語法）
final sessionStoreProvider = Provider<SessionStore>(...);     // 預設 SecureSessionStore
final apiClientProvider = Provider<ApiClient>(...);
final authRepositoryProvider = Provider<AuthRepository>(...);
final tripRepositoryProvider = Provider<TripRepository>(...);
class AuthNotifier extends AsyncNotifier<UserInfo?> { Future<void> login(String email, String password); Future<void> logout(); }
final authStateProvider = AsyncNotifierProvider<AuthNotifier, UserInfo?>(AuthNotifier.new); // build() = currentUser()
```

## lib/app/ 與 features/

```dart
// app/router.dart
GoRouter createAppRouter(WidgetRef ref); // 或接受 Ref —— StatefulShellRoute.indexedStack 5 branches：
// /chat(ChatScreen) /trips(TripsListScreen) /map(GlobalMapScreen) /favorites(FavoritesScreen) /account(AccountScreen)
// shell 外：/login（LoginScreen）、/invite（InviteScreen；允許未登入公開預覽）
// trips branch 子路由：/trips/new（TripFormScreen.create）、/trips/:tripId（TripTimelineScreen）、/trips/:tripId/edit（TripFormScreen.edit）、/trips/:tripId/map（TripMapScreen）、/trips/:tripId/notes（TripNotesScreen）、/trips/:tripId/collab（CollabScreen）、/trips/:tripId/add-entry（AddEntryScreen）、/trips/:tripId/add-stop（AddEntryScreen 相容入口）、/trips/:tripId/add-custom-stop（AddEntryScreen 自訂座標入口）、/trips/:tripId/stop/:entryId/edit（EditEntryScreen）、/trips/:tripId/stop/:entryId/change-poi（ChangePoiScreen）、/trips/:tripId/stop/:entryId/copy 與 /move（EntryActionScreen）
// favorites branch 子路由：/favorites/:favoriteId/add-to-trip（AddPoiFavoriteToTripScreen）；secondary route：/explore（ExploreScreen）、/add-to-trip（AddPoiFavoriteToTripScreen direct-mode）
// redirect：未登入(authState data null) 且非 /login 或 /invite → /login；已登入在 /login → /trips

// features/shell/app_shell.dart
class AppShell extends StatelessWidget { const AppShell({required this.navigationShell}); }  // NavigationBar 5 tabs：聊天/行程/地圖/收藏/帳號
class PlaceholderScreen extends StatelessWidget { const PlaceholderScreen({required this.title}); } // 「即將推出」

// features/trip_detail/trip_providers.dart（由 timeline agent 實作，map/notes agent 只 import）
final tripDetailProvider = FutureProvider.family<Trip, String>(...);
final tripDaysProvider = FutureProvider.family<List<TripDay>, String>(...);
final entryDetailProvider = FutureProvider.family<TimelineEntry, ({String tripId, int entryId})>(...);
final tripNotesProvider = FutureProvider.family<TripNotes, String>(...);

// 各 screen class 名
class LoginScreen extends ConsumerStatefulWidget;      // features/auth/login_screen.dart
class ChatScreen extends ConsumerStatefulWidget;       // features/chat/chat_screen.dart
class CollabScreen extends ConsumerStatefulWidget;     // features/collab/collab_screen.dart（接受 tripId）
class InviteScreen extends ConsumerStatefulWidget;     // features/invite/invite_screen.dart（接受 token）
class GlobalMapScreen extends ConsumerStatefulWidget;  // features/map/global_map_screen.dart
class TripsListScreen extends ConsumerWidget;          // features/trips/trips_list_screen.dart
class TripFormScreen extends ConsumerStatefulWidget;   // features/trips/trip_form_screen.dart（create/edit named constructors）
class TripTimelineScreen extends ConsumerWidget;       // features/trip_detail/trip_timeline_screen.dart（接受 tripId）
class AddEntryScreen extends ConsumerStatefulWidget;   // features/trip_detail/add_entry_screen.dart（接受 tripId, initialDayNum?, initialSource?）
class EditEntryScreen extends ConsumerStatefulWidget;  // features/trip_detail/edit_entry_screen.dart（接受 tripId, entryId）
class ChangePoiScreen extends ConsumerStatefulWidget;  // features/trip_detail/change_poi_screen.dart（接受 tripId, entryId, mode）
class EntryActionScreen extends ConsumerStatefulWidget; // features/trip_detail/entry_action_screen.dart（接受 tripId, entryId, action）
class TripMapScreen extends ConsumerWidget;            // features/trip_detail/trip_map_screen.dart（flutter_map + OSM）
class TripMapContent extends ConsumerWidget;           // features/trip_detail/trip_map_screen.dart（可嵌入地圖內容）
class TripNotesScreen extends ConsumerWidget;          // features/trip_detail/trip_notes_screen.dart
class AccountScreen extends ConsumerWidget;            // features/account/account_screen.dart
```

## 測試要求（TDD）

- models：每個 model 至少 1 個 fromJson 測試（fixture 對齊 discovery/models.md 欄位表，含 nullable/0-1 bool/num 轉型 edge case）
- api：ApiClient 4 條行為規則各 1 測試（http_mock_adapter）；AuthRepository login 解析 set-cookie 測試
- screens：每個 screen 至少 1 個 widget test（ProviderScope override 假 repository）
- 全部 `flutter analyze` 零 error/warning、`flutter test` 綠
