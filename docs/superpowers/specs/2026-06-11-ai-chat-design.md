# AI 聊天（行程助手）設計

**目標**：`/chat` 分頁從 placeholder 變成可用的 AI 行程助手 — 選一個行程、看歷史對話、送訊息給 AI、AI 非同步回覆（並可能直接改了行程,client 完成後自動刷新）。

**架構心智模型**：**非同步「工單佇列」,不是 ChatGPT 對話 API**。送訊息 = 在後端建一筆 `trip_requests` row（status `open`）;外部 worker 非同步處理後回填 `reply`(markdown) + status。client 靠 **polling** 等結果。per-trip;同行程 collaborator 共享對話。

**Tech**：flutter_riverpod 3.x / go_router / dio mock + mocktail / markdown 套件（onTapLink）。單一 PR,分 3 階段。

---

## 範圍（「完整」）
**做**：行程下拉選擇、歷史 cursor 分頁（上捲載更舊）、送訊息 + polling 等回覆、markdown 渲染（僅 AI 氣泡）、reply deep-link in-app 跳轉、三方氣泡（自己/其他 collaborator/AI）、特殊前綴摘要、亂碼防護、AI 改完行程後自動刷新 trip providers、長等待提示、open/processing row 重開續 poll。
**不做**：SSE（polling 已足夠,SSE 只送 status 又要手動帶 cookie）、client 主動 PATCH（admin-only）、多輪對話記憶（後端每則獨立處理,不傳歷史）。

---

## 後端契約（權威來自 web `functions/api/requests*`）

base `https://trip-planner-dby.pages.dev/api`,出口 camelCase（`deepCamel`）。經 `ApiClient`（自動 Cookie + CSRF Origin）。

### 端點
- **列歷史** `GET /api/requests?tripId=&limit=&sort=desc[&before=&beforeId=]`
  - **永遠帶 `limit`** → 回 `{ items:[...], hasMore:bool }`（不帶 limit/before/after 會回裸陣列,避開）。
  - cursor（往更舊,DESC）：`before=<最舊 createdAt>&beforeId=<最舊 id>`;比較鍵 `(createdAt, id)` 複合。
  - viewer 可讀;缺 tripId（非 admin）→ 400。
- **送訊息** `POST /api/requests`，body `{ "tripId": string, "message": string }`（camelCase）→ **201** 完整 row（**INSERT RETURNING,無 `submittedByDisplayName`**）;30s 內同 trip+message+人重複 → **200** 既有 row。需 write 權限（viewer 403）。**勿送 `mode`**（已廢）。
- **查單筆（poll）** `GET /api/requests/:id` → 完整 row（含 `submittedByDisplayName`）。viewer 可讀;不存在 404。
- *（不用）* SSE `GET /api/requests/:id/events`（純 status 流）、`PATCH /api/requests/:id`（admin/service 回填）。

### row 形狀（`trip_requests`,camelCase）
`id:int` / `tripId:string` / `message:string` / `reply:string?`(markdown,未完成 null) / `status`:`open|processing|completed|failed` / `submittedBy:string?`(email) / `submittedByDisplayName:string?`(GET 才有) / `processedBy:'api'|'job'?` / `createdAt:string?`(ISO,存字串) / `updatedAt:string?`。
（`mode` 已 DROP;`actions_taken` schema 有但 API 不回 → 忽略。）

### 狀態機 + 流程
`open`（排隊）→ `processing`（AI 處理）→ `completed`（有 reply）/ `failed`。送出後**不會馬上變**,靠 poll。等待可長（AI 健檢 5–60 分,曾 1h+）→ **不設短 timeout 放棄**。

### 錯誤（`{error:{code,message,detail?}}`）
`AUTH_REQUIRED`→401（poll 收 401 = session 過期 → 停 + 提示重登）;`PERM_DENIED`→403（無權/CSRF）;`DATA_VALIDATION`→400;`DATA_NOT_FOUND`→404。POST /requests **無 rate limit**(僅 30s 去重)。

### reply 處理
markdown,**僅對 AI 氣泡渲染**（user 訊息純文字防 XSS）。常含 deep-link（`/trip/:id/health`、`/trip/:id/notes`…）。後端已 `sanitizeReply`,信任顯示。**亂碼防護**（鏡像 `detectGarbledText`）：含 `�` / 連續 3+ U+0080–U+00FF / C1 控制字元 → 顯示「訊息含編碼錯誤,無法顯示」。

### 特殊前綴（user 氣泡顯示摘要,非整坨 system prompt）
`[AI 健檢]`→「已觸發 AI 行程健檢」;`[行程筆記-lodging-tips]`→「…住宿在地建議」;`[行程筆記-tips]`→「…行前須知」;`[行程筆記-emergency]`→「…緊急聯絡」。（這些功能共用同一 queue,聊天歷史會混入 → 顯示摘要,不過濾。）

### AI 改資料 → client 要刷新
AI（worker）用同一套 REST 直接改 trip（對 client 透明,**無 structured action 回傳,無確認流程**,只給 markdown reply）。**完成後 client 不會被通知** → ChatController 在 request `completed` 後 **`invalidate` 該 trip 的 `tripDetailProvider`/`tripDaysProvider`/`tripNotesProvider`/`tripSegmentsProvider`（+ `favoritesProvider`）**,使用者切回行程才看得到變更。

---

## 階段 0：models + repository + markdown 依賴

### `lib/models/trip_request.dart`（新,純 Dart）
```dart
enum RequestStatus { open, processing, completed, failed }
// parse: 'completed'/'failed'/'processing'/'open' → 對應;unknown → processing（不誤判終止,續 poll）
// isTerminal => completed || failed

class TripRequest {
  final int id; final String tripId; final String message; final String? reply;
  final RequestStatus status; final String? submittedBy; final String? submittedByDisplayName;
  final String? processedBy; final String? createdAt; final String? updatedAt;
  // fromJson:id toInt;status parse;其餘 as String?
}
```

### `lib/api/requests_repository.dart`（新 + provider `requestsRepositoryProvider`）
```dart
Future<({List<TripRequest> items, bool hasMore})> fetchRequests({
  required String tripId, int limit = 20, String sort = 'desc',
  String? before, int? beforeId,
}); // GET /requests?tripId=&limit=&sort=[&before=&beforeId=];body 為 {items,hasMore}

Future<TripRequest> sendRequest({required String tripId, required String message});
// POST /requests {tripId, message} → row

Future<TripRequest> fetchRequest(int id); // GET /requests/:id（poll）
```
（`fetchRequests` 永遠帶 `limit` → 後端回物件形;解析 `body['items']` + `body['hasMore']`。）

### pubspec：加 markdown 套件
`flutter_markdown_plus`（flutter_markdown 維護分支,提供 `MarkdownBody` + `onTapLink`）。pub get 確認可用;不可用則改 `markdown_widget` / `gpt_markdown`（皆支援 link tap）。

### 測試（階段 0）
`test/models/trip_request_test.dart`：fromJson（含 status parse、unknown→processing、reply null）。
`test/api/requests_repository_test.dart`：fetchRequests（{items,hasMore} 解析 + query 帶 limit/before/beforeId）、sendRequest（POST body camelCase {tripId,message} → row）、fetchRequest（GET /requests/:id）、401 → ApiError。

---

## 階段 1：ChatController（polling 狀態機）

### `lib/features/chat/chat_message.dart`（view model + 投影）
```dart
enum ChatRole { user, assistant }
class ChatMessage {
  final String key;        // row id + 'u'/'a'
  final ChatRole role;
  final String text;
  final bool isMarkdown;   // assistant completed
  final bool isFailed;
  final int? pendingRequestId; // open/processing 的 placeholder
  final String? submittedBy;   // user 氣泡:判斷自己/他人
  final String? senderName;
  final String? createdAt;
}
// rowToMessages(TripRequest, {required String? myEmail}) → List<ChatMessage>（1 row → 1~2 氣泡）
//   user 氣泡:displayUserText（特殊前綴替換）、亂碼防護
//   assistant:completed→markdown reply（亂碼防護）/ failed→reply??'AI 處理失敗。' / open|processing→'思考中…'+pendingId
```

### `lib/features/chat/chat_controller.dart`（`NotifierProvider.autoDispose.family<ChatController, ChatState, String tripId>`）
`ChatState`：`messages:List<ChatMessage>`、`hasMore`、`loadingOlder`、`oldest:(createdAt,id)?`、`sending`、`error?`、`authExpired`、`initialLoading`。

方法：
- `loadInitial()`：`fetchRequests(tripId, limit, sort:'desc')` → 反轉 asc → 設 messages/hasMore/oldest。對 open|processing 的 row **續 poll**。
- `loadOlder()`：`fetchRequests(before:oldest.createdAt, beforeId:oldest.id)` → prepend。
- `send(text)`：樂觀 push（user + 思考中 placeholder）→ `sendRequest` → 取 id → `_poll(id)`。POST 失敗 → 移除 placeholder + error。
- `_poll(id)`：立即 `fetchRequest`,之後迴圈 `Future.delayed(~4s)` 直到 `status.isTerminal` 或 `_disposed` 或 401(authExpired,停)。completed → 用 reply 換掉 placeholder + **invalidate trip providers**（見契約）。failed → 顯示失敗。
- 生命週期：`ref.onDispose(() => _disposed = true)`（autoDispose:切行程/離開頁即停 poll）。多筆 inflight 用 `Set<int>` 防重複 poll。

### 測試（階段 1）
`test/features/chat/chat_message_test.dart`：rowToMessages（completed→markdown、failed、processing→思考中+pendingId、特殊前綴、亂碼）。
`test/features/chat/chat_controller_test.dart`（mock RequestsRepository）：loadInitial 反轉排序、send 樂觀+poll 到 completed 換 reply、poll completed 後 invalidate trip providers（用 listen/refetch 驗）、401→authExpired、loadOlder prepend。

---

## 階段 2：ChatScreen + 路由

### `lib/features/chat/chat_screen.dart`（ConsumerStatefulWidget）
- state：`selectedTripId`（預設 `myTripsProvider` 第一筆/最近）。
- 頂端：行程 **DropdownButton**（watch `myTripsProvider`,顯示 displayTitle;切換 → 換 `chatControllerProvider(tripId)`）。my-trips 空 → 提示「先建立行程」。
- body：watch `chatControllerProvider(selectedTripId)`。
  - 訊息列：`ListView(reverse:true)`（newest 底部;上捲近頂 → `loadOlder`）。
  - 氣泡三方（讀 `authStateProvider` 取 myEmail）：assistant 左 + 「Tripline AI」(sage)、自己 accent 右、其他 collaborator 左 + 名 + 頭像(pink)。
  - **AI 氣泡 markdown**（`MarkdownBody` + `onTapLink` → deep-link 映射:`/trip/:id`→`/trips/:id`、`/trip/:id/notes`→`/trips/:id/notes`、`/trip/:id/map`→`/trips/:id/map`、無對應如 `/health`→退回 `/trips/:id` 時間軸;外部 http → 忽略/snackbar）。user 氣泡純 `Text`。
  - 思考中態（pendingRequestId）：「思考中…」+ 進度指示;`createdAt` 距今 ≥3 分 → 加「AI 還在處理（已等候 N 分）」。failed:錯誤色。
  - 亂碼 row → placeholder 文字。
- 底部輸入列：`TextField` + 送出鈕（空白 disable;送出呼叫 `controller.send`,清空欄位,捲到底）。
- `authExpired` → 橫幅「登入已過期,請重新登入」。
- ValueKey：`chat-trip-dropdown`、`chat-input`、`chat-send`、`chat-msg-<key>`、`chat-bubble-ai`/`chat-bubble-self`/`chat-bubble-other`。

### 路由（`lib/app/router.dart`）
`/chat` 的 `builder` 由 `PlaceholderScreen(title:'聊天')` 改為 `const ChatScreen()`。

### 測試（階段 2,widget + mock repo + override myTrips/auth）
行程下拉渲染 + 切換;送訊息 → 樂觀顯示 + 呼叫 sendRequest;completed reply markdown 顯示;思考中態;空 my-trips 提示;（deep-link 映射函式抽純函式單測）。

---

## 錯誤處理（統一）
| 情境 | 行為 |
|---|---|
| send 成功 | 樂觀 user+思考中 → poll → completed 換 reply + invalidate trip providers |
| poll 收 401 | authExpired:停 poll + 橫幅提示重登 |
| request failed | 顯示 reply（已被後端改人話）或「AI 處理失敗」,失敗樣式 |
| send/load 其他錯誤 | snackbar/error 態,移除樂觀 placeholder |
| 亂碼 reply/message | placeholder「含編碼錯誤,無法顯示」 |

---

## 測試完成定義
每階段 `flutter analyze` 0 + `flutter test` 全綠。

---

## 風險 / 注意
- **deep-link 路由不一致**：reply 用 web `/trip/:id/*`（單數）,Flutter 是 `/trips/:id/*`（複數）+ 無 `/health` 路由 → 需映射表,未知路徑退回時間軸。抽純函式 `mapReplyLink(href, tripId)` 以利測試。
- **長等待**：poll 無硬 timeout,但 autoDispose（離頁/切行程）停;不要因等太久就放棄。
- **混入的健檢/筆記 row**：同 queue,顯示摘要不過濾（對齊 web）。
- **markdown 依賴**：`flutter_markdown_plus` pub get 確認;不可用換 `markdown_widget`/`gpt_markdown`（plan 自審記錄實際採用）。
- **POST row 缺 displayName**：樂觀 UI 用當前 user.displayName 補（authStateProvider）。
- **AI 改資料刷新**：completed 後 invalidate trip 系列 providers — 這是本功能最關鍵的非顯而易見點。
- **TripRepository 不動**：聊天走獨立 `RequestsRepository`,不擴肥 TripRepository。
- **status 不信任**：unknown 值 narrow 成 processing 續 poll,避免 UI 永久 hang 或誤判完成。
```
