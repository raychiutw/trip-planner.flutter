# 分享(公開連結) 設計 spec

> P2。為行程建立/管理唯讀公開分享連結(`trip_shares`)。後端固定。

## 後端契約(本機 repo 讀證)
- **list** `GET /api/trips/:id/shares`(需 write permission)→ `{shares:[{id,label,visibleSections,expiresAt,viewCount,anonymous,createdBy,createdAt,revokedAt}]}`(不回 token/hash)。
- **create** `POST /api/trips/:id/shares` body `{label?, visibleSections?, expiresAt?, anonymous?}` → `{id, token, url:'/s/<token>', label, visibleSections, expiresAt, anonymous}`。**raw token 只在建立時回一次**(只存 hash)。`visibleSections` 省略 → 後端 DEFAULT_SHARE_SECTIONS;`expiresAt` epoch ms 或 null=永久。
- **revoke** `PATCH /api/trips/:id/shares/:shareId {action:'revoke'}` → `{ok,revoked:true}`(設 revoked_at)。
- (**rotate** `{action:'rotate'}` → 新 token;update 其他欄位 — 本期不做。)
- 公開連結 = `<kTriplineOrigin>/s/<token>`(在瀏覽器/web 開啟;app 只負責產生 + 分享 URL)。
- 權限:owner/editor(write permission)可管理;viewer/他人 403。無 OCC。

## 範圍(MVP,1 PR)
- 列出現有分享連結(label、狀態 active/已撤銷/已過期、瀏覽次數)+ 撤銷。
- 建立連結(label 選填)→ 顯示完整 URL + **複製到剪貼簿**(raw token 只回一次,建立後即顯示)。
- 入口:行程清單長按 sheet「分享」。

### 不在範圍(本期)
- visibleSections 挑選 UI(預設後端 DEFAULT)、expiresAt 日期選擇、anonymous 切換、rotate、原生 share sheet(用 Clipboard 複製,免新增 share_plus dep)、public 瀏覽端(那是 web)。

## 架構(沿用既有慣例)
- **models**(`lib/models/trip_share.dart`):
  - `TripShare{id, label, visibleSections, expiresAt?, viewCount, anonymous, createdAt?, revokedAt?}`;`bool get isRevoked => revokedAt != null`;`bool get isExpired`(expiresAt 過 now);`bool get isActive => !isRevoked && !isExpired`。
  - `ShareLink{id, token, url, label}`(create 回應;`fullUrl(origin)` = `origin + url`)。
- **api**(`lib/api/share_repository.dart` + provider):`fetchShares(tripId)`、`createShare(tripId,{label})`、`revokeShare(tripId, shareId)`。PATCH revoke body `{action:'revoke'}`。
- **controller**(`lib/features/trips/share/share_controller.dart`,`NotifierProvider.autoDispose.family<_,_,String tripId>`):load 清單(403→canManage false)、`create(label)`(回新 ShareLink 供畫面顯示 + reload)、`revoke(shareId)`;busy/error。沿用 collab 的 `_disposed` 守門 + 重入守門 + reload。
- **screen**(`lib/features/trips/share/share_screen.dart`):清單(每列 label + 狀態 chip + 瀏覽次數 + 撤銷鈕,二次確認)+ 建立區(label `TextField` + 建立鈕)+ 建立成功卡(顯示 `fullUrl` + 複製鈕,key `share-copy`)。非 write 權限 → 提示。route top-level `/share-trip/:tripId`;入口:`TripsListScreen` 長按 sheet「分享」。

## 測試
- model:fromJson、isActive/isExpired/isRevoked、ShareLink.fullUrl。
- repository:list({shares})、create(POST body + 回 token/url)、revoke(PATCH `{action:'revoke'}`)。
- controller:load、create→呼叫 + reload + 回 ShareLink、revoke→呼叫 + reload、403→canManage false。
- screen:清單渲染、建立→顯示 URL + 複製、撤銷→確認→呼叫、空權限提示。

## 決策
MVP(label + 建立/清單/撤銷 + 複製);expiry/sections/anonymous/rotate/原生分享延後。連結用 `<kTriplineOrigin>/s/<token>`。
