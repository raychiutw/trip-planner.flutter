# Tripline 後端任務：單筆收藏取消與復原 API

日期：2026-07-18

狀態：待後端實作

後端 repository：`/Users/ray/Projects/trip-planner`

前端 repository：`/Users/ray/Projects/trip-planner.flutter`

## 1. 目標

讓使用者在 App 內單筆「取消收藏」後，可以在 Undo 提示期間透過同一筆 favorite id 復原。復原必須由伺服器保存原始關聯與備註，不再由 App 用 `POST /api/poi-favorites` 猜測式重建。

本任務只處理單筆收藏關聯；不包含批次復原、最近刪除頁、POI／行程停留點刪除或一般資料回收桶。

## 2. 定版 API

### 2.1 取消收藏

沿用既有端點與成功狀態碼：

```http
DELETE /api/poi-favorites/:id
Cookie: session=...
Origin: https://...

HTTP/1.1 204 No Content
```

行為由 hard delete 改為 soft delete：

- 僅 owner 可取消。
- 寫入 `deleted_at`，保留原 `id`、`poi_id`、`note` 與 `favorited_at`。
- `GET /api/poi-favorites` 與所有收藏關聯查詢必須排除 `deleted_at IS NOT NULL`。
- 對同一筆已取消收藏重送 DELETE 必須保持 idempotent，回 `204`。
- 不得刪除 POI、行程停留點或 `trip_entry_pois`。

錯誤維持現有 envelope：

- 無此 id：`404 DATA_NOT_FOUND`
- 非 owner：沿用專案現有 containment 規則，不可洩漏其他使用者資料
- 未登入／CSRF／rate limit：沿用現有 middleware

### 2.2 復原收藏

新增端點：

```http
POST /api/poi-favorites/:id/restore
Cookie: session=...
Origin: https://...
Content-Type: application/json

{}
```

成功：

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 987,
  "user_id": "user-id",
  "poi_id": 123,
  "note": "原收藏備註",
  "favorited_at": "2026-07-18 12:00:00",
  "deleted_at": null
}
```

規則：

- 只接受目前登入 owner 的 soft-deleted favorite。
- 伺服器復原期限為取消後 10 分鐘；App 的 Undo 按鈕只顯示 6 秒，較長的 server window 用於網路重試，不新增最近刪除 UI。
- 復原將同一列的 `deleted_at` 清為 `NULL`，保留原 favorite id、POI、note 與原始收藏時間。
- 同一 restore request 重送必須 idempotent：該 favorite 已恢復時仍回 `200` 與目前 row。
- 超過期限回 `410 UNDO_EXPIRED`。
- 找不到 id 回 `404 DATA_NOT_FOUND`。
- 若同一使用者已存在另一筆 active favorite 指向相同 POI，回 `200` 與該 active row，並確保最後只有一筆 active 關聯；不得回傳 500 或建立重複資料。
- 不接受 client 傳 `poiId`、`note` 或 owner，避免竄改原 snapshot。

## 3. 資料庫 migration

在 `poi_favorites` 新增 nullable timestamp：

```sql
ALTER TABLE poi_favorites ADD COLUMN deleted_at TEXT NULL;
```

將「同一使用者＋同一 POI」的唯一性改為只限制 active row。請依目前 migration 中的實際 index 名稱調整，結果需等價於：

```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_poi_favorites_active_user_poi
ON poi_favorites(user_id, poi_id)
WHERE deleted_at IS NULL;
```

所有直接 join `poi_favorites` 的查詢都必須明確加入 active 條件。後端 PR 必須列出受影響查詢，不能只改收藏清單 route。

本期不做通用回收桶。Soft-deleted rows 至少保留 24 小時；若現有排程架構已有資料清理工作，可在 24 小時後清除，否則另開清理 ticket，不阻擋 restore API 上線。

## 4. POST 建立收藏的相容行為

`POST /api/poi-favorites` 保留既有 request：

```json
{ "poiId": 123, "note": "optional" }
```

- 已有 active favorite：維持 `409 DATA_CONFLICT`。
- 只有 soft-deleted favorite：將該列重新啟用，套用本次 request 的 `note` 與新的 `favorited_at`，回 `201`。這是一次新的收藏，不受 10 分鐘 Undo 期限限制。
- 不能因 soft-deleted row 而觸發 unique constraint 500。

## 5. Audit、快取與安全

- DELETE 寫既有取消收藏 audit event，包含 favorite id 與 poi id，不記錄敏感 session 資料。
- Restore 新增 `poi_favorite.restored` audit event。
- DELETE、restore、重新建立都必須讓 `GET /api/poi-favorites` 快取失效。
- Restore 必須通過 session、companion containment、Origin／CSRF 與 mutation rate limit。
- API 回應不可揭露其他 owner 的 favorite 是否存在。

## 6. 後端檔案範圍

實際名稱以 repository 為準，至少盤點／修改：

- `migrations/*poi*favorites*.sql` 或新增下一號 migration
- `functions/api/poi-favorites.ts`
- `functions/api/poi-favorites/[id].ts`
- 新增 `functions/api/poi-favorites/[id]/restore.ts`（若 router 慣例不同，沿用既有動態 route 結構）
- 所有直接查詢／join `poi_favorites` 的 repository 或 route
- `tests/api/poi-favorites-post.integration.test.ts`
- `tests/api/poi-favorites-delete.integration.test.ts`
- 新增 `tests/api/poi-favorites-restore.integration.test.ts`
- API reference／OpenAPI 文件（若 repository 內有）

## 7. 必測案例

1. 建立含 note 的 favorite，DELETE 後不出現在 GET。
2. DELETE 後 10 分鐘內 restore，回同一 id，note／poiId／favoritedAt 完整保留。
3. restore 重送兩次都回 200，GET 最後只有一筆 active favorite。
4. 超過 10 分鐘 restore 回 `410 UNDO_EXPIRED`。
5. 非 owner 無法 DELETE 或 restore，回應不洩漏 row 內容。
6. DELETE 重送保持 204。
7. soft-deleted row 存在時重新 POST 收藏成功，不觸發 unique constraint 500。
8. active duplicate POST 仍回 409。
9. restore 與重新 POST 競速時，最後只有一筆 active row。
10. DELETE／restore 都寫 audit、清除 favorites GET cache，並通過既有 rate-limit／CSRF 測試。
11. 取消收藏不影響 POI、行程 entry、`trip_entry_pois` 或其他使用者的收藏。

## 8. Flutter 串接契約

後端完成後，Flutter 只需要：

```dart
Future<void> deleteFavorite(int favoriteId);
Future<PoiFavorite> restoreFavorite(int favoriteId);
```

Undo 流程：DELETE 成功後顯示 6 秒 `復原`；點擊時呼叫 restore endpoint，成功後 invalidate favorites provider。`410 UNDO_EXPIRED` 顯示「復原期限已過」，其他錯誤顯示「無法復原收藏，請稍後再試」。App 不再用 `poiId`／`note` 重送 `POST /poi-favorites`。

## 9. Definition of Done

- migration 可在 production D1 向前套用，且有 rollback／forward-fix 說明。
- 所有 active 查詢排除 deleted rows。
- 新舊收藏建立、刪除、restore 整合測試全部通過。
- 既有 API regression suite、typecheck、lint 全綠。
- API reference 更新並提供後端 commit SHA 給 Flutter 開發。
