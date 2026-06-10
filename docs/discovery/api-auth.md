# Tripline 後端 API 調查報告（for Flutter mobile client）

## 1. 認證機制

### Session cookie
- 名稱 **`tripline_session`**，屬性：`HttpOnly; Secure(https); SameSite=Lax; Path=/; Max-Age=2592000`（30 天）— `functions/api/_cookies.ts`
- Token 格式：**非 JWT**，`base64url(payload).base64url(HMAC-SHA256)`，payload `{ uid, iat, exp, csrf, v, sid }`，secret = env `SESSION_SECRET` — `src/server/session.ts`
- `sid` 對應 D1 `session_devices` row，支援遠端 revoke（`/api/account/sessions`）。payload 內 `csrf` 欄位**未啟用** double-submit 驗證，CSRF 防護僅靠 Origin allowlist + SameSite=Lax。

### Bearer token（V2 OAuth）
- `_middleware.ts` 認證順序：**(1) session cookie → (2) `Authorization: Bearer <opaque token>`**。Bearer 是 opaque 48-byte token 存 D1 `oauth_models`（非 JWT）。
- user-bound Bearer（`authorization_code` grant，`user_id` 非 null）→ 解出 userId/email，**與 cookie session 完全等價**，可打所有 `/api/*` 業務 endpoint。
- service Bearer（`client_credentials`，`user_id=null`）→ `isServiceToken=true`，多數 trip 權限檢查直接拒絕，mobile 不適用。
- **例外：`/api/oauth/*` 路徑 middleware 一律 `auth=null`**（OAuth endpoint 自管認證）。因此 **`GET /api/oauth/userinfo` 只吃 session cookie，不吃 Bearer**（內部走 `requireSessionUser`）。用 Bearer 的 client 取 user info 要靠 token response 裡的 `id_token`（scope 含 `openid` 時）或自行先呼叫 cookie 流程。

### Token endpoint — `POST /api/oauth/token`（form-urlencoded 或 JSON）
- grants：`authorization_code`（+PKCE S256）、`refresh_token`（rotation + reuse 偵測，重放會 cascade revoke 整個 family）、`client_credentials`（限 confidential client）。
- Response：`{ access_token, refresh_token, token_type:'Bearer', expires_in:3600, scope, id_token? }`。access 1h、refresh 30d。
- client 須事先註冊於 `client_apps`（dev portal `/api/dev/apps`）；public client 可免 secret 但 PKCE 必驗。
- `GET /api/oauth/authorize`：驗 client/redirect_uri 後，**需瀏覽器 session cookie**；未登入 302 → `/login?redirect_after=...`，登入後發 code 302 回 `redirect_uri?code=&state=`。

### 密碼登入 — `POST /api/oauth/login`
- Body `{ email, password }` → 200 `{ ok:true, userId, email }` + `Set-Cookie: tripline_session=...`。
- Rate limit：per-IP + per-email 各 5 次/15min，鎖 30min（429 `LOGIN_RATE_LIMITED` + `Retry-After`）。失敗統一 401 `LOGIN_INVALID`。
- 另有 `/api/oauth/signup`、`/api/oauth/login/google`（browser redirect flow，也是發 cookie）。

### Mobile 最可行路徑（兩條都可行）
1. **直接密碼登入拿 cookie（最簡單）**：POST `/api/oauth/login` → 存 `tripline_session` cookie（dio + CookieJar / 自行讀 Set-Cookie）。注意 CSRF：cookie-based **mutating request（POST/PUT/PATCH/DELETE）必須帶 `Origin: https://trip-planner-dby.pages.dev`**（native client 預設不送 Origin → 會被 `checkCsrf` 以 403 `Origin header required` 拒絕）。`/api/oauth/*` 路徑免 Origin。
2. **OAuth code+PKCE 拿 Bearer（較正規）**：系統瀏覽器開 `/api/oauth/authorize`（custom scheme redirect_uri）→ 換 token → 之後全部帶 `Authorization: Bearer`。**Bearer 且無 Origin header 時 CSRF 直接 skip**，對 native app 最乾淨；refresh_token 有 rotation，平行 refresh 會觸發 family revoke，client 須序列化 refresh。前提：要先在 `client_apps` 註冊一個 public client。

## 2. 核心 endpoints 合約

**通用慣例**：成功 response 經 `_utils.ts json()` **深層 snake_case→camelCase**（`day_num`→`dayNum`）；request body 維持 **DB snake_case 欄位**（`poi_type`、`sort_order`）混部分 camelCase（`expectedVersion`、`poiId`、`displayName`、`startDate`）。錯誤 shape：業務端點 `{ error: { code, message, detail? } }`（`functions/api/_errors.ts`，code 如 `AUTH_REQUIRED`/`PERM_DENIED`/`DATA_NOT_FOUND`/`STALE_ENTRY`/`SYS_RATE_LIMIT`）；OAuth wire 端點為 RFC 6749 flat `{ error, error_description }`。

| Endpoint | Method | 說明 |
|---|---|---|
| `/api/my-trips` | GET（須認證） | `[{ tripId, name, title, totalDays }]` — 使用者有 permission 的行程 |
| `/api/trips` | GET | 僅回 `published=1`（admin `?all=1` 回全部）：`[{ tripId, name, owner, ownerDisplayName, ownerUserId, title, countries, published, dataSource, lang, dayCount, startDate, endDate, memberCount }]` |
| `/api/trips` | POST | body `{ id, name, startDate, endDate, title?, description?, countries?, destinations?[], lang?, data_source? }` → 201 `{ ok, tripId, daysCreated, destinationsCreated }`（自動建 days/permissions/docs） |
| `/api/trips/:id` | GET | trips row（`SELECT *` camelCase 化）+ `destinations[]`；published 行程可匿名讀，否則須 member |
| `/api/trips/:id` | PUT / DELETE | PUT 白名單欄位 `{name,title,description,countries,published,data_source,lang,destinations[]}` → `{ok:true}`；DELETE 限 owner/admin → `{ok:true}` |
| `/api/trips/:id/days` | GET | 預設 summary `[{id, dayNum, date, dayOfWeek, label, title}]`；**`?all=1`** 回完整：`[{ id, dayNum, date, dayOfWeek, label, title, version, hotel:{...pois欄位, parking:[]}, timeline:[{ ...entry, travel:{type,desc,min,distanceM,source}|null, master:{poiId,name,lat,lng,type,category,hours,rating,price,photos,reservation,note,...}|null, alternates:[], stopPois:[], entryPoisVersion }] }]` — `days/_merge.ts buildAllDays` |
| `/api/trips/:id/days` | POST | `{ position: 'start'|'end'|'insert', date? }` → `{ day: {...} }` |
| `/api/trips/:id/days/:num/entries` | POST | `{ title(必填), poi_type?, description?, note?, lat?, lng?, rating?, sort_order?, start_time?/end_time?, source? }` → 201 entry row；自動 find-or-create POI + master 綁定 |
| `/api/trips/:id/notes` | GET | 聚合 5 區：`{ flights:[], lodgings:[], reservations:[], pretripNotes:[], emergencyContacts:[] }` |
| `/api/trips/:id/notes/{flights\|lodgings\|reservations\|pretrip\|emergency}` | GET / POST | GET → `{ items: [...] }`；POST body 為各表白名單 snake_case 欄位（見 `notes/_shared.ts ALLOWED_FIELDS`）→ 201 row |
| `/api/trips/:id/notes/{section}/:rowId` | PATCH / DELETE | PATCH 支援 OCC `{ ...fields, expectedVersion? }`，版本不符 409 `STALE_ENTRY`；DELETE → `{ok:true}` |
| `/api/trips/:id/notes/{section}/reorder` | POST | `{ items: [{ id, sortOrder }] }` |
| `/api/poi-favorites` | GET / POST | GET → `[{ id, userId, poiId, favoritedAt, note, poiName, poiAddress, poiLat, poiLng, poiType, poiRating, usages:[{tripId,tripName,dayNum,dayDate,entryId}] }]`；POST `{ poiId, note? }` → 201 row（重複 409、POI 不存在 404）；`DELETE /api/poi-favorites/:id`；`POST /:id/add-to-trip`（PR-B 加入行程）|
| `/api/poi-search` | GET | 查詢參數：`q`（必填，2–200 字）、`limit`（1–20，預設 10）、`region`（中文城市名，選填）；回 `{ results: PoiSearchResult[] }`，item 欄位 snake_case：`place_id, name, address, lat, lng, type, category, rating?, photos?[]` |
| `/api/pois/find-or-create` | POST | body snake_case：`name, type, lat, lng, address?, category?, source?, place_id?`；`type` 須通過 `mapGooglePrimaryTypeToPoiType` 映射；回 `{ id }`（POI 的整數主鍵） |
| `/api/account/profile` | PATCH | `{ displayName: string\|null }` → 200 userinfo shape `{ id, email, emailVerified, displayName, avatarUrl, createdAt }` |
| `/api/oauth/userinfo` | GET（**僅 cookie**） | `{ id, email, emailVerified, displayName, avatarUrl, createdAt }` |

## 3. 前端呼叫慣例（`src/lib/apiClient.ts` — mobile 須複製的行為）

- Base URL：相對路徑 `fetch('/api' + path)` — mobile 改絕對 `https://trip-planner-dby.pages.dev/api`。
- Header：body 為 JSON string 時自動補 `Content-Type: application/json`（GET/HEAD/DELETE 不補）。**無任何 CSRF token header** — 防護全靠瀏覽器自動帶的 `Origin`，mobile 用 cookie 模式時須手動補 `Origin`。
- 認證：cookie 自動隨 fetch 送（same-origin）；無 Authorization header。
- **429 處理**：讀 `Retry-After`（delta-seconds 或 HTTP-date，cap 30s），**只對 GET/HEAD retry 1 次**，mutation 不 retry（防 double-mutate）。
- **204 → 視為成功回 `undefined`**（多個 DELETE 端點回 204，`response.json()` 會炸，必須先判斷）。
- 錯誤解析（`src/lib/errors.ts ApiError.fromResponse`）：優先 `{error:{code,message,detail}}`，fallback `{error:"string"}` 與純 status；`detail` 截 200 字。Mobile 建議照抄此分層（code 為穩定機器碼，message 為繁中人話）。

## 4. CORS / Origin 限制（直接打 prod API）

- **後端完全沒有 CORS header**（無 `Access-Control-Allow-Origin`、無 OPTIONS handler；v2.33.42 已拔掉唯一的 `*`）。
- **Flutter native（iOS/Android）不受 CORS 影響**（CORS 是瀏覽器概念）→ 直接打沒問題。真正會踩的是：
  1. **CSRF Origin 檢查**：cookie 認證的 mutating request 沒帶 `Origin` → 403 `Origin header required`；帶了但不在 allowlist（prod origin / localhost / env `ALLOWED_ORIGIN`）→ 403 `Invalid origin`。解法：cookie 模式手動帶 `Origin: https://trip-planner-dby.pages.dev`，或改用 Bearer（無 Origin 即 skip）。
  2. Bearer 模式若多帶了非法 Origin 一樣 403（defense in depth）。
- **Flutter Web 則完全不可行**（cross-origin 無 CORS header，preflight 必死），除非部署同網域或後端加 CORS。
- 其他注意：UA 會被 `summarizeUserAgent` 記進 session_devices；`CF-Connecting-IP` 用於 rate-limit bucket；錯誤 5xx 會觸發後端 Telegram alert，測試時避免亂打。

**關鍵檔案**：`functions/api/_middleware.ts`（認證順序+CSRF）、`functions/api/_session.ts`、`functions/api/_cookies.ts`、`functions/api/oauth/token.ts`、`functions/api/_errors.ts`、`functions/api/_utils.ts`（deepCamel）、`functions/api/trips/[id]/days/_merge.ts`（timeline shape）、`src/lib/apiClient.ts`。