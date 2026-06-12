# 分享(公開連結) 實作計畫

> executing-plans 逐 task TDD。分支 `feat/share-links`。spec：`docs/superpowers/specs/2026-06-12-share-links-design.md`。

## Task 1：models + repository
- 新 `lib/models/trip_share.dart`:`TripShare`(fromJson;isRevoked/isExpired/isActive)+ `ShareLink`(fromJson;`fullUrl(origin)`)。
- 新 `lib/api/share_repository.dart` + `shareRepositoryProvider`(providers.dart):
  - `fetchShares(tripId)` → GET `/trips/:id/shares` → `(body['shares'])` map TripShare。
  - `createShare(tripId,{label})` → POST `/trips/:id/shares` body `{label: ?label}` → ShareLink。
  - `revokeShare(tripId, shareId)` → PATCH `/trips/:id/shares/:shareId` body `{action:'revoke'}`。
- test:`trip_share_test`(fromJson/isActive/fullUrl)、`share_repository_test`(list/create/revoke wire)。
- commit。

## Task 2：ShareController
- 新 `lib/features/trips/share/share_controller.dart`:`NotifierProvider.autoDispose.family<ShareController,ShareState,String>`。
  - state:`loading, canManage, shares, error, creating, revokingId, lastCreated(ShareLink?)`。copyWith(sentinels)。
  - `build`:constructor 注入 tripId;`_load`(403→canManage false)。
  - `create(label)`:guard creating;create→`lastCreated`=result + reload;error。
  - `revoke(shareId)`:guard;revoke→reload。
  - `_disposed` 守門(沿用 collab)。
- test:load、create(呼叫+reload+lastCreated)、revoke、403→canManage false。
- commit。

## Task 3：ShareScreen + route + 入口
- 新 `lib/features/trips/share/share_screen.dart`:清單(label + 狀態 chip + 瀏覽次數 + 撤銷鈕[二次確認])+ 建立區(`share-label` TextField + `share-create` 鈕)+ 建立成功卡(`fullUrl` + `share-copy` 複製鈕,Clipboard)。非 canManage → 提示。
- `lib/app/router.dart`:top-level `/share-trip/:tripId` → ShareScreen。
- `lib/features/trips/trips_list_screen.dart`:長按 sheet 加「分享」→ `context.push('/share-trip/:id')`。
- test:清單渲染、建立→URL+複製、撤銷→確認→呼叫、空權限提示。
- commit。

## 收尾
- `flutter analyze` 0 + `flutter test` 全綠;`dart format`。CHANGELOG/TODOS。finishing：push + PR(base master)。

## 自審
契約(GET shares / POST create raw-token / PATCH revoke)→ Task1;canManage 403 / 建立顯 URL 複製 / 撤銷確認 → 2/3;沿用 autoDispose.family + _disposed 守門 + Clipboard(免新 dep)。
