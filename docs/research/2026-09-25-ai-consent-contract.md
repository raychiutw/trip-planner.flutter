# AI 資料流與三入口同意契約調查

## 2026-09-26 後續：後端 staged 契約草案

[後端 PR #1353](https://github.com/raychiutw/trip-planner/pull/1353) 在 `uat` 目標分支提出[版本化資料同意契約](https://github.com/raychiutw/trip-planner/blob/1c0ff79d82a8c365d6ff98e5fcbb777b854e6050/docs/api/ai-data-consent.md)：`GET /api/account/ai-data-consent` 回傳 server-owned 告知版本、文字、`unconfigured／not_accepted／current／outdated／revoked／declined` 狀態及接受／決定時間；`POST` 接受或拒絕、`DELETE` 撤銷皆帶所顯示版本及 UUID `requestId`。同一 `requestId` 的同一決定可冪等重送；版本失效或同一 ID 對應不同決定回 409。三個 AI 建工單入口與排隊後的 token mint 都檢查送出者及行程 owner：送出者缺同意回 `AI_DATA_CONSENT_REQUIRED`，只有 owner 缺同意回 `AI_DATA_CONSENT_OWNER_REQUIRED`；排隊後的失效仍只記通用的 `terminalReason: needs_consent`。

這是尚未啟用的契約草案：migration 0097 **不**建立 active disclosure，正式處理方、資料類別、目的、撤銷文案、版本與 production rollout 都待核准。既有 OAuth grant 與 AI 資料同意仍分開。Flutter 現有 `TripRequest.fromJson` 已能解析 `terminalReason: needs_consent`；但聊天文案仍將它誤稱為舊 OAuth 授權。排隊中的通用原因無法辨別哪一方狀態改變，恢復時應重新讀登入者的 consent：本人未達 `current` 才提示本人同意；本人已達 `current` 則提示聯絡行程 owner。這是 #390 的後續實作範圍，本節不代表已解除正式契約 blocker 或做過正式環境測試。

日期：2026-09-25。追蹤：[T49／#382](https://github.com/raychiutw/trip-planner.flutter/issues/382)，交付對象：[T58／#390](https://github.com/raychiutw/trip-planner.flutter/issues/390)。

## 結論

**聊天已有代理操作授權；後端也有三入口共用的 owner Consent gate。現行契約不足以證明使用者已同意特定版本的第三方 AI 資料分享。** #390 應維持 blocked，不能用 client 布林值或增加一句文案冒充後端已有版本化資料同意。

本次只調查並新增此文件；未修改後端、未部署、未送出 AI 工單、未讀取帳號或行程內容、未執行 Flutter／後端測試。#382 保留開啟，正式部署與營運者證據仍未完整。

## 固定版本與部署界線

- Flutter：`b9729c171eb1d27a21f7dfc2a98cabf3512824ae`，研究 worktree 由當時 `origin/master` 建立。
- 後端／web／worker 原始碼：`a26590a4cf4a00f6ac991cf783e7b263244aae60`；本機 HEAD 與 origin/master 相同，工作目錄乾淨。以下 B 連結均固定此 SHA；F 連結均固定 Flutter SHA。
- GitHub [Cloudflare check 107967668463](https://github.com/raychiutw/trip-planner/runs/107967668463) 雖 success，output 指向 `https://bbcb059a.trip-planner-dby.pages.dev` 與 `https://uat.trip-planner-dby.pages.dev`。這只證明 preview／UAT，不能證明正式域名使用同一 SHA。
- 唯讀 `GET https://trip-planner-dby.pages.dev/api/health` 回 `status=healthy`、`d1=ok`、`googleMapsKey=ok`、`ts=2026-09-25T06:32:57.360Z`；沒有 SHA、worker 版本或 consent capability。正式 Pages deployment SHA、D1 schema 與 Mac Mini 執行中的 worker/config 尚未核實。GitHub deployments API 最近資料為舊 github-pages，不能補足。

## 現行端點契約（原始碼證據，非正式環境實測）

| 操作 | 已核實行為 | 界線 |
|---|---|---|
| `GET /api/account/ai-authorization` | session 使用者的 `${uid}:tripline-tp-request` Consent 存在且未過期，回 `{authorized:true}`；否則 false | 不回接收者、資料類別、目的、告知版本；查的是目前使用者，不是所選行程 owner |
| `POST /api/account/ai-authorization` | 固定 client `tripline-tp-request`；upsert `user_id/client_id/scopes/grantedAt`，365 天 TTL，回 authorized=true；記錄 auth audit | 不讀 body 的資料告知版本；`openid/profile` 不是此 AI 的實際能力限縮 |
| `DELETE /api/account/connected-apps/tripline-tp-request` | atomic batch 刪該使用者 Consent 與同 user/client 的 AccessToken、RefreshToken；缺 grant 回 404 `CONSENT_NOT_FOUND` | 不是刪除第三方既收資料，不是召回輸出或中止已送出推論 |
| `POST /api/oauth/mint-restricted` | API secret gate；request 必須 open/processing；查 trip owner 的 Consent；發 owner 身分、restrict_trip token | 不查送出者的資料同意版本；scopes 為空，能力由 owner＋trip gate 決定 |

來源：[B 授權端點](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/account/ai-authorization.ts#L1-L62)、[B 過期判斷](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/src/server/oauth-d1-adapter.ts#L39-L65)、[B 撤銷](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/account/connected-apps/%5Bclient_id%5D.ts#L1-L59)、[B mint](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/oauth/mint-restricted.ts#L34-L167)。後端 middleware 每次從 D1 讀取 AccessToken（[B](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/_middleware.ts#L465-L490)）；刪除既有 token 後後續驗證會拒絕。但 mint 的 Consent 查詢和 token upsert 並非同一原子交易，本次未證明與撤銷併發時的完整保證，也未證明已通過驗證的在途工作會停止。mint TTL 原始碼為 **2 小時**，不可沿用舊 ADR 的 1 小時敘述。

## 三入口與 server gate

| 入口 | Flutter 現況 | 後端建立與處理 |
|---|---|---|
| 聊天 | `_sendText` 等待授權讀取；未授權顯示 `showAiConsentSheet`；允許後呼叫 authorizeAi，再送原訊息；取消不送 | `POST /requests` 驗 trip 寫入權、存 message 與 submitted_by，再觸發 worker |
| AI 健檢 | `_startHealthCheck` 直接呼叫 repository；有 generation／tripId 防過時結果 | `POST /trips/:id/health-check` 驗寫入權、空行程與短期去重；建立帶健檢 prompt／移動記錄的 request 與報告 |
| 筆記 AI 生成 | `_startAiGeneration` 直接呼叫 generateNotes；保留每種 type 的 job／pending 生命周期 | `POST /trips/:id/notes/:type/generate` 驗寫入權、type 與 active job；生成 request＋job，10 分鐘期限 |

F 證據：[聊天](https://github.com/raychiutw/trip-planner.flutter/blob/b9729c171eb1d27a21f7dfc2a98cabf3512824ae/lib/features/chat/chat_screen.dart#L394-L440)、[授權說明](https://github.com/raychiutw/trip-planner.flutter/blob/b9729c171eb1d27a21f7dfc2a98cabf3512824ae/lib/features/chat/ai_consent_sheet.dart#L100-L119)、[repository](https://github.com/raychiutw/trip-planner.flutter/blob/b9729c171eb1d27a21f7dfc2a98cabf3512824ae/lib/api/auth_repository.dart#L272-L286)、[健檢](https://github.com/raychiutw/trip-planner.flutter/blob/b9729c171eb1d27a21f7dfc2a98cabf3512824ae/lib/features/trips/health/trip_health_screen.dart#L155-L185)、[筆記](https://github.com/raychiutw/trip-planner.flutter/blob/b9729c171eb1d27a21f7dfc2a98cabf3512824ae/lib/features/trip_detail/trip_notes_screen.dart#L346-L380)。B 證據：[聊天建立](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/requests.ts#L107-L165)、[健檢](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/trips/%5Bid%5D/health-check.ts)、[筆記](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/trips/%5Bid%5D/notes/%5Btype%5D/generate.ts)。

三條建立路徑沒有在 INSERT 前查資料分享同意，但**不能因此說後端沒有 gate**：共用 worker 在啟動新的 contained Claude session 前 mint，無 owner Consent 時拒發 token、工單 failed／needs_consent，並共用收尾健檢／筆記；mint 失敗不 fallback service token。這是**處理前的代理操作授權**，不是 **AI mutation 建立前的版本化資料分享同意**。[B worker](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/scripts/lib/request-worker.ts#L75-L141)、[B lifecycle ADR](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/docs/adr/0007-request-termination-cancel-and-reap.md)。

另須分清共編：建立請求允許有寫入權的協作者；mint 查 owner；`ai-authorization` 查登入者。協作者替自己授權不會替 owner 建 grant；owner 的 grant 也不是協作者已看過第三方告知的證據。contained session 的 listRequests 會讀同 trip 待處理工單，不是每一張工單都重新 mint。[B MCP read tools](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/scripts/tp-request-mcp-server.js#L55-L82)、[B request 查詢](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/requests.ts#L28-L104)。

## 資料流、接收者與目的

程式所示路徑：Flutter → Cloudflare Pages／D1 儲存工單 → 自有 Mac Mini worker → Claude Code contained session → Tripline MCP 回傳工具資料 → AI 結果回寫 requests／健檢報告／筆記。AI 可依工具結果繼續讀取或執行允許的行程操作；不是單次只傳 composer 文字。[B worker](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/scripts/tripline-api-server.ts#L1-L59)、[B contained command](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/scripts/lib/contained-spawn.ts#L24-L97)。

| 資料類別 | 可核實範圍與目的 |
|---|---|
| 工單文字、reply、送出者 email／display name、工單與 trip 識別碼／狀態／時間 | listRequests 讀 `r.*`＋display name；AI 取得同 trip 待處理工單，用來理解要求、回答與安排旅程。不能宣稱僅送匿名提示詞 |
| 行程 metadata、目的地／座標、日期、每日停留點、POI、住宿、路線、移動時間／距離 | getTrip／getDay 取得，用於旅程安排與健檢；getTrip 為 trips `SELECT *`，不是最小化的 AI 專屬 DTO |
| 停留點／POI 關聯的描述、note、reservation／reservation_url | day merge 會組裝，故使用者自由輸入可能含個資；實際每次傳輸哪些值取決於 worker 工具呼叫，未取真實使用者樣本 |
| 筆記生成所需行程脈絡 | lodging-tips／tips／emergency 的固定 prompt；worker skill 要讀目的地、日期、住宿，回純 JSON，由後端套用生成結果。不能由功能名稱推導「五區筆記、護照、緊急聯絡人全數上傳」；MCP 白名單沒有 notes 讀取工具 |
| 地點查詢文字、地區與位置 | AI 可用 poiSearch 經後端 Google Places 驗證地點；Google 是地圖資料服務的下游接收者，不能混稱另一個聊天模型 |

來源：[B requests SQL](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/requests.ts#L45-L100)、[B getTrip](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/trips/%5Bid%5D.ts#L28-L54)、[B getDay](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/trips/%5Bid%5D/days/%5Bnum%5D.ts#L22-L62)、[B POI merge](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/trips/%5Bid%5D/days/_merge.ts#L160-L210)、[B worker skill（只作資料流證據，未執行）](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/.claude/skills/tp-request/SKILL.md#L10-L76)、[B Google search](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/functions/api/poi-search.ts)。

**接收者核實程度：** 原始碼確定呼叫 Claude binary，contained 環境僅注入 `CLAUDE_CODE_OAUTH_TOKEN`，使用訂閱 OAuth；因此預期 AI 供應商為 Anthropic／Claude。這是程式路徑推論，**尚非正式 worker 的供應商、帳號方案、model、處理地區、訓練使用或保留期限證明**。沒有把 OpenAI／Gemini 編進此三入口主要路徑的證據，亦不據此聲稱全營運環境絕不存在其他接收者。[B OAuth 設定需求](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/scripts/tripline-api-server.ts#L143-L169)、[B clean environment](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/scripts/lib/contained-spawn.ts#L40-L76)。

web 隱私政策原始碼列雲端、地圖、錯誤回報、郵件與維運通知，沒有在該接收者段列出 Claude／Anthropic，也沒有三入口資料告知版本。這是文件內容觀察，不是法律或 App Review 結論。[B PrivacyPage](https://github.com/raychiutw/trip-planner/blob/a26590a4cf4a00f6ac991cf783e7b263244aae60/src/pages/PrivacyPage.tsx#L90-L124)。

## #390 可執行交付與實際 blocker

### 可沿用

沿用 AuthRepository、showAiConsentSheet／AiAuthorizeCard、已連結應用撤銷與後端 owner grant；三入口共用同一帳號狀態來源，不新增三個獨立布林值。既有 `authorized` 只能代表代理操作授權，不能自動升格為資料同意。帳號切換、撤銷、返回前景／重新進入送出流程需重新核實狀態；健檢 generation、筆記 job 生命周期仍各自保留。[F 撤銷現況](https://github.com/raychiutw/trip-planner.flutter/blob/b9729c171eb1d27a21f7dfc2a98cabf3512824ae/lib/features/account/connected_apps_screen.dart#L117-L157)。

### 必須先確認／提供

1. **正式環境證據**：Pages production deployment SHA／schema 與 worker 版本；營運者核對 Claude 供應商與帳號方案、適用資料處理條款、資料類別／目的、保留與撤銷界線。不得將 UAT check 或一般 Claude 官方說明替代此部署證據。
2. **資料同意契約**：產品需核准告知文案及版本、誰同意（登入者／owner／協作者）、版本更新是否重新同意、撤銷是否同時撤銷代理能力。現行 GET/POST 沒有上述欄位，既有 grant 無法證明接受某版告知。
3. **能力差距需後端 scope 批准**：若要求可驗證、跨裝置的版本化資料同意與 server gate，需後端保存／回傳／驗證該版本與同意主體；三條 mutation 建立前、worker 後续讀取／執行的責任邊界也須確認。不能只把 `consentVersion` 塞入現行 POST body（會被忽略）。本研究不指定未存在的新端點、error code 或自行批准後端變更。
4. **撤銷與在途工作證據**：驗證 grant/token 撤銷與併發 mint／既存 session 行為，明示已傳到第三方的資料不會被本機撤銷召回；不要承諾「撤銷等於刪除 AI 留存資料」。

以上滿足後，#390 的最小公開 seam 測試矩陣：同一狀態下三入口未同意／拒絕／撤銷／過期或版本失效均零 AI mutation；同意成功只執行當下 intent 一次；取消、換帳號、換 trip、離頁後不重播；讀取／授權失敗保留輸入並可重試；共編 owner 與送出者兩種授權不可互換；既有健檢與筆記 lifecycle 回歸。這是待核准的驗收交付，**沒有宣稱已完成測試或 #390 功能**。

## 重現與驗證

1. `gh issue view 382 --json body,comments`、同樣讀 #390；查核時兩票 comments 為空。#382 已 assign @me。
2. graph-first：`search_graph(project="Users-ray-Projects-trip-planner", query="consent")` 與 `query="mint restricted"`；Flutter 搜 `authorize`；讀 `get_code_snippet` 的 mint onRequestPost。再讀固定 SHA 檔案確認 graph 行號／內容；string literal／config 搜尋用 rg。
3. `git rev-parse HEAD origin/master`、`git status --short`；以以上 SHA 的 `git show SHA:path` 重讀來源。後端保持唯讀。
4. `gh api repos/raychiutw/trip-planner/commits/a26590a4cf4a00f6ac991cf783e7b263244aae60/check-runs`：只取 Cloudflare output／status；`gh api repos/raychiutw/trip-planner/deployments` 只取 SHA／environment metadata。
5. 唯讀 health GET 如上；沒有登入、AI mutation、grant／revoke mutation或 secrets 輸出。文件驗證逐一確認所有 frozen blob path 與 line anchor 可在對應 Git SHA 解析，並執行 `git diff --check`。
