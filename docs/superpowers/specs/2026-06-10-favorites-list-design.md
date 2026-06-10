# 設計:收藏清單(FavoritesScreen,favorites tab 轉正)

> 日期:2026-06-10
> 狀態:已批准設計,待寫 plan
> 來源任務:P1「收藏 + 探索」decompose 後的**第一個子專案** — 收藏清單(GET + DELETE)

## 背景

`/favorites` tab 目前是 `PlaceholderScreen('收藏')`。P1「收藏 + 探索」含 3 子系統(收藏清單 / 探索 ExplorePage / 加入行程),其中探索與加入行程的後端契約(`poi-search`、`pois/find-or-create`、`add-to-trip` body)在 `docs/discovery/` 未完整記錄。本子專案只做**契約完整**的收藏清單:`GET /api/poi-favorites` + `DELETE /api/poi-favorites/:id`。

## 目標 / 非目標

**目標**
- favorites tab 從 placeholder 轉成收藏 POI 清單(渲染 + 取消收藏)。
- 把 POI 類型→tone 的對應抽到共用位置(收藏與 timeline 共用)。
- 引入第一個「收藏 domain」的 read + delete mutation。

**非目標**
- 不做探索(ExplorePage / poi-search / find-or-create)。
- 不做加入行程(add-to-trip)。
- 不做「收藏新 POI」的入口(timeline entry 加 heart 等),屬探索子專案。

## A. 資料層

### Models(`lib/models/poi_favorite.dart`)

```
PoiFavorite:
  id: int (必)            userId: String (必)      poiId: int (必)
  favoritedAt: String (必) note: String?
  poiName: String?        poiAddress: String?      poiType: String?
  poiLat: double?         poiLng: double?          poiRating: double?
  usages: List<PoiFavoriteUsage>（預設 []）

PoiFavoriteUsage:
  tripId: String (必)     tripName: String (必)
  dayNum: int?            dayDate: String?         entryId: int?
```

- fromJson 遵循 `CONTRACTS.md`:數字 `(json['x'] as num?)?.toInt()/toDouble()`;`usages` = `(json['usages'] as List<dynamic>? ?? []).map(PoiFavoriteUsage.fromJson)`。
- 顯示名 fallback:`displayName => poiName ?? '未命名地點'`(getter)。

### Repository(`lib/api/favorites_repository.dart`)

```
class FavoritesRepository {
  FavoritesRepository({required ApiClient client});
  Future<List<PoiFavorite>> fetchFavorites();      // GET /poi-favorites
  Future<void> deleteFavorite(int id);             // DELETE /poi-favorites/:id
}
```

- 新 repository(非塞進 `TripRepository`)— 收藏是獨立的「跨 trip 收藏池」domain。
- `deleteFavorite` 走 `ApiClient.delete()`,mutation 自動帶 CSRF `Origin` header(已驗證行為)。

### Providers(`lib/features/favorites/favorites_providers.dart`)

```
favoritesRepositoryProvider = Provider((ref) =>
    FavoritesRepository(client: ref.watch(apiClientProvider)));
favoritesProvider = FutureProvider<List<PoiFavorite>>((ref) =>
    ref.watch(favoritesRepositoryProvider).fetchFavorites());
```

## B. UI(`lib/features/favorites/`)

### FavoritesScreen(`favorites_screen.dart`,ConsumerWidget)

- 替換 `router.dart` 的 `/favorites` → `FavoritesScreen()`(該處 `PlaceholderScreen` 移除;`PlaceholderScreen` 類別保留給聊天/全域地圖 branch)。
- AppBar「收藏」+ `favoritesAsync.when`:
  - **data 空** → empty hero:「還沒有收藏的地點」+ 副文案「探索並收藏喜歡的地點(即將推出)」。
  - **data 有** → `RefreshIndicator`(下拉 `ref.refresh(favoritesProvider.future)`)+ 單欄 `ListView.separated`(`PoiFavoriteCard`)。
  - **loading** → `Center(CircularProgressIndicator)`。
  - **error** → 文案 + 重試按鈕(`ref.invalidate(favoritesProvider)`),沿用 `TripsListScreen._ErrorState` 風格。

### PoiFavoriteCard(`poi_favorite_card.dart`,StatelessWidget)

- 參數:`favorite`、`onRemove`(VoidCallback)。
- 版面(沿用 hairline 卡片 + tone 色階,參考 `HotelCard`):
  - 左:poiType icon(tone bg 圓底);中:`displayName`(標題)+ meta(poiType tone deep 的分類字、rating 星+`toStringAsFixed(1)`、note、usages 摘要「用於 N 個行程」當 usages 非空);右:**filled heart icon(永遠粉 `tones.pink`,`design.md` 規範)**。
  - tone = `resolvePoiTone(tones, favorite.poiType)`(見 C 段)。
  - `ValueKey('favorite-card-${favorite.id}')`。
- heart 點擊 → `onRemove`,由 FavoritesScreen 處理:`AlertDialog`「取消收藏『{displayName}』?」→ 確認 → `deleteFavorite(id)` → `invalidate(favoritesProvider)`;失敗 → `SnackBar('取消收藏失敗,請稍後再試')`。取消對話框 → 不動作。

## C. tone 重構(POI 類型→tone 抽共用)

- **移檔 + 改名**:`lib/features/trip_detail/widgets/entry_tone.dart` → `lib/theme/poi_tone.dart`;`resolveEntryTone` → `resolvePoiTone`、`EntryToneColors` → `PoiToneColors`(函式邏輯不變:hotel/transport/parking→sage、restaurant→pink、其他/null→accent)。
- 連動更新:
  - `lib/features/trip_detail/widgets/timeline_entry_tile.dart`:import 改 `poi_tone.dart`;`resolveEntryTone`→`resolvePoiTone`、`EntryToneColors`→`PoiToneColors`(各 1-2 處)。
  - `test/features/trip_detail/widgets/entry_tone_test.dart` → `test/theme/poi_tone_test.dart`:import + 名稱更新(測試內容不變)。
  - `PoiFavoriteCard` import `poi_tone.dart` 用 `resolvePoiTone`。
- `timeline_entry_tile_test.dart` 不受影響(它測 widget 渲染,不直接呼叫 `resolveEntryTone`)。既有 timeline 測試持續綠 = 重構零回歸的保證。

## D. 測試(TDD)

| 檔案 | 測什麼 |
|---|---|
| `test/models/poi_favorite_test.dart` | `PoiFavorite`/`PoiFavoriteUsage` fromJson:完整欄位、nullable 缺漏、usages 巢狀 list、`displayName` fallback |
| `test/api/favorites_repository_test.dart` | `fetchFavorites`(GET /poi-favorites 解析 list,沿用 http_mock_adapter)、`deleteFavorite`(DELETE 204 視為成功) |
| `test/theme/poi_tone_test.dart`(移址後) | `resolvePoiTone` 三色對應(原 entry_tone_test 內容) |
| `test/features/favorites/favorites_screen_test.dart` | 清單渲染 N 卡、empty hero、error 重試;heart 點擊→AlertDialog→確認→`deleteFavorite` 被呼叫 + refresh(2 次 fetch);取消對話框→`verifyNever` delete |
| `test/features/favorites/poi_favorite_card_test.dart` | 欄位顯示(name/rating/note)、usages 摘要(有/無)、poiType tone、heart 點擊觸發 onRemove |

- mock 策略沿用既有:`FavoritesRepository` mock + `ProviderScope` override 或 `favoritesProvider.overrideWith`;error-state 測試帶 `ProviderScope(retry: (_, _) => null)`。

## E. Router / 文件 / 交付

- `lib/app/router.dart`:`/favorites` builder → `const FavoritesScreen()`。
- 文件:
  - `docs/reference-navigation.md`:favorites 由「P1 待實作」改為 `FavoritesScreen`。
  - `docs/reference-api.md`:加 `FavoritesRepository`(fetchFavorites/deleteFavorite)。
  - `TODOS.md`:① 把「收藏 + 探索」P1 項改為「收藏清單 ✓(子專案)/ 探索 + 加入行程待續」;② **順手勾掉技術債「`git tag v0.1.0`」**(tag 實際已於 2026-06-10 完成 + push)。
  - `CHANGELOG.md`:Unreleased 記錄收藏清單。
- 分支 `feat/favorites-list`;全程 TDD;`flutter analyze` + `flutter test` 全綠;開一個 PR。

## 風險

1. **空收藏無法在 app 內驗證有資料的狀態** — 此 app 目前無「新增收藏」入口(屬探索子專案)。有資料的渲染靠 widget test(mock)涵蓋;真機可能顯示 empty(除非帳號在 web 已收藏過)。可接受。
2. **`/poi-favorites` 實際 wire shape 若與 discovery 記錄有出入** — fromJson 寫寬鬆(全 nullable except id/userId/poiId/favoritedAt),降低風險;真打 prod 驗證列為後續(避免 brainstorm 階段亂打 prod)。

## 驗收條件

- [ ] `flutter analyze` 0 issues。
- [ ] `flutter test` 全綠(既有 + 新增;tone 重構零回歸)。
- [ ] favorites tab 顯示收藏清單(mock 驗證渲染 + heart 取消收藏流程)。
- [ ] `resolvePoiTone` 移共用,timeline 既有測試持續綠。
- [ ] reference-navigation / reference-api / TODOS(含 git tag 勾選)/ CHANGELOG 更新。
