# 收藏清單(FavoritesScreen)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** favorites tab 從 placeholder 轉成收藏 POI 清單(`GET /poi-favorites` 渲染 + heart 取消收藏 `DELETE`)。

**Architecture:** 新 `PoiFavorite` model + `FavoritesRepository` + riverpod providers;`FavoritesScreen`/`PoiFavoriteCard` 沿用 `TripsListScreen`/`HotelCard` 既有 pattern;POI 類型→tone 對應抽到共用 `lib/theme/poi_tone.dart`(收藏與 timeline 共用)。

**Tech Stack:** Flutter 3.43、flutter_riverpod 3.x、go_router 17.x、dio + http_mock_adapter、mocktail。

---

## 重要慣例

- **TDD**:Task 2/3/5/6 為真 TDD(test red → impl green);Task 1 為重構(既有 test 持續綠 = 零回歸);Task 4/7/8 含 analyze/全套驗證。
- **Commit trailer**:每個 commit message 結尾空一行後加
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **mocktail**:`any()` 用於 `int`/`String` 等 primitive 無需 `registerFallbackValue`。
- **flutter_riverpod 3.x**:`Override` 型別未匯出,overrides 以 list literal inline 傳入 `ProviderScope`;error-state 測試帶 `ProviderScope(retry: (retryCount, error) => null)`。

## 前置條件

- branch `feat/favorites-list`(spec 已 commit)。
- 起點全綠:`flutter test`(應 173 passed)。

## File Structure

| 檔案 | 責任 | 動作 |
|---|---|---|
| `lib/theme/poi_tone.dart` | POI 類型→tone(`resolvePoiTone`/`PoiToneColors`) | 建立(Task 1,移自 entry_tone) |
| `lib/features/trip_detail/widgets/entry_tone.dart` | (移除) | 刪除(Task 1) |
| `lib/features/trip_detail/widgets/timeline_entry_tile.dart` | timeline tile | 修改 import/名稱(Task 1) |
| `test/theme/poi_tone_test.dart` | `resolvePoiTone` 測試 | 建立(Task 1,移自 entry_tone_test) |
| `test/features/trip_detail/widgets/entry_tone_test.dart` | (移除) | 刪除(Task 1) |
| `lib/models/poi_favorite.dart` | `PoiFavorite`/`PoiFavoriteUsage` | 建立(Task 2) |
| `lib/api/favorites_repository.dart` | GET/DELETE poi-favorites | 建立(Task 3) |
| `lib/features/favorites/favorites_providers.dart` | repo + list provider | 建立(Task 4) |
| `lib/features/favorites/poi_favorite_card.dart` | 收藏卡片 | 建立(Task 5) |
| `lib/features/favorites/favorites_screen.dart` | 收藏清單畫面 | 建立(Task 6) |
| `lib/app/router.dart` | `/favorites` 接線 | 修改(Task 7) |
| `docs/*` `TODOS.md` `CHANGELOG.md` | 文件 | 修改(Task 8) |

---

## Task 1: tone 重構(entry_tone → 共用 poi_tone,移檔+改名)

**Files:**
- Create: `lib/theme/poi_tone.dart`
- Delete: `lib/features/trip_detail/widgets/entry_tone.dart`
- Modify: `lib/features/trip_detail/widgets/timeline_entry_tile.dart`(import + 2 處名稱)
- Create: `test/theme/poi_tone_test.dart`
- Delete: `test/features/trip_detail/widgets/entry_tone_test.dart`

- [ ] **Step 1: 建 `lib/theme/poi_tone.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 單一 tone 的 4 階色組（base/deep/subtle/bg），供 POI 元件套色階梯：
/// 卡底 subtle → icon 底 bg → glyph/圓點 deep。
class PoiToneColors {
  const PoiToneColors({
    required this.base,
    required this.deep,
    required this.subtle,
    required this.bg,
  });

  final Color base;
  final Color deep;
  final Color subtle;
  final Color bg;
}

/// poi_type → 三色 tone：玩/看/買=accent、住/移動=sage、吃=pink；未分類視同 accent。
PoiToneColors resolvePoiTone(TpTones tones, String? poiType) {
  switch (poiType) {
    case 'hotel':
    case 'transport':
    case 'parking':
      return PoiToneColors(
        base: tones.sage,
        deep: tones.sageDeep,
        subtle: tones.sageSubtle,
        bg: tones.sageBg,
      );
    case 'restaurant':
      return PoiToneColors(
        base: tones.pink,
        deep: tones.pinkDeep,
        subtle: tones.pinkSubtle,
        bg: tones.pinkBg,
      );
    default:
      return PoiToneColors(
        base: tones.accent,
        deep: tones.accentDeep,
        subtle: tones.accentSubtle,
        bg: tones.accentBg,
      );
  }
}
```

- [ ] **Step 2: 刪除 `lib/features/trip_detail/widgets/entry_tone.dart`**

Run: `git rm lib/features/trip_detail/widgets/entry_tone.dart`(刪除 + stage)

- [ ] **Step 3: 更新 `timeline_entry_tile.dart`**(3 處)

import(原 `import 'entry_tone.dart';`)改為:
```dart
import '../../../theme/poi_tone.dart';
```
`build()` 內(原 `final tone = resolveEntryTone(tones, entry.master?.type);`)改為:
```dart
    final tone = resolvePoiTone(tones, entry.master?.type);
```
`_EntryCard` 欄位(原 `final EntryToneColors tone;`)改為:
```dart
  final PoiToneColors tone;
```

- [ ] **Step 4: 建 `test/theme/poi_tone_test.dart`**(= 原 entry_tone_test 改名)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/theme/poi_tone.dart';
import 'package:tripline/theme/app_theme.dart';

void main() {
  const tones = TpTones.light;

  void expectTone(
    PoiToneColors actual, {
    required Color base,
    required Color deep,
    required Color subtle,
    required Color bg,
  }) {
    expect(actual.base, base);
    expect(actual.deep, deep);
    expect(actual.subtle, subtle);
    expect(actual.bg, bg);
  }

  group('resolvePoiTone', () {
    test('hotel / transport / parking → sage', () {
      for (final poiType in ['hotel', 'transport', 'parking']) {
        expectTone(
          resolvePoiTone(tones, poiType),
          base: tones.sage,
          deep: tones.sageDeep,
          subtle: tones.sageSubtle,
          bg: tones.sageBg,
        );
      }
    });

    test('restaurant → pink', () {
      expectTone(
        resolvePoiTone(tones, 'restaurant'),
        base: tones.pink,
        deep: tones.pinkDeep,
        subtle: tones.pinkSubtle,
        bg: tones.pinkBg,
      );
    });

    test('其他類型與 null → accent', () {
      for (final poiType in [null, 'attraction', 'shopping', 'activity']) {
        expectTone(
          resolvePoiTone(tones, poiType),
          base: tones.accent,
          deep: tones.accentDeep,
          subtle: tones.accentSubtle,
          bg: tones.accentBg,
        );
      }
    });
  });
}
```

- [ ] **Step 5: 刪除舊 test**

Run: `git rm test/features/trip_detail/widgets/entry_tone_test.dart`(刪除 + stage)

- [ ] **Step 6: run 確認零回歸**

Run: `flutter test test/theme/poi_tone_test.dart test/features/trip_detail/widgets/timeline_entry_tile_test.dart`
Expected: PASS(timeline 既有測試證明重構無破壞)

- [ ] **Step 7: Commit**

```bash
# git rm 已 stage 兩個刪除（Step 2/5），這裡只需 add 新檔/改檔
git add lib/theme/poi_tone.dart test/theme/poi_tone_test.dart lib/features/trip_detail/widgets/timeline_entry_tile.dart
git commit -m "refactor: POI tone 對應抽到共用 lib/theme/poi_tone.dart" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `PoiFavorite` / `PoiFavoriteUsage` models

**Files:**
- Create: `test/models/poi_favorite_test.dart`
- Create: `lib/models/poi_favorite.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_favorite.dart';

void main() {
  group('PoiFavorite.fromJson', () {
    test('完整欄位 + usages 巢狀', () {
      final favorite = PoiFavorite.fromJson({
        'id': 7,
        'userId': 'u-1',
        'poiId': 501,
        'favoritedAt': '2026-06-01T10:00:00Z',
        'note': '想吃',
        'poiName': '首里城',
        'poiAddress': '那霸市',
        'poiType': 'attraction',
        'poiLat': 26.21,
        'poiLng': 127.71,
        'poiRating': 4.4,
        'usages': [
          {
            'tripId': 'okinawa',
            'tripName': '沖繩',
            'dayNum': 1,
            'dayDate': '2026-06-10',
            'entryId': 101,
          },
        ],
      });
      expect(favorite.id, 7);
      expect(favorite.poiId, 501);
      expect(favorite.poiName, '首里城');
      expect(favorite.poiRating, 4.4);
      expect(favorite.usages.single.tripName, '沖繩');
      expect(favorite.usages.single.dayNum, 1);
    });

    test('nullable 缺漏 + usages 缺省為空 + displayName fallback', () {
      final favorite = PoiFavorite.fromJson({
        'id': 8,
        'userId': 'u-1',
        'poiId': 502,
        'favoritedAt': '2026-06-02T10:00:00Z',
      });
      expect(favorite.note, isNull);
      expect(favorite.poiName, isNull);
      expect(favorite.poiRating, isNull);
      expect(favorite.usages, isEmpty);
      expect(favorite.displayName, '未命名地點');
    });

    test('displayName 用 poiName', () {
      final favorite = PoiFavorite.fromJson({
        'id': 9,
        'userId': 'u-1',
        'poiId': 503,
        'favoritedAt': '2026-06-03T10:00:00Z',
        'poiName': '美麗海水族館',
      });
      expect(favorite.displayName, '美麗海水族館');
    });
  });
}
```

- [ ] **Step 2: run 確認 fail**

Run: `flutter test test/models/poi_favorite_test.dart`
Expected: FAIL(`poi_favorite.dart` 不存在,compile error)

- [ ] **Step 3: 建 `lib/models/poi_favorite.dart`**

```dart
/// 收藏 models（`GET /api/poi-favorites`，跨 trip 收藏池）。
library;

/// POI 收藏在某行程的使用紀錄（反查 hotel_poi_id ∪ trip_entry_pois）。
class PoiFavoriteUsage {
  const PoiFavoriteUsage({
    required this.tripId,
    required this.tripName,
    this.dayNum,
    this.dayDate,
    this.entryId,
  });

  final String tripId;
  final String tripName;
  final int? dayNum;
  final String? dayDate;
  final int? entryId;

  factory PoiFavoriteUsage.fromJson(Map<String, dynamic> json) {
    return PoiFavoriteUsage(
      tripId: json['tripId'] as String,
      tripName: json['tripName'] as String,
      dayNum: (json['dayNum'] as num?)?.toInt(),
      dayDate: json['dayDate'] as String?,
      entryId: (json['entryId'] as num?)?.toInt(),
    );
  }
}

/// 一筆 POI 收藏（含 JOIN pois 的展示欄位與 usages）。
class PoiFavorite {
  const PoiFavorite({
    required this.id,
    required this.userId,
    required this.poiId,
    required this.favoritedAt,
    this.note,
    this.poiName,
    this.poiAddress,
    this.poiType,
    this.poiLat,
    this.poiLng,
    this.poiRating,
    this.usages = const [],
  });

  final int id;
  final String userId;
  final int poiId;
  final String favoritedAt;
  final String? note;
  final String? poiName;
  final String? poiAddress;
  final String? poiType;
  final double? poiLat;
  final double? poiLng;
  final double? poiRating;
  final List<PoiFavoriteUsage> usages;

  /// 顯示名 fallback：poiName → '未命名地點'。
  String get displayName => poiName ?? '未命名地點';

  factory PoiFavorite.fromJson(Map<String, dynamic> json) {
    return PoiFavorite(
      id: (json['id'] as num).toInt(),
      userId: json['userId'] as String,
      poiId: (json['poiId'] as num).toInt(),
      favoritedAt: json['favoritedAt'] as String,
      note: json['note'] as String?,
      poiName: json['poiName'] as String?,
      poiAddress: json['poiAddress'] as String?,
      poiType: json['poiType'] as String?,
      poiLat: (json['poiLat'] as num?)?.toDouble(),
      poiLng: (json['poiLng'] as num?)?.toDouble(),
      poiRating: (json['poiRating'] as num?)?.toDouble(),
      usages: (json['usages'] as List<dynamic>? ?? [])
          .map((usageJson) =>
              PoiFavoriteUsage.fromJson(usageJson as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

- [ ] **Step 4: run 確認 pass**

Run: `flutter test test/models/poi_favorite_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/poi_favorite.dart test/models/poi_favorite_test.dart
git commit -m "feat: PoiFavorite / PoiFavoriteUsage models" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `FavoritesRepository`

**Files:**
- Create: `test/api/favorites_repository_test.dart`
- Create: `lib/api/favorites_repository.dart`

- [ ] **Step 1: 寫測試**(沿用 `trip_repository_test.dart` 的 DioAdapter pattern)

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tripline/api/api_client.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/api/session_store.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late FavoritesRepository favoritesRepository;

  setUp(() {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    final apiClient = ApiClient(sessionStore: InMemorySessionStore(), dio: dio);
    favoritesRepository = FavoritesRepository(client: apiClient);
  });

  test('fetchFavorites：GET /poi-favorites 解析 PoiFavorite list', () async {
    dioAdapter.onGet(
      '/poi-favorites',
      (server) => server.reply(200, [
        {
          'id': 7,
          'userId': 'u-1',
          'poiId': 501,
          'favoritedAt': '2026-06-01T10:00:00Z',
          'poiName': '首里城',
          'poiType': 'attraction',
          'poiRating': 4.4,
          'usages': [
            {'tripId': 'okinawa', 'tripName': '沖繩', 'dayNum': 1},
          ],
        },
      ]),
    );

    final favorites = await favoritesRepository.fetchFavorites();

    expect(favorites, hasLength(1));
    expect(favorites.single.poiName, '首里城');
    expect(favorites.single.usages.single.tripName, '沖繩');
  });

  test('deleteFavorite：DELETE /poi-favorites/:id（204 視為成功）', () async {
    dioAdapter.onDelete(
      '/poi-favorites/7',
      (server) => server.reply(204, null),
    );

    await expectLater(favoritesRepository.deleteFavorite(7), completes);
  });
}
```

- [ ] **Step 2: run 確認 fail**

Run: `flutter test test/api/favorites_repository_test.dart`
Expected: FAIL(`favorites_repository.dart` 不存在)

- [ ] **Step 3: 建 `lib/api/favorites_repository.dart`**

```dart
/// 收藏 repository：跨 trip 收藏池（`/api/poi-favorites`）。
library;

import '../models/poi_favorite.dart';
import 'api_client.dart';

/// 對應 `/api/poi-favorites`。
class FavoritesRepository {
  FavoritesRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// GET /poi-favorites。
  Future<List<PoiFavorite>> fetchFavorites() async {
    final responseBody = await _client.get('/poi-favorites');
    return (responseBody as List<dynamic>)
        .map((favoriteJson) =>
            PoiFavorite.fromJson(favoriteJson as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /poi-favorites/:id（mutation，ApiClient 自動帶 CSRF Origin）。
  Future<void> deleteFavorite(int id) => _client.delete('/poi-favorites/$id');
}
```

- [ ] **Step 4: run 確認 pass**

Run: `flutter test test/api/favorites_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/api/favorites_repository.dart test/api/favorites_repository_test.dart
git commit -m "feat: FavoritesRepository（GET / DELETE poi-favorites）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: favorites providers

**Files:**
- Create: `lib/features/favorites/favorites_providers.dart`

說明:組裝 code,無獨立 unit test(由 Task 6 widget test override 覆蓋)。本 task 以 `flutter analyze` 確認編譯。

- [ ] **Step 1: 建 `lib/features/favorites/favorites_providers.dart`**

```dart
/// 收藏 feature providers。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/favorites_repository.dart';
import '../../api/providers.dart';
import '../../models/poi_favorite.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(client: ref.watch(apiClientProvider)),
);

/// 收藏清單（本畫面專屬 scope；取消收藏後 invalidate refresh）。
final favoritesProvider = FutureProvider<List<PoiFavorite>>(
  (ref) => ref.watch(favoritesRepositoryProvider).fetchFavorites(),
);
```

- [ ] **Step 2: analyze 確認編譯**

Run: `flutter analyze lib/features/favorites/favorites_providers.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/favorites/favorites_providers.dart
git commit -m "feat: favorites providers（repository + list）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `PoiFavoriteCard`

**Files:**
- Create: `test/features/favorites/poi_favorite_card_test.dart`
- Create: `lib/features/favorites/poi_favorite_card.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/features/favorites/poi_favorite_card.dart';
import 'package:tripline/theme/app_theme.dart';

Future<void> pumpCard(
  WidgetTester tester,
  PoiFavorite favorite, {
  VoidCallback? onRemove,
}) {
  return tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: PoiFavoriteCard(favorite: favorite, onRemove: onRemove ?? () {}),
    ),
  ));
}

const _favorite = PoiFavorite(
  id: 7,
  userId: 'u-1',
  poiId: 501,
  favoritedAt: '2026-06-01T10:00:00Z',
  note: '想去',
  poiName: '美麗海水族館',
  poiType: 'attraction',
  poiRating: 4.6,
  usages: [
    PoiFavoriteUsage(tripId: 'okinawa', tripName: '沖繩', dayNum: 1),
    PoiFavoriteUsage(tripId: 'kyoto', tripName: '京都'),
  ],
);

void main() {
  group('PoiFavoriteCard', () {
    testWidgets('顯示名稱、評分、note、usages 摘要、ValueKey', (tester) async {
      await pumpCard(tester, _favorite);
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('想去'), findsOneWidget);
      expect(find.text('用於 2 個行程'), findsOneWidget);
      expect(find.byKey(const ValueKey('favorite-card-7')), findsOneWidget);
    });

    testWidgets('usages 空 → 不顯示行程摘要', (tester) async {
      await pumpCard(
        tester,
        const PoiFavorite(
          id: 8,
          userId: 'u-1',
          poiId: 502,
          favoritedAt: '2026-06-02T10:00:00Z',
          poiName: '無人地點',
        ),
      );
      expect(find.text('無人地點'), findsOneWidget);
      expect(find.textContaining('用於'), findsNothing);
    });

    testWidgets('點 heart → onRemove 被呼叫', (tester) async {
      var removed = 0;
      await pumpCard(tester, _favorite, onRemove: () => removed++);
      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      expect(removed, 1);
    });
  });
}
```

- [ ] **Step 2: run 確認 fail**

Run: `flutter test test/features/favorites/poi_favorite_card_test.dart`
Expected: FAIL(`poi_favorite_card.dart` 不存在)

- [ ] **Step 3: 建 `lib/features/favorites/poi_favorite_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../../models/poi_favorite.dart';
import '../../theme/app_theme.dart';
import '../../theme/poi_tone.dart';
import '../../theme/tokens.dart';

/// 收藏 POI 卡片：poiType tone 色階 + rating/note/usages + 取消收藏 heart（永遠粉）。
class PoiFavoriteCard extends StatelessWidget {
  const PoiFavoriteCard({
    super.key,
    required this.favorite,
    required this.onRemove,
  });

  final PoiFavorite favorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = theme.extension<TpTones>()!;
    final tone = resolvePoiTone(tones, favorite.poiType);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      key: ValueKey('favorite-card-${favorite.id}'),
      padding: const EdgeInsets.all(TpSpacing.s3),
      decoration: BoxDecoration(
        color: tone.subtle,
        borderRadius: BorderRadius.circular(TpRadius.md),
        border: Border.all(color: tone.bg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.bg,
              borderRadius: BorderRadius.circular(TpRadius.md),
            ),
            child: Icon(Icons.place_outlined, size: 20, color: tone.deep),
          ),
          const SizedBox(width: TpSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  favorite.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (favorite.poiRating != null)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: tones.accent),
                        const SizedBox(width: 2),
                        Text(
                          favorite.poiRating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: mutedColor,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (favorite.note != null && favorite.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Text(
                      favorite.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: mutedColor),
                    ),
                  ),
                if (favorite.usages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: TpSpacing.s1),
                    child: Text(
                      '用於 ${favorite.usages.length} 個行程',
                      style: TextStyle(fontSize: 12, color: tone.deep),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('favorite-remove-${favorite.id}'),
            tooltip: '取消收藏',
            icon: Icon(Icons.favorite, color: tones.pink),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: run 確認 pass**

Run: `flutter test test/features/favorites/poi_favorite_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/favorites/poi_favorite_card.dart test/features/favorites/poi_favorite_card_test.dart
git commit -m "feat: PoiFavoriteCard（tone 色階 + rating/note/usages + heart）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: `FavoritesScreen`

**Files:**
- Create: `test/features/favorites/favorites_screen_test.dart`
- Create: `lib/features/favorites/favorites_screen.dart`

- [ ] **Step 1: 寫測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tripline/api/favorites_repository.dart';
import 'package:tripline/features/favorites/favorites_providers.dart';
import 'package:tripline/features/favorites/favorites_screen.dart';
import 'package:tripline/features/favorites/poi_favorite_card.dart';
import 'package:tripline/models/poi_favorite.dart';
import 'package:tripline/theme/app_theme.dart';

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

const _favorites = [
  PoiFavorite(
    id: 7,
    userId: 'u-1',
    poiId: 501,
    favoritedAt: '2026-06-01T10:00:00Z',
    poiName: '美麗海水族館',
    poiType: 'attraction',
    poiRating: 4.6,
  ),
  PoiFavorite(
    id: 8,
    userId: 'u-1',
    poiId: 502,
    favoritedAt: '2026-06-02T10:00:00Z',
    poiName: '暖暮拉麵',
    poiType: 'restaurant',
  ),
];

Widget buildApp() => MaterialApp(
      theme: AppTheme.light(),
      home: const FavoritesScreen(),
    );

void main() {
  group('FavoritesScreen', () {
    testWidgets('渲染收藏清單 N 卡', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          favoritesProvider.overrideWith((ref) async => _favorites),
        ],
        child: buildApp(),
      ));
      await tester.pump();

      expect(find.text('收藏'), findsOneWidget); // AppBar
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
      expect(find.text('美麗海水族館'), findsOneWidget);
      expect(find.text('暖暮拉麵'), findsOneWidget);
    });

    testWidgets('empty → 還沒有收藏 hero', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          favoritesProvider.overrideWith((ref) async => const <PoiFavorite>[]),
        ],
        child: buildApp(),
      ));
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsNothing);
      expect(find.text('還沒有收藏的地點'), findsOneWidget);
    });

    testWidgets('error → 重試後成功', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          favoritesProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) throw Exception('network');
            return _favorites;
          }),
        ],
        child: buildApp(),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('重試'), findsOneWidget);
      await tester.tap(find.text('重試'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));
    });

    testWidgets('heart → 確認對話框 → deleteFavorite + refresh', (tester) async {
      final mockRepo = MockFavoritesRepository();
      var fetchCount = 0;
      when(mockRepo.fetchFavorites).thenAnswer((_) async {
        fetchCount++;
        return _favorites;
      });
      when(() => mockRepo.deleteFavorite(any())).thenAnswer((_) async {});

      await tester.pumpWidget(ProviderScope(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: buildApp(),
      ));
      await tester.pump();
      expect(find.byType(PoiFavoriteCard), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('移除'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteFavorite(7)).called(1);
      expect(fetchCount, 2); // 初載 + 刪除後 invalidate refresh
    });

    testWidgets('heart → 對話框「保留」→ 不刪除', (tester) async {
      final mockRepo = MockFavoritesRepository();
      when(mockRepo.fetchFavorites).thenAnswer((_) async => _favorites);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: buildApp(),
      ));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('favorite-remove-7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保留'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => mockRepo.deleteFavorite(any()));
    });
  });
}
```

- [ ] **Step 2: run 確認 fail**

Run: `flutter test test/features/favorites/favorites_screen_test.dart`
Expected: FAIL(`favorites_screen.dart` 不存在)

- [ ] **Step 3: 建 `lib/features/favorites/favorites_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/poi_favorite.dart';
import '../../theme/tokens.dart';
import 'favorites_providers.dart';
import 'poi_favorite_card.dart';

/// 收藏清單（5-tab「收藏」分頁）：GET /poi-favorites，heart 取消收藏（確認對話框）。
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('收藏')),
      body: favoritesAsync.when(
        data: (favorites) => RefreshIndicator(
          onRefresh: () => ref.refresh(favoritesProvider.future),
          child: favorites.isEmpty
              ? const _EmptyHero()
              : _buildList(context, ref, favorites),
        ),
        error: (error, stackTrace) => _ErrorState(
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<PoiFavorite> favorites,
  ) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TpSpacing.s4),
      itemCount: favorites.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: TpSpacing.s3),
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return PoiFavoriteCard(
          favorite: favorite,
          onRemove: () => _confirmRemove(context, ref, favorite),
        );
      },
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    PoiFavorite favorite,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('確定要移除「${favorite.displayName}」嗎?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(favoritesRepositoryProvider).deleteFavorite(favorite.id);
      ref.invalidate(favoritesProvider);
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('取消收藏失敗，請稍後再試')),
      );
    }
  }
}

/// 空清單 hero 文案。
class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('還沒有收藏的地點', style: theme.textTheme.titleLarge),
                const SizedBox(height: TpSpacing.s2),
                Text(
                  '探索並收藏喜歡的地點（即將推出）。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 載入失敗：文案 + 重試。
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('載入失敗', style: theme.textTheme.titleMedium),
          const SizedBox(height: TpSpacing.s2),
          Text(
            '無法取得收藏清單，請檢查網路後再試一次。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: TpSpacing.s4),
          FilledButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: run 確認 pass**

Run: `flutter test test/features/favorites/favorites_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/favorites/favorites_screen.dart test/features/favorites/favorites_screen_test.dart
git commit -m "feat: FavoritesScreen（清單 / empty / error / heart 取消收藏）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: router 接線

**Files:**
- Modify: `lib/app/router.dart`(`/favorites` branch + import)

- [ ] **Step 1: 改 router**

在 `lib/app/router.dart` 頂部 import 區加(對齊既有 `../features/...` import 順序):
```dart
import '../features/favorites/favorites_screen.dart';
```
把 `/favorites` 的 `GoRoute`(原 `builder: (context, state) => const PlaceholderScreen(title: '收藏'),`)改為:
```dart
              GoRoute(
                path: '/favorites',
                builder: (context, state) => const FavoritesScreen(),
              ),
```
(保留 `PlaceholderScreen` import — 聊天/全域地圖 branch 仍用)

- [ ] **Step 2: run 全套確認無回歸**

Run: `flutter test`
Expected: PASS。既有 `app_smoke_test`/`router_test`/`flow` 不進 favorites branch(StatefulShellRoute.indexedStack lazy build),故不觸發 `favoritesProvider`、不打 prod。

- [ ] **Step 3: Commit**

```bash
git add lib/app/router.dart
git commit -m "feat: /favorites tab 接 FavoritesScreen（取代 placeholder）" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 文件 + 驗收

**Files:**
- Modify: `docs/reference-navigation.md`、`docs/reference-api.md`、`TODOS.md`、`CHANGELOG.md`

- [ ] **Step 1: analyze**

Run: `flutter analyze`
Expected: `No issues found!`(若有 unused import / 順序問題逐一修)

- [ ] **Step 2: 全套 test**

Run: `flutter test`
Expected: 全綠。新增約 13 測試(model 3 + repo 2 + card 3 + screen 5);tone 重構 test 數不變(移址)。記下實際 passed 數。

- [ ] **Step 3: 更新文件**(executing 時先讀各檔當前內容再 Edit,對齊實際格式)

`docs/reference-navigation.md`:`/favorites` 行由「`PlaceholderScreen('收藏')` | tab 4(P1 待實作)」改為「`FavoritesScreen` | tab 4(收藏清單)」。

`docs/reference-api.md`:在 repository 區塊加 `FavoritesRepository`:
```
Future<List<PoiFavorite>> fetchFavorites();   // GET /poi-favorites
Future<void>              deleteFavorite(int); // DELETE /poi-favorites/:id
```

`TODOS.md`:
- P1 區「收藏 + 探索」項改為:
  `- [ ] 探索 + 加入行程（ExplorePage poi-search/find-or-create、add-to-trip;**收藏清單已於 2026-06-10 完成**）`
- 技術債區「`git tag v0.1.0`」項由 `[ ]` 改 `[x]` 並加 `（**Completed:** 2026-06-10）`(tag 實際已打+push)。

`CHANGELOG.md` `## [Unreleased]` 的 `### 新增` 加:
```
- **收藏清單**:favorites tab 轉正 — `GET /poi-favorites` 渲染（名稱/類型 tone/評分/note/用於 N 個行程）+ heart 取消收藏（確認對話框 → `DELETE`）。POI 類型→tone 對應抽到共用 `lib/theme/poi_tone.dart`。
```

- [ ] **Step 4: Commit**

```bash
git add docs/reference-navigation.md docs/reference-api.md TODOS.md CHANGELOG.md
git commit -m "docs: 收藏清單文件更新 + 勾除 git tag 技術債" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: 交付**

- `git push -u origin feat/favorites-list`
- 開 PR(或交由 finishing-a-development-branch)。PR 描述含:`flutter test` passed 數、`flutter analyze` 結果、收藏清單範圍(GET+DELETE,探索/加入行程後續)。

---

## 驗收條件(對照 spec)

- [ ] `flutter analyze` 0 issues。
- [ ] `flutter test` 全綠(既有 + 新增;tone 重構零回歸)。
- [ ] favorites tab 顯示收藏清單(渲染 + heart 取消收藏流程,mock 驗證)。
- [ ] `resolvePoiTone` 移共用,timeline 既有測試持續綠。
- [ ] reference-navigation / reference-api / TODOS(含 git tag 勾選)/ CHANGELOG 更新。
