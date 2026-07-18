# Tripline HIG Navigation and Sheet Semantics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Tripline root page, detail page, bottom sheet, itinerary Timeline, movement workflow, compact navigation capsule, and map interaction use the correct HIG semantics and one shared implementation source for its role, including a fixed full-width Root Glass Header and clickable native Google POIs.

**Architecture:** Keep `liquid_glass_widgets` and `lib/app/adaptive.dart` as the single material/presentation boundaries. Replace Root `SliverAppBar` and feature-owned app bars with one full-bleed `TpRootScaffold` that overlays a fixed `TpRootGlassHeader`; keep role-aware `TpAppBar` only for detail routes and sheet navigation. Replace generic large-sheet functions with one private engine plus semantic wrappers, and migrate call sites by task type. Keep `AppleRootTabBar` and `TpHorizontalSelector` semantically separate while sharing one compact-navigation glass recipe. Convert the itinerary to one native section-linked `CustomScrollView` with adaptive rows and explicit movement semantics. Replace `google_maps_flutter` with mobile-only `google_navigation_flutter` behind an app-owned `TripMapController`/canvas boundary, preserve Tripline markers, routes, clustering, zoom 12, and accessories, and add native Google POI selection plus Universal URL external opening. Use a web external-map fallback instead of retaining a second embedded Google Maps SDK. This is a whole-plan structural refactor: remove duplicate compatibility paths after migration, while preserving product behavior, accessibility, and tests. The only planned API change is the owner-scoped favorite restore contract in `docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, `liquid_glass_widgets`, `google_navigation_flutter ^0.10.0`, `url_launcher`, Flutter widget tests, Mocktail.

## Global Constraints

- This constraint applies to the entire plan: optimize for the correct shared architecture, not the smallest diff. The implementation may reorganize Root Shell, Header, Sheet, compact navigation, Timeline, map adapter, and tests when that removes duplicate ownership or package leakage.
- Preserve user-visible workflows, deep links, accessibility, and rollback behavior. Preserve API/data contracts except for the explicitly approved favorite soft-delete/restore endpoint. Remove old compatibility-only widgets and adapters once all consumers migrate; do not keep two production paths “temporarily” without a dated removal gate.
- Root destinations (`聊天`, `行程`, `地圖`, `收藏`) show neither Back nor Close.
- All four Root destinations use one fixed, full-width `TpRootGlassHeader` over full-bleed content. Root pages do not build `AppBar`, `SliverAppBar`, `GlassAppBar`, or a second page-specific header surface.
- Chat, itinerary content, and map root headers show the current trip title as a trip-selection control. Favorites shows `收藏`; the no-selected-trip list fallback shows `我的行程`.
- Root header icon actions are 44×44pt; text actions use intrinsic width with a 44pt minimum height. All actions use an 8pt gap and 16pt outer inset. General Root pages expose at most two trailing actions; Favorites may show search, sort, add, and account together because its fixed two-character title leaves enough measured width, and must pass the 200% Dynamic Type layout test.
- Back moves one level within the current navigation hierarchy; it never dismisses the whole sheet.
- Close dismisses a content sheet and returns to the covered screen.
- Selection sheets use leading `取消`, no `完成`, current-value checkmark, and immediate selection.
- Form sheets use leading `取消` and trailing `完成` or a specific verb; dirty forms intercept Cancel, barrier dismiss, swipe down, and system back.
- A content-sheet child may show leading Back and trailing Close; it must not also show Done.
- The trip-level command is named `調整順序`, not `編輯行程` or `移動行程`; it enters a reorder mode and uses `CupertinoIcons.line_horizontal_3`.
- The item-level command is named `移到其他 Day`; it uses the HIG Move To symbol `CupertinoIcons.folder` as a direct 44pt button with tooltip and accessibility label, never as an unlabeled compact button.
- Reorder mode keeps the drag handle and the explicit Move To Day command. Drag is not the only way to move an item.
- Reorder mode changes the Header task title to `調整順序` and exposes the complete text `完成` directly in the trailing app bar; the text action has intrinsic width with a 44pt minimum height and must never be constrained to the 44pt square icon slot or truncate to `完`.
- `移到其他 Day` uses a direct `folder` inline action because it is the only command in its current ellipsis menu. It and the `line_horizontal_3` drag handle share one 44pt inline-control geometry, foreground, pressed state, tooltip, and semantics; the drag gesture remains distinct.
- Toolbar, row-menu, Back, Close, Cancel, Done, and drag controls use a minimum `44x44 pt` hit region and an explicit accessibility label.
- The trip More menu may contain `調整順序`; `移到其他 Day` stays scoped to the selected itinerary entry and never appears as a trip-level command.
- `TpMoreMenuButton` normal rows use Light `colorScheme.onSurface` and Dark `colorScheme.primary`; destructive rows use `colorScheme.error`. A selected menu item replaces its leading icon with a checkmark.
- Fixed-height sheets do not show a resize grabber. Resizable sheets use distinct `0.62` medium and `0.93` large detents.
- All bottom-up presentations route through `lib/app/adaptive.dart`; `lib/features/**` must not call `showModalBottomSheet`, `showCupertinoModalPopup`, or `showGeneralDialog` directly.
- Reuse the installed `liquid_glass_widgets` package. The only new production dependency in this plan is `google_navigation_flutter ^0.10.0`, replacing `google_maps_flutter`; do not keep both Google Maps packages.
- Keep current warm-light and neutral-dark Tripline colors; this plan changes navigation semantics, not the color system.
- Root Tab and the itinerary/map Day selector use one compact-navigation glass recipe; they do not duplicate `LiquidGlassSettings` values.
- `platformViewBackdrop` changes only the Google Map rendering path, not navigation blur, thickness, refraction, light intensity, or opacity.
- Root Tab selection and Day selection use one translucent `navigationSelection` tint; selected indicators do not introduce another blur or refractive-index recipe.
- POI accessories, sheets, menus, and content cards keep their size-appropriate glass recipes and do not reuse compact-navigation optics.
- Mobile map rendering uses `GoogleMapsMapView`, never initializes a navigation session, and never exposes plugin types above the map renderer boundary.
- Raise Android `minSdk` to 24 and Kotlin to the version required by the locked `google_navigation_flutter` release; raise iOS deployment target to 16.0 in Podfile, Xcode project, and CI.
- Do not add background navigation or Always-location behavior for the map-only use case. Keep least-privilege location requests; if the package cannot pass an iOS 16 map-only build without background mode, stop at the dependency spike and document the conflict before expanding permissions.
- Keep Google native POIs visible and clickable. A native POI uses the existing bottom accessory slot temporarily; it never overwrites the current Tripline selection or writes data.
- External Google Maps opening is always user-initiated from a labeled button and uses a Universal URL with `api=1`, `query`, and `query_place_id` when available. No confirmation alert precedes the open.
- Preserve Tripline marker, route, cluster, PageView, and zoom-12 behavior across the map-engine migration.
- The itinerary selector contains `地圖` and `DAY 1...DAY N`; remove `總覽` and do not add vertical page snapping.
- The itinerary uses one vertical `CustomScrollView`; no nested vertical scroll view and no scroll-position dependency.
- Passive scrolling updates the local active Day only; never invalidate Riverpod state from Sliver layout or widget build.
- Weather preview is explicitly labeled as sample data and is replaced in place when real forecast data exists.
- Timeline rows show start and end time when both exist, expose the Google category below the title, and adapt rather than truncate at accessibility text sizes.
- Drag feedback uses a full-card representation and local insertion indicator; keep `移到其他 Day` as the non-drag alternative.
- Remote push is forbidden until the implementation has passed the scoped simplification pass, an independent merge-base code review, full verification, screenshot QA, gstack `/review`, Codex adversarial review, and the structured Codex review gate for a 200+ line diff. Fix accepted findings and rerun the affected review and verification gates before push.

## HIG References

- [Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons): use clear labels, familiar symbols, and a minimum 44pt hit region for standard touch controls.
- [Icons](https://developer.apple.com/design/human-interface-guidelines/icons): `folder` is the standard Move To symbol; `pencil` means edit or rename, not reorder.
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars): keep secondary commands in More and expose a current modal task's Done action directly on the trailing edge.
- [Menus](https://developer.apple.com/design/human-interface-guidelines/menus): list important commands first and group related commands with separators.
- [Context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus): keep item-specific commands scoped to the selected item.
- [Drag and drop](https://developer.apple.com/design/human-interface-guidelines/drag-and-drop): keep a non-drag alternative for move operations.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): provide sufficiently sized controls, labels, and alternatives to gestures.
- [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars): keep top-level destinations on one floating Liquid Glass navigation layer and allow content to remain visible beneath it.
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials): use Liquid Glass as a distinct functional layer above content without obscuring the content layer.
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass): reduce custom navigation backgrounds, avoid overlapping custom glass effects, and verify custom controls across appearance and accessibility settings.
- [Loading](https://developer.apple.com/design/human-interface-guidelines/loading): show a useful placeholder immediately and replace it when data is available.
- [Motion](https://developer.apple.com/design/human-interface-guidelines/motion): keep frequent feedback brief, purposeful, cancellable, and compatible with Reduce Motion.
- [Typography](https://developer.apple.com/design/human-interface-guidelines/typography): support Dynamic Type, minimize truncation, and reduce columns at accessibility sizes.
- [Scroll views](https://developer.apple.com/design/human-interface-guidelines/scroll-views): keep standard scrolling gestures and use one soft scroll edge where pinned Liquid Glass overlaps content.
- [Flutter slivers](https://docs.flutter.dev/ui/layout/scrolling/slivers): use native slivers for the pinned selector and a single scrolling surface.
- [Google Navigation for Flutter](https://pub.dev/packages/google_navigation_flutter): use the map-only `GoogleMapsMapView`, satisfy Android API 24/iOS 16 platform floors, and avoid a second Google Maps SDK dependency.
- [Google Navigation Flutter API](https://pub.dev/documentation/google_navigation_flutter/latest/google_navigation_flutter/): use `onPoiClicked`, `onMarkerClicked`, app-owned DTO conversion, marker image registration, and controller-managed overlays.
- [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started): use the cross-platform search URL with required `api=1`/`query` and optional `query_place_id` for app-or-browser fallback.

## File Map

- `lib/ui/tp_action_item.dart`: the single typed command model consumed by both compact More menus and bottom action sheets; owns destructive role, selected state, divider intent, key, label, icon, and returned value.
- `lib/ui/tp_app_bar.dart`: explicit page roles, shared Back/Close/Cancel/Done controls, shared sheet header, and sheet navigation scope.
- `lib/ui/tp_root_scaffold.dart`: the only Root full-bleed layout, fixed full-width Glass Header, scroll-body insets, soft edge, and Root Tab clearance.
- `lib/ui/tp_root_scroll_scaffold.dart`: remove after all consumers migrate to `TpRootScaffold`.
- `lib/ui/trip_title_button.dart`: reusable current-trip title/control shared by chat, itinerary, and map Root headers.
- `lib/ui/tp_glass_surface.dart`: the one compact-navigation `LiquidGlassSettings` source; larger surfaces retain their existing size-aware settings.
- `lib/ui/tp_horizontal_selector.dart`: shared itinerary/map selector that consumes compact-navigation settings; PlatformView changes only rendering compatibility.
- `lib/features/shell/apple_root_tab_bar.dart`: four root destinations that consume the same compact-navigation settings and translucent selection tint.
- `lib/theme/tokens.dart`: one Light/Dark `navigationSelection` tint aliased by Root Tab and Day thumb tokens.
- `lib/features/trip_detail/trip_timeline_screen.dart`: trip-level reorder entry point, direct Done action, per-entry Move To Day menu, drag alternative, and Day picker.
- `lib/features/chat/chat_screen.dart`: migrate to Root full-bleed scroll/body and fixed trip-title Glass Header without changing composer behavior.
- `lib/features/trips/trips_list_screen.dart`: migrate the no-selected-trip fallback to the shared Root Header.
- `lib/features/map/global_map_screen.dart`: remove `_MapRootAppBar`; provide current-trip title/actions to `TpRootScaffold`.
- `lib/features/favorites/favorites_screen.dart`: keep `收藏` and add in the shared Root Header; move search into the same capsule, render sorting/filtering through the shared menu, and keep account at the trailing edge.
- `lib/features/map/map_adapter.dart`: package-neutral map models, callbacks, controller interface, and conditional canvas factory; no Google plugin import.
- `lib/features/map/map_canvas_mobile.dart`: the only `google_navigation_flutter` renderer, controller bridge, native POI event adapter, appearance, padding, and overlay synchronization.
- `lib/features/map/map_canvas_web.dart`: non-embedded web fallback with a labeled Google Maps Web action.
- `lib/features/map/trip_map_overlay_synchronizer.dart`: app marker/route ID to plugin handle reconciliation without clear-and-redraw flicker.
- `lib/features/map/trip_map_marker_icon_registry.dart`: register and cache existing Tripline marker PNGs as `ImageDescriptor` values.
- `lib/features/map/trip_map_cluster_projector.dart`: pure-Dart zoom-grid clustering that replaces `google_maps_flutter.ClusterManager` without leaking plugin types.
- `lib/features/map/google_maps_external_launcher.dart`: typed Universal URL builder and injectable `url_launcher` boundary.
- `lib/features/trip_detail/google_poi_accessory_card.dart`: selected Google-native POI card rendered in the existing bottom accessory slot.
- `lib/features/trip_detail/trip_map_screen.dart`: preserve Tripline POI/Day selection and zoom 12 while adding temporary Google POI selection state.
- `lib/features/trip_detail/day_weather.dart`: one weather state surface that keeps the sample layout until live forecast data is available.
- `lib/features/trip_detail/widgets/timeline_entry_tile.dart`: start/end time, localized Google category, and standard/accessibility Timeline layouts.
- `lib/features/trip_detail/widgets/reorderable_row.dart`: shared 44pt reorder handle and accessibility semantics.
- `docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`: backend handoff for favorite soft delete, owner-scoped restore, migration, idempotency, expiry, and integration tests.
- `lib/features/trip_detail/entry_action_route_screen.dart`: web-compatible Move To Day wording that matches the in-app command.
- `lib/app/adaptive.dart`: the only sheet presentation engine, semantic wrappers, detents, glass, keyboard/safe-area behavior, and dirty dismissal interception.
- `lib/app/router.dart`: modal page transitions and explicit root/detail route intent where a route remains full screen.
- `pubspec.yaml` / `pubspec.lock`: replace `google_maps_flutter` with locked `google_navigation_flutter`.
- `android/settings.gradle.kts`: update Kotlin to the locked package requirement.
- `android/app/build.gradle.kts`: set API 24 minimum and required core-library desugaring without changing release signing.
- `ios/Podfile` / `ios/Runner.xcodeproj/project.pbxproj`: set iOS 16 consistently.
- `ios/Runner/Info.plist`: retain truthful foreground location purpose strings; do not claim background navigation for map-only usage.
- `lib/features/**`: replace generic or direct sheet calls and declare the correct semantic role; no sheet geometry or platform presentation code remains here.
- `test/ui/tp_app_bar_test.dart`: header role and control semantics.
- `test/ui/tp_root_scaffold_test.dart`: fixed overlay geometry, title semantics, four-action Favorites capacity, top/bottom clearance, and Dynamic Type.
- `test/app/adaptive_sheet_test.dart`: selection, content, form, nested navigation, detent, and dismissal behavior.
- Existing feature tests: preserve each workflow while asserting the new visible controls and return path.
- `test/features/trip_detail/day_weather_test.dart`: preview, loading, live data, error, and transition behavior.
- `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`: time range, category, semantics, and large-text layout.
- `test/features/trip_detail/trip_timeline_screen_test.dart`: pinned Day selector, scroll-linked selection, scroll edge, drag feedback, and rollback.
- `test/features/map/map_adapter_test.dart`: package-neutral config/controller and mobile renderer translation contract.
- `test/features/map/trip_map_cluster_projector_test.dart`: stable cluster membership, zoom changes, non-clusterable markers, and cluster fit points.
- `test/features/map/google_maps_external_launcher_test.dart`: encoded Universal URL, place-ID precision, fallback, and launch failure.
- `test/features/trip_detail/trip_map_screen_test.dart`: native Google POI accessory swap/restore, Tripline marker precedence, zoom 12, and existing PageView behavior.
- `test/ui/shared_ui_usage_test.dart`: static regression guard against feature-owned AppBars and sheet APIs.
- `test/ui/tripline_ui_test.dart`: selector optics remain identical with and without PlatformView rendering.
- `test/features/shell/app_shell_test.dart`: Root Tab optics stay identical across branches and its selected indicator reuses the base optics.

## Required Execution Order

The numeric task labels preserve the discussion history, but implementation must use this dependency order:

1. Task 0: establish the single typed action model and migrate both existing renderers before any feature adds commands.
2. Tasks 1–2: establish semantic detail/sheet headers and the shared sheet engine.
3. Task 10: establish the compact-navigation glass recipe before any Root/map surface consumes it.
4. Task 13: replace all Root headers/scaffolds and add the Favorites search/sort/add states before Timeline reorder work targets the new Root action slots; its action layout must support intrinsic-width `完成`.
5. Tasks 3–8: migrate sheet, action, movement, routed-task, detail, modal, and standalone semantics.
6. Tasks 11–12: finish the weather, adaptive Timeline, and section-linked scroll on the new Root scaffold.
7. Task 14: replace the map SDK and package boundary; Task 15 then adds native Google POI state and external opening.
8. Task 9: remove legacy sheet APIs only after all call sites are migrated.
9. External Backend Task B1 can proceed in parallel, but Flutter favorite-undo integration and Task 16 release verification require its contract tests to pass.
10. Task 16: simplify, remove compatibility code, verify, screenshot, run gstack `/review` plus its Codex gates, and only then allow a remote push.

---

### External Backend Task B1: Add owner-scoped favorite restore

**Handoff:** `docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`

**Backend repository:** `/Users/ray/Projects/trip-planner`

**Produces:** soft-delete migration, active-only favorite queries/index, idempotent `POST /api/poi-favorites/:id/restore`, 10-minute server retry window, audit/cache invalidation, and integration tests.

**Blocks:** Flutter replacement of recreate-on-undo with `FavoritesRepository.restoreFavorite(id)`, and Task 16 release verification.

- [ ] Backend applies the migration and active-only query audit.
- [ ] DELETE remains backward-compatible `204` but soft-deletes the owner row.
- [ ] Restore passes owner, idempotency, expiry, duplicate-race, audit, cache, CSRF, and rate-limit tests.
- [ ] Backend provides a commit SHA and a test environment where Flutter can verify DELETE → restore → GET.
- [ ] Flutter adds a failing repository test for `POST /poi-favorites/:id/restore`, replaces `addFavorite(poiId, note)` in the Undo callback, handles `410 UNDO_EXPIRED`, and retains the local snapshot only for optimistic rollback.

Do not silently retain the old recreate-on-undo path after this task lands. If the backend task is unavailable during UI development, keep the Flutter test skipped with the backend issue reference; do not ship a second production restore strategy.

---

### Task 0: Replace the two command models with one shared `TpActionItem<T>`

**Files:**
- Create: `lib/ui/tp_action_item.dart`
- Modify: `lib/ui/tp_app_bar.dart:346-484`
- Modify: `lib/app/adaptive.dart:87-177`
- Modify: `lib/features/trips/trips_list_screen.dart`
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart`
- Modify: `lib/features/favorites/explore/explore_screen.dart`
- Modify: `lib/features/favorites/favorites_screen.dart`
- Modify: `test/ui/tp_app_bar_test.dart`
- Modify: `test/ui/tripline_ui_test.dart`
- Modify: `test/app/adaptive_test.dart`
- Create: `test/ui/tp_action_item_test.dart`

**Interfaces:**
- Produces: `enum TpActionRole { normal, destructive }`
- Produces: immutable `TpActionItem<T>` with required `value`, `label`, and `icon`, plus `key`, `selected`, `dividerBefore`, `role`, and `enabled`
- Changes: `TpMoreMenuButton<T>.items` and `showAppActionSheet<T>(actions:)` both accept `List<TpActionItem<T>>`
- Preserves: each renderer's presentation role; the compact More menu stays a menu and the bottom action sheet stays a sheet
- Removes immediately after migration: `TpMenuAction<T>` and `AppSheetAction<T>`; no typedef, deprecated alias, or parallel compatibility constructor

- [ ] **Step 1: Add failing shared-model tests**

Create `test/ui/tp_action_item_test.dart` and extend both renderer test suites:

```dart
const sharedActions = <TpActionItem<String>>[
  TpActionItem(
    value: 'edit',
    label: '行程資料',
    icon: CupertinoIcons.pencil,
  ),
  TpActionItem(
    value: 'delete',
    label: '刪除行程',
    icon: CupertinoIcons.delete,
    dividerBefore: true,
    role: TpActionRole.destructive,
  ),
];

test('one action list carries renderer-independent semantics', () {
  expect(sharedActions.last.role, TpActionRole.destructive);
  expect(sharedActions.last.dividerBefore, isTrue);
  expect(sharedActions.map((action) => action.value), ['edit', 'delete']);
});
```

Add widget tests proving:

- the same `sharedActions` value can be passed without conversion to `TpMoreMenuButton<String>` and `showAppActionSheet<String>`;
- each renderer returns the typed `value` rather than invoking feature logic inside the UI primitive;
- `destructive` uses the theme error role, normal rows use title-level foreground contrast, and neither renderer hard-codes black;
- `dividerBefore`, disabled state, icon, label, key, 44pt hit target, tooltip, and accessibility label are retained in both Light and Dark;
- `selected: true` uses a checkmark in both renderers without making feature code build a custom menu row;
- the action-sheet title is centered directly above its separator with no decorative blank block.

- [ ] **Step 2: Run focused tests and confirm they fail**

Run:

```bash
flutter test test/ui/tp_action_item_test.dart test/ui/tp_app_bar_test.dart test/app/adaptive_test.dart
```

Expected: FAIL because `TpActionItem`, `TpActionRole`, and the shared renderer signatures do not exist.

- [ ] **Step 3: Add the package-independent action value object**

Create `lib/ui/tp_action_item.dart`:

```dart
import 'package:flutter/widgets.dart';

enum TpActionRole { normal, destructive }

@immutable
class TpActionItem<T> {
  const TpActionItem({
    required this.value,
    required this.label,
    required this.icon,
    this.key,
    this.selected = false,
    this.dividerBefore = false,
    this.role = TpActionRole.normal,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final Key? key;
  final bool selected;
  final bool dividerBefore;
  final TpActionRole role;
  final bool enabled;
}
```

This file must not import `adaptive.dart`, `tp_app_bar.dart`, feature code, or a glass package. It describes command semantics only.

- [ ] **Step 4: Migrate both renderers and all current call sites atomically**

Update `TpMoreMenuButton<T>` and `showAppActionSheet<T>` to consume `List<TpActionItem<T>>`. Both return/dispatch the selected typed value after their presentation closes. The renderer decides layout; feature screens decide what the returned value does.

Migrate every code and test call site listed above in the same commit. Convert `isDestructive: true` to `role: TpActionRole.destructive`, add `dividerBefore` where HIG grouping requires it, and supply a meaningful icon for every action-sheet item. When `selected` is true, the shared renderer replaces the leading icon with `CupertinoIcons.check_mark`; feature code must not build a custom selected row. Do not add conversion extensions or a temporary adapter list.

Run the graph/static check before deleting the old definitions:

```bash
rg -n "TpMenuAction|AppSheetAction" lib test
```

Expected: no match after the two class definitions are deleted.

- [ ] **Step 5: Verify renderer parity and commit**

Run:

```bash
dart format lib/ui/tp_action_item.dart lib/ui/tp_app_bar.dart lib/app/adaptive.dart lib/features/trips/trips_list_screen.dart lib/features/trip_detail/trip_timeline_screen.dart lib/features/favorites/explore/explore_screen.dart lib/features/favorites/favorites_screen.dart test/ui/tp_action_item_test.dart test/ui/tp_app_bar_test.dart test/ui/tripline_ui_test.dart test/app/adaptive_test.dart
flutter test test/ui/tp_action_item_test.dart test/ui/tp_app_bar_test.dart test/ui/tripline_ui_test.dart test/app/adaptive_test.dart
flutter analyze
```

Expected: PASS, with no legacy action model or renderer-specific feature adapter remaining.

Commit:

```bash
git add lib/ui/tp_action_item.dart lib/ui/tp_app_bar.dart lib/app/adaptive.dart lib/features/trips/trips_list_screen.dart lib/features/trip_detail/trip_timeline_screen.dart lib/features/favorites/explore/explore_screen.dart lib/features/favorites/favorites_screen.dart test/ui/tp_action_item_test.dart test/ui/tp_app_bar_test.dart test/ui/tripline_ui_test.dart test/app/adaptive_test.dart
git commit -m "refactor: unify Tripline action semantics"
```

---

### Task 1: Make `TpAppBar` semantic instead of route-inferred

**Files:**
- Modify: `lib/ui/tp_app_bar.dart:85-289`
- Modify: `test/ui/tp_app_bar_test.dart:12-188`

**Interfaces:**
- Produces: `enum TpAppBarRole { standalone, detail, modalContent, modalForm }`; Root destinations do not use `TpAppBar`
- Produces: `TpAppBar.role`, `TpAppBar.onCancel`, `TpAppBar.primaryActionLabel`, `TpAppBar.onPrimaryAction`, and `TpAppBar.primaryActionEnabled`
- Produces: public `TpToolbarTextButton`, reused for Cancel, Done, and form submit actions
- Produces: `TpSheetHeader`, reused by the sheet engine in Task 2
- Preserves: `TpToolbarGlassButton` as the only circular icon-button surface

- [ ] **Step 1: Add failing role tests**

Add these tests to `test/ui/tp_app_bar_test.dart`:

```dart
testWidgets('standalone app bar never implies a leading action', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.standalone,
          title: Text('邀請'),
        ),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
  expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
  expect(find.text('取消'), findsNothing);
});

testWidgets('detail app bar pops one route', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                appBar: TpAppBar(
                  role: TpAppBarRole.detail,
                  title: Text('外觀'),
                ),
              ),
            ),
          ),
          child: const Text('開啟'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('開啟'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
  await tester.pumpAndSettle();

  expect(find.text('開啟'), findsOneWidget);
  expect(find.text('外觀'), findsNothing);
});

testWidgets('modal form exposes Cancel and the explicit submit verb', (
  tester,
) async {
  var cancelled = false;
  var saved = false;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: TpAppBar(
          role: TpAppBarRole.modalForm,
          title: const Text('編輯行程'),
          onCancel: () => cancelled = true,
          primaryActionLabel: '儲存',
          onPrimaryAction: () => saved = true,
        ),
      ),
    ),
  );

  await tester.tap(find.text('取消'));
  await tester.tap(find.text('儲存'));

  expect(cancelled, isTrue);
  expect(saved, isTrue);
});

```

- [ ] **Step 2: Run the header tests and confirm they fail**

Run:

```bash
flutter test test/ui/tp_app_bar_test.dart
```

Expected: FAIL because `TpAppBarRole`, the semantic fields, and the stable Back key do not exist.

- [ ] **Step 3: Add the semantic role and shared text action**

Add near the top of `lib/ui/tp_app_bar.dart`:

```dart
enum TpAppBarRole { standalone, detail, modalContent, modalForm }

class TpToolbarTextButton extends StatelessWidget {
  const TpToolbarTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TpSpacing.tapMin,
        minHeight: TpSpacing.tapMin,
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(label, maxLines: 1),
      ),
    );
  }
}
```

Extend the `TpAppBar` constructor and fields:

```dart
const TpAppBar({
  super.key,
  required this.title,
  required this.role,
  this.actions = const [],
  this.onCancel,
  this.primaryActionLabel,
  this.onPrimaryAction,
  this.primaryActionEnabled = true,
});

final TpAppBarRole role;
final VoidCallback? onCancel;
final String? primaryActionLabel;
final VoidCallback? onPrimaryAction;
final bool primaryActionEnabled;
```

Resolve the leading action from `role` before using the existing automatic fallback:

```dart
Widget? semanticLeading(BuildContext context) {
  switch (role) {
    case TpAppBarRole.standalone:
      return null;
    case TpAppBarRole.detail:
      return TpToolbarGlassButton(
        key: const ValueKey('tp-app-bar-back'),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Icon(CupertinoIcons.back, size: 22),
      );
    case TpAppBarRole.modalContent:
      return TpToolbarGlassButton(
        key: const ValueKey('tp-app-bar-close'),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Icon(CupertinoIcons.xmark, size: 19),
      );
    case TpAppBarRole.modalForm:
      return TpToolbarTextButton(label: '取消', onPressed: onCancel);
  }
}
```

For `modalForm`, append one shared trailing text action instead of asking the feature to build it:

```dart
final resolvedActions = <Widget>[
  ...actions,
  if (primaryActionLabel != null)
    TpToolbarTextButton(
      key: const ValueKey('tp-app-bar-primary-action'),
      label: primaryActionLabel!,
      onPressed: primaryActionEnabled ? onPrimaryAction : null,
    ),
];
```

Add assertions to the constructor body:

```dart
assert(
  role != TpAppBarRole.modalForm ||
      (onCancel != null &&
          primaryActionLabel != null &&
          onPrimaryAction != null),
  'modalForm requires Cancel and a primary action.',
);
assert(
  (primaryActionLabel == null) == (onPrimaryAction == null),
  'primaryActionLabel and onPrimaryAction must be supplied together.',
);
```

- [ ] **Step 4: Add the shared sheet header**

Add to `lib/ui/tp_app_bar.dart`:

```dart
class TpSheetHeader extends StatelessWidget {
  const TpSheetHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 88),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (leading != null)
            Positioned(left: TpSpacing.s4, child: leading!),
          if (trailing != null)
            Positioned(right: TpSpacing.s4, child: trailing!),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests and commit the semantic header**

Run:

```bash
dart format lib/ui/tp_app_bar.dart test/ui/tp_app_bar_test.dart
flutter test test/ui/tp_app_bar_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/ui/tp_app_bar.dart test/ui/tp_app_bar_test.dart
git commit -m "refactor: make app bar navigation semantic"
```

---

### Task 2: Replace generic large sheets with one semantic engine

**Files:**
- Modify: `lib/app/adaptive.dart:178-491`
- Create: `test/app/adaptive_sheet_test.dart`
- Modify: `test/ui/tp_app_bar_test.dart:141-188`

**Interfaces:**
- Produces: `showAppSelectionSheet<T>()`
- Produces: `showAppContentSheet<T>()`
- Produces: `showAppScreenSheet<T>()`
- Produces: `showAppFormSheet()` and `AppSheetFormController`
- Removes after migration: `showAppLargeSheet<T>()` and `showAppLargeScreenSheet<T>()`
- Uses: `TpSheetHeader` and `TpToolbarGlassButton` from Task 1

- [ ] **Step 1: Add failing semantic sheet tests**

Create `test/app/adaptive_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:tripline/app/adaptive.dart';

void main() {
  testWidgets('selection sheet has Cancel, no Done, and distinct detents', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showAppSelectionSheet<String>(
                context,
                title: '切換行程',
                builder: (sheetContext, select) => ListTile(
                  title: const Text('東京五日行'),
                  onTap: () => select('trip-1'),
                ),
              );
            },
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsNothing);
    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.initialState, GlassSheetState.full);
    expect(sheet.halfSize, 0.62);
    expect(sheet.fullSize, 0.93);
    expect(sheet.showDragIndicator, isTrue);

    await tester.tap(find.text('東京五日行'));
    await tester.pumpAndSettle();
    expect(result, 'trip-1');
  });

  testWidgets('fixed content sheet has Close and no resize grabber', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showAppContentSheet<void>(
              context,
              title: '帳號',
              builder: (_) => const Text('帳號內容'),
            ),
            child: const Text('開啟'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-sheet-close')), findsOneWidget);
    final sheet = tester.widget<GlassModalSheetScaffold>(
      find.byType(GlassModalSheetScaffold),
    );
    expect(sheet.halfSize, 0.93);
    expect(sheet.fullSize, 0.93);
    expect(sheet.showDragIndicator, isFalse);
  });
}
```

- [ ] **Step 2: Run the new tests and confirm they fail**

Run:

```bash
flutter test test/app/adaptive_sheet_test.dart
```

Expected: FAIL because the semantic wrappers do not exist.

- [ ] **Step 3: Add the minimal form controller**

Add to `lib/app/adaptive.dart`:

```dart
class AppSheetFormController extends ChangeNotifier {
  Future<bool> Function()? _submit;
  bool _dirty = false;
  bool _canSubmit = false;
  bool _submitting = false;

  bool get isDirty => _dirty;
  bool get canSubmit => _canSubmit && !_submitting && _submit != null;
  bool get isSubmitting => _submitting;

  void attach(Future<bool> Function() submit) {
    _submit = submit;
    notifyListeners();
  }

  void update({bool? dirty, bool? canSubmit, bool? submitting}) {
    _dirty = dirty ?? _dirty;
    _canSubmit = canSubmit ?? _canSubmit;
    _submitting = submitting ?? _submitting;
    notifyListeners();
  }

  Future<bool> submit() async {
    final callback = _submit;
    if (!canSubmit || callback == null) return false;
    update(submitting: true);
    try {
      return await callback();
    } finally {
      update(submitting: false);
    }
  }
}
```

- [ ] **Step 4: Implement one private sheet engine**

Replace `_showThemeAwareAppLargeSheet` with one private entry that receives actual detents and an optional dismissal guard:

```dart
typedef _AppSheetBuilder<T> = Widget Function(
  BuildContext context,
  Future<void> Function([T? result]) close,
);

Future<T?> _showAppSheet<T>({
  required BuildContext context,
  required _AppSheetBuilder<T> builder,
  required GlassSheetState initialState,
  required double mediumSize,
  required double largeSize,
  required bool resizable,
  Future<bool> Function()? canDismiss,
}) {
  final controller = GlassModalSheetController();
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        _ThemeAwareAppSheet<T>(
          controller: controller,
          initialState: initialState,
          mediumSize: mediumSize,
          largeSize: largeSize,
          resizable: resizable,
          canDismiss: canDismiss,
          onClosed: (value) => Navigator.of(
            dialogContext,
            rootNavigator: true,
          ).pop(value),
          builder: builder,
        ),
  );
}
```

Implement `_ThemeAwareAppSheet<T>` so every close path calls one guarded method:

```dart
class _ThemeAwareAppSheet<T> extends StatefulWidget {
  const _ThemeAwareAppSheet({
    required this.controller,
    required this.initialState,
    required this.mediumSize,
    required this.largeSize,
    required this.resizable,
    required this.canDismiss,
    required this.onClosed,
    required this.builder,
  });

  final GlassModalSheetController controller;
  final GlassSheetState initialState;
  final double mediumSize;
  final double largeSize;
  final bool resizable;
  final Future<bool> Function()? canDismiss;
  final ValueChanged<T?> onClosed;
  final _AppSheetBuilder<T> builder;

  @override
  State<_ThemeAwareAppSheet<T>> createState() =>
      _ThemeAwareAppSheetState<T>();
}

class _ThemeAwareAppSheetState<T> extends State<_ThemeAwareAppSheet<T>> {
  bool _isClosing = false;
  bool _checkingDismiss = false;
  Widget? _sheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sheet ??= widget.builder(context, _requestClose);
  }

Future<void> _requestClose([T? result]) async {
  if (_isClosing || _checkingDismiss) return;
  _checkingDismiss = true;
  final allowed = await (widget.canDismiss?.call() ?? Future.value(true));
  _checkingDismiss = false;
  if (!mounted || !allowed) {
    widget.controller.snapToState(widget.initialState);
    return;
  }
  _isClosing = true;
  widget.onClosed(result);
}
}
```

Use the existing glass settings and configure the package from the supplied values:

```dart
return GlassModalSheetScaffold(
  controller: widget.controller,
  body: const SizedBox.expand(),
  sheet: _sheet!,
  initialState: widget.initialState,
  halfSize: widget.mediumSize,
  fullSize: widget.largeSize,
  settings: settings,
  halfSettings: settings,
  fullSettings: settings,
  expandedColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFBF5),
  quality: GlassQuality.standard,
  fillThreshold: 1,
  fillTransition: GlassFillTransition.gradual,
  topBorderRadius: 28,
  fullTopBorderRadius: 28,
  bottomBorderRadius: 0,
  fullBottomBorderRadius: 0,
  horizontalMargin: 0,
  bottomMargin: 0,
  padding: EdgeInsets.zero,
  showDragIndicator: widget.resizable,
  onStateChanged: (state) {
    if (state == GlassSheetState.hidden) {
      widget.controller.snapToState(widget.initialState, animate: false);
      unawaited(_requestClose());
    }
  },
);
```

- [ ] **Step 5: Add the four semantic wrappers**

Add to `lib/app/adaptive.dart`:

```dart
Future<T?> showAppSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext, ValueChanged<T>) builder,
}) {
  return _showAppSheet<T>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.62,
    largeSize: 0.93,
    resizable: true,
    builder: (sheetContext, close) => Column(
      children: [
        TpSheetHeader(
          title: title,
          leading: _AppSheetTextButton(
            label: '取消',
            onPressed: close,
          ),
        ),
        Expanded(
          child: builder(sheetContext, (value) => unawaited(close(value))),
        ),
      ],
    ),
  );
}

Future<T?> showAppContentSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  return _showAppSheet<T>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.93,
    largeSize: 0.93,
    resizable: false,
    builder: (sheetContext, close) => _AppContentSheet(
      title: title,
      contentBuilder: builder,
      onClose: close,
    ),
  );
}

Future<T?> showAppScreenSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return _showAppSheet<T>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.93,
    largeSize: 0.93,
    resizable: false,
    builder: (sheetContext, close) => _AppScreenSheet(
      contentBuilder: builder,
      onClose: close,
    ),
  );
}

Future<bool?> showAppFormSheet(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required AppSheetFormController controller,
  required WidgetBuilder builder,
}) {
  return _showAppSheet<bool>(
    context: context,
    initialState: GlassSheetState.full,
    mediumSize: 0.62,
    largeSize: 0.93,
    resizable: true,
    canDismiss: () async {
      if (!controller.isDirty) return true;
      return showAppConfirm(
        context,
        title: '捨棄未儲存的變更？',
        message: '離開後，本次修改不會保留。',
        confirmLabel: '捨棄',
        isDestructive: true,
      );
    },
    builder: (sheetContext, close) => AnimatedBuilder(
      animation: controller,
      builder: (_, child) => Column(
        children: [
          TpSheetHeader(
            title: title,
            leading: _AppSheetTextButton(
              label: '取消',
              onPressed: () => unawaited(close()),
            ),
            trailing: _AppSheetTextButton(
              label: submitLabel,
              onPressed: controller.canSubmit
                  ? () async {
                      if (await controller.submit()) await close(true);
                    }
                  : null,
            ),
          ),
          Expanded(child: child!),
        ],
      ),
      child: builder(sheetContext),
    ),
  );
}
```

`_AppSheetTextButton` is private to `adaptive.dart` and only applies shared 44pt sizing:

```dart
class _AppSheetTextButton extends StatelessWidget {
  const _AppSheetTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minWidth: TpSpacing.tapMin,
      minHeight: TpSpacing.tapMin,
    ),
    child: TextButton(onPressed: onPressed, child: Text(label)),
  );
}
```

- [ ] **Step 6: Run sheet tests and commit the engine**

Run:

```bash
dart format lib/app/adaptive.dart test/app/adaptive_sheet_test.dart test/ui/tp_app_bar_test.dart
flutter test test/app/adaptive_sheet_test.dart test/ui/tp_app_bar_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/app/adaptive.dart test/app/adaptive_sheet_test.dart test/ui/tp_app_bar_test.dart
git commit -m "refactor: add semantic app sheet engine"
```

---

### Task 3: Migrate trip selection, account, and trip utility sheets

**Files:**
- Modify: `lib/features/trips/trip_title_button.dart:23-73`
- Modify: `lib/ui/tp_account_avatar_button.dart:17-67`
- Modify: `lib/features/account/account_screen.dart:510-614`
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart:74-124`
- Modify: `test/features/account/account_screen_test.dart`
- Modify: `test/features/trip_detail/trip_timeline_screen_test.dart`
- Create: `test/features/trips/trip_title_button_test.dart`

**Interfaces:**
- Consumes: `showAppSelectionSheet`, `showAppContentSheet`, and `showAppScreenSheet` from Task 2
- Produces: trip picker with immediate selection; account with one internal navigator; utility screens with one Close path

- [ ] **Step 1: Add failing trip-picker and account navigation tests**

Create `test/features/trips/trip_title_button_test.dart` with a two-trip fixture and these assertions:

```dart
testWidgets('trip picker is a selection sheet', (tester) async {
  String? selected;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TripTitleButton(
          currentTripId: 'trip-1',
          currentTitle: '東京五日行',
          trips: const [
            TripSummary(tripId: 'trip-1', name: '東京五日行'),
            TripSummary(tripId: 'trip-2', name: '沖繩五日行'),
          ],
          onSelected: (value) => selected = value,
        ),
      ),
    ),
  );

  await tester.tap(find.text('東京五日行'));
  await tester.pumpAndSettle();
  expect(find.text('取消'), findsOneWidget);
  expect(find.text('完成'), findsNothing);
  expect(find.byIcon(Icons.check), findsOneWidget);

  await tester.tap(find.text('沖繩五日行'));
  await tester.pumpAndSettle();
  expect(selected, 'trip-2');
});
```

Add to `test/features/account/account_screen_test.dart`:

```dart
testWidgets('account child uses Back while Close dismisses the whole sheet', (
  tester,
) async {
  await tester.tap(find.byKey(const ValueKey('account-avatar-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('settings-appearance')));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('tp-app-bar-back')), findsOneWidget);
  expect(find.byKey(const ValueKey('app-sheet-close')), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('tp-app-bar-back')));
  await tester.pumpAndSettle();
  expect(find.text('帳號'), findsOneWidget);
});
```

- [ ] **Step 2: Run focused tests and confirm they fail**

Run:

```bash
flutter test test/features/trips/trip_title_button_test.dart test/features/account/account_screen_test.dart
```

Expected: FAIL because both entries still use the generic content sheet.

- [ ] **Step 3: Migrate the trip picker**

Replace `TripTitleButton._openPicker` with:

```dart
Future<void> _openPicker(BuildContext context) async {
  final selected = await showAppSelectionSheet<String>(
    context,
    title: '切換行程',
    builder: (sheetContext, select) => _TripPickerSheet(
      currentTripId: currentTripId,
      trips: trips,
      onSelected: select,
    ),
  );
  if (selected != null && selected != currentTripId) onSelected(selected);
}
```

Add `ValueChanged<String> onSelected` to `_TripPickerSheet` and replace row pops with:

```dart
onTap: () => widget.onSelected(trip.tripId),
```

- [ ] **Step 4: Migrate account and utility screens**

Replace the account avatar call with:

```dart
showAppContentSheet<void>(
  context,
  title: '帳號',
  builder: (_) => const AccountScreen(embedded: true),
);
```

Keep `AccountScreen._openSheetPage` on the sheet's existing nested `Navigator`, and set all read-only/settings children to:

```dart
appBar: const TpAppBar(
  role: TpAppBarRole.detail,
  title: Text('外觀'),
),
```

Replace timeline utility opening with:

```dart
void _openActionSheet(Widget screen) {
  unawaited(showAppScreenSheet<void>(context, builder: (_) => screen));
}
```

Do not migrate `EditTripScreen` through `_openActionSheet`; Task 7 gives it form semantics.

- [ ] **Step 5: Run feature tests and commit**

Run:

```bash
dart format lib/features/trips/trip_title_button.dart lib/ui/tp_account_avatar_button.dart lib/features/account/account_screen.dart lib/features/trip_detail/trip_timeline_screen.dart test/features/trips/trip_title_button_test.dart test/features/account/account_screen_test.dart test/features/trip_detail/trip_timeline_screen_test.dart
flutter test test/features/trips/trip_title_button_test.dart test/features/account/account_screen_test.dart test/features/trip_detail/trip_timeline_screen_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/features/trips/trip_title_button.dart lib/ui/tp_account_avatar_button.dart lib/features/account/account_screen.dart lib/features/trip_detail/trip_timeline_screen.dart test/features/trips/trip_title_button_test.dart test/features/account/account_screen_test.dart test/features/trip_detail/trip_timeline_screen_test.dart
git commit -m "refactor: migrate trip and account sheets"
```

---

### Task 4: Separate trip reordering from item-level Move To Day

**Files:**
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart:100-180,554-590,889-919`
- Modify: `lib/features/trip_detail/widgets/reorderable_row.dart:62-91`
- Modify: `lib/features/trip_detail/entry_action_route_screen.dart:12-27`
- Modify: `test/features/trip_detail/trip_timeline_screen_test.dart`
- Modify: `test/features/trip_detail/entry_action_route_screen_test.dart`

**Interfaces:**
- Consumes: `TpRootScaffold`/`TpRootGlassHeader` from Task 13 and `showAppSelectionSheet<int>()` from Task 2
- Reuses: `TpMoreMenuButton<T>` and `TpActionItem<T>`; no second menu implementation
- Produces: trip-level `調整順序`, intrinsic-width trailing `完成`, direct per-entry `移到其他 Day`, matching 44pt inline move/reorder controls, full-card drag feedback, and local insertion feedback
- Preserves: same-Day reorder, cross-Day drag, explicit Day selection, repository calls, and travel recomputation

- [ ] **Step 1: Add failing movement-semantics tests**

Add to `test/features/trip_detail/trip_timeline_screen_test.dart`:

```dart
testWidgets('trip menu enters reorder mode and Done exits directly', (
  tester,
) async {
  await _pumpTimeline(tester);

  await tester.tap(find.byKey(const ValueKey('trip-actions-menu')));
  await tester.pumpAndSettle();

  final reorderAction = find.byKey(const ValueKey('trip-edit-mode'));
  expect(reorderAction, findsOneWidget);
  expect(
    find.descendant(
      of: reorderAction,
      matching: find.byIcon(CupertinoIcons.line_horizontal_3),
    ),
    findsOneWidget,
  );
  expect(find.text('調整順序'), findsOneWidget);
  expect(find.text('編輯行程'), findsNothing);
  expect(find.text('移動行程'), findsNothing);

  await tester.tap(reorderAction);
  await _pumpGlassMenuClose(tester);

  expect(find.byKey(const ValueKey('trip-actions-menu')), findsNothing);
  expect(
    find.byKey(const ValueKey('tp-root-header-primary-action')),
    findsOneWidget,
  );
  expect(find.text('完成'), findsOneWidget);
  expect(find.byKey(const ValueKey('entry-drag-11')), findsOneWidget);

  await tester.tap(
    find.byKey(const ValueKey('tp-root-header-primary-action')),
  );
  await tester.pump();

  expect(find.byKey(const ValueKey('entry-drag-11')), findsNothing);
  expect(find.byKey(const ValueKey('trip-actions-menu')), findsOneWidget);
});

testWidgets('Move To Day and reorder use matching direct inline controls', (
  tester,
) async {
  await _pumpTimeline(tester);
  await _enableTimelineEditing(tester);

  final moveButton = find.byKey(const ValueKey('entry-move-to-day-11'));
  final dragHandle = find.byKey(const ValueKey('entry-drag-11'));
  expect(tester.getSize(moveButton), const Size(44, 44));
  expect(tester.getSize(dragHandle), const Size(44, 44));
  expect(tester.getSemantics(moveButton).label, '移到其他 Day');
  expect(tester.getSemantics(dragHandle).label, '拖曳調整順序');
  expect(
    find.descendant(of: moveButton, matching: find.byIcon(CupertinoIcons.folder)),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('entry-menu-11')), findsNothing);

  await tester.tap(moveButton);
  await tester.pumpAndSettle();
  expect(find.text('移到其他 Day'), findsOneWidget);
});

testWidgets('Done keeps its full label and intrinsic width at 200 percent text', (
  tester,
) async {
  await _pumpTimeline(tester, textScaler: const TextScaler.linear(2));
  await _enableTimelineEditing(tester);

  final done = find.byKey(
    const ValueKey('tp-root-header-primary-action'),
  );
  expect(find.descendant(of: done, matching: find.text('完成')), findsOneWidget);
  expect(tester.getSize(done).height, greaterThanOrEqualTo(44));
  expect(tester.getSize(done).width, greaterThan(44));
  expect(find.text('完'), findsNothing);
  expect(tester.takeException(), isNull);
});
```

Add to `test/features/trip_detail/entry_action_route_screen_test.dart`:

```dart
testWidgets('move route uses the same Move To Day wording', (tester) async {
  final repo = _MockTripRepository();
  await tester.pumpWidget(_buildScreen(repo, EntryRouteAction.move));
  await tester.pumpAndSettle();
  expect(find.text('移到其他 Day'), findsOneWidget);
  expect(find.text('移動停留點'), findsNothing);
  expect(find.text('移動行程'), findsNothing);
});
```

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run:

```bash
flutter test test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/entry_action_route_screen_test.dart
```

Expected: FAIL because the More menu still says `編輯行程`, uses `pencil`, hides Done inside the menu, and exposes an unlabeled compact folder button.

- [ ] **Step 3: Make reorder mode a trip-level command with direct Done**

Update `TripTimelineScreen` so the shared Root Glass Header shows More plus account in normal mode. In reorder mode the title becomes `調整順序`, More becomes a direct full-width Done text action, and the account button stays available:

```dart
return TpRootScaffold(
  header: TpRootHeaderConfig(
    title: _isEditing
        ? const Text('調整順序')
        : TripTitleButton(
            key: const ValueKey('trip-timeline-trip-picker'),
            currentTripId: widget.tripId,
            currentTitle: tripTitle,
            trips: trips,
            onSelected: (tripId) =>
                context.go('/trips/${Uri.encodeComponent(tripId)}'),
          ),
    actions: [
      if (_isEditing)
        TpToolbarTextButton(
          key: const ValueKey('tp-root-header-primary-action'),
          label: '完成',
          onPressed: () => setState(() => _isEditing = false),
        )
      else
        TpMoreMenuButton<_TripMoreAction>(
          key: const ValueKey('trip-actions-menu'),
          onSelected: _handleTripAction,
          items: const [
            TpActionItem(
              key: ValueKey('trip-edit-mode'),
              value: _TripMoreAction.editMode,
              icon: CupertinoIcons.line_horizontal_3,
              label: '調整順序',
            ),
            TpActionItem(
              key: ValueKey('trip-action-notes'),
              value: _TripMoreAction.notes,
              icon: CupertinoIcons.doc_text,
              label: '筆記',
            ),
            TpActionItem(
              key: ValueKey('trip-action-edit-info'),
              value: _TripMoreAction.editInfo,
              icon: CupertinoIcons.pencil,
              label: '行程資料',
              dividerBefore: true,
            ),
            TpActionItem(
              key: ValueKey('trip-action-print'),
              value: _TripMoreAction.print,
              icon: CupertinoIcons.printer,
              label: '列印',
            ),
            TpActionItem(
              key: ValueKey('trip-action-audit'),
              value: _TripMoreAction.audit,
              icon: Icons.history_outlined,
              label: '異動紀錄',
            ),
            TpActionItem(
              key: ValueKey('trip-action-share'),
              value: _TripMoreAction.share,
              icon: Icons.ios_share_outlined,
              label: '分享連結',
            ),
            TpActionItem(
              key: ValueKey('trip-action-collab'),
              value: _TripMoreAction.collab,
              icon: Icons.group_outlined,
              label: '共編設定',
            ),
            TpActionItem(
              key: ValueKey('trip-action-health'),
              value: _TripMoreAction.health,
              icon: Icons.health_and_safety_outlined,
              label: 'AI 健檢',
            ),
          ],
        ),
      const TpAccountAvatarButton(),
    ],
  ),
  body: daysAsync.when(
    data: (days) => days.isEmpty
        ? const _EmptyTimeline()
        : _TimelineBody(
            days: days,
            tripId: widget.tripId,
            initialEntryId: widget.initialEntryId,
            initialDayNum: widget.initialDayNum,
            isEditing: _isEditing,
          ),
    loading: () => const _TimelineSkeleton(),
    error: (error, stackTrace) => _TimelineError(
      onRetry: () {
        ref.invalidate(tripDetailProvider(widget.tripId));
        ref.invalidate(tripDaysProvider(widget.tripId));
      },
    ),
  ),
);
```

`TpRootGlassHeader` must pass text actions through the same shared toolbar slot logic as `TpAppBar`: `TpToolbarTextButton` receives intrinsic/flexible width and a minimum 44pt height; only icon actions use a 44×44pt square. Do not abbreviate the localized label or special-case Chinese text.

Extract the current switch body without changing behavior:

```dart
void _handleTripAction(_TripMoreAction action) {
  switch (action) {
    case _TripMoreAction.editMode:
      setState(() => _isEditing = true);
    case _TripMoreAction.notes:
      _openActionSheet(TripNotesScreen(tripId: widget.tripId));
    case _TripMoreAction.editInfo:
      _openActionSheet(EditTripScreen(tripId: widget.tripId));
    case _TripMoreAction.print:
      _openActionSheet(TripPrintScreen(tripId: widget.tripId));
    case _TripMoreAction.audit:
      _openActionSheet(TripAuditScreen(tripId: widget.tripId));
    case _TripMoreAction.share:
      _openActionSheet(ShareScreen(tripId: widget.tripId));
    case _TripMoreAction.collab:
      _openActionSheet(CollabScreen(tripId: widget.tripId));
    case _TripMoreAction.health:
      _openActionSheet(TripHealthScreen(tripId: widget.tripId));
  }
}
```

- [ ] **Step 4: Unify Move To Day and reorder as direct inline controls**

The ellipsis currently contains one command and adds an unnecessary interaction. Replace `_EntryTrailing` with two direct 44pt controls that share `TpInlineEditActionStyle` (or the existing equivalent shared style). Use the folder as a button that opens the labeled selection sheet; keep the three-line control as the drag source:

```dart
class _EntryTrailing extends StatelessWidget {
  const _EntryTrailing({
    required this.entryId,
    required this.index,
    required this.onMove,
  });

  final int entryId;
  final int index;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TpInlineEditActionButton(
          key: ValueKey('entry-move-to-day-$entryId'),
          tooltip: '移到其他 Day',
          icon: CupertinoIcons.folder,
          onPressed: onMove,
        ),
        ReorderDragHandle(
          index: index,
          iconKey: ValueKey('entry-drag-$entryId'),
        ),
      ],
    );
  }
}
```

`TpInlineEditActionButton` and `ReorderDragHandle` both use the same 44×44pt transparent image-button surface, primary foreground, pressed/highlight state, tooltip, and semantics. They do not add nested glass or bordered circles inside the Timeline card. `ReorderDragHandle` owns pointer/drag behavior but consumes the same visual builder. Keep the existing vertical rail if it preserves Timeline text width at 200% Dynamic Type; format consistency does not require turning the two actions into a wide horizontal toolbar.

- [ ] **Step 5: Give the drag handle a 44pt target and accessibility label**

Replace `ReorderDragHandle.build` in `lib/features/trip_detail/widgets/reorderable_row.dart` with:

```dart
@override
Widget build(BuildContext context) {
  return ReorderableDragStartListener(
    index: index,
    child: Listener(
      onPointerDown: (_) => HapticFeedback.selectionClick(),
      child: Semantics(
        key: iconKey,
        button: true,
        label: '拖曳調整順序',
          child: TpInlineEditControlVisual(
            icon: CupertinoIcons.line_horizontal_3,
          ),
      ),
    ),
  );
}
```

- [ ] **Step 6: Use the semantic Day picker and consistent route wording**

Replace `_moveToDay` presentation with:

```dart
final targetDayId = await showAppSelectionSheet<int>(
  context,
  title: '移到其他 Day',
  builder: (sheetContext, select) => ListView(
    children: [
      for (final target in targets)
        ListTile(
          key: ValueKey('move-day-${target.id}'),
          title: Text('DAY ${target.dayNum} · ${target.displayTitle}'),
          onTap: () => select(target.id),
        ),
    ],
  ),
);
```

Update only the move title in `entry_action_route_screen.dart`:

```dart
String get title => switch (this) {
  EntryRouteAction.copy => '複製停留點',
  EntryRouteAction.move => '移到其他 Day',
};
```

Keep the submit verb `移動`; do not introduce the ambiguous label `移動行程` anywhere.

- [ ] **Step 7: Add failing drag-feedback tests**

Add to `test/features/trip_detail/trip_timeline_screen_test.dart`:

```dart
testWidgets('cross-Day drag lifts the full card and marks only the insertion point', (
  tester,
) async {
  await _pumpTimeline(tester);
  await _enableTimelineEditing(tester);

  final drag = find.byKey(const ValueKey('entry-cross-drag-11'));
  final gesture = await tester.startGesture(tester.getCenter(drag));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));

  expect(
    find.byKey(const ValueKey('entry-drag-feedback-11')),
    findsOneWidget,
  );
  expect(find.text('美麗海水族館'), findsWidgets);

  await gesture.moveTo(
    tester.getCenter(find.byKey(const ValueKey('entry-drop-21'))),
  );
  await tester.pump(const Duration(milliseconds: 100));

  expect(
    find.byKey(const ValueKey('entry-drop-indicator-21')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('day-drop-outline-2')),
    findsNothing,
  );

  await gesture.cancel();
  await tester.pumpAndSettle();
});
```

Run:

```bash
flutter test test/features/trip_detail/trip_timeline_screen_test.dart \
  --plain-name 'cross-Day drag lifts the full card and marks only the insertion point'
```

Expected: FAIL because the feedback contains only the title and the whole Day currently receives a border.

- [ ] **Step 8: Replace whole-Day highlighting and stepped auto-scroll**

In `_DaySection.build`, remove the `DecoratedBox` border derived from `candidateData`. Keep the Day-level `DragTarget` only as the append-to-end destination.

Wrap each row target with a local indicator:

```dart
builder: (context, candidateData, rejectedData) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    AnimatedSize(
      duration: TpMotion.resolve(context, TpMotion.fast),
      curve: TpMotion.appleEase,
      child: candidateData.isEmpty
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey('entry-drop-indicator-${entry.id}'),
              height: 3,
              margin: const EdgeInsets.only(bottom: TpSpacing.s2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
    ),
    row,
  ],
),
```

Use the actual tile as the drag representation and preserve its width:

```dart
feedback: Material(
  key: ValueKey('entry-drag-feedback-${entry.id}'),
  type: MaterialType.transparency,
  child: Opacity(
    opacity: 0.92,
    child: Transform.scale(
      scale: MediaQuery.disableAnimationsOf(context) ? 1 : 0.98,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width -
            (TpSpacing.s4 * 2) -
            kTimelineTimeColumnWidth -
            kTimelineRailWidth,
        child: IgnorePointer(child: tile),
      ),
    ),
  ),
),
```

Keep `childWhenDragging` at `0.35` opacity. Trigger one lift haptic from `onDragStarted`:

```dart
onDragStarted: () {
  HapticFeedback.mediumImpact();
  _captureDragScroll();
},
```

Replace the fixed 32px `jumpTo` step in `_autoScrollDuringDrag` with a distance-sensitive short animation:

```dart
final distance = globalPosition.dy < edge
    ? globalPosition.dy - edge
    : globalPosition.dy > height - edge
        ? globalPosition.dy - (height - edge)
        : 0.0;
if (distance == 0) return;
final delta = (distance / edge * 48).clamp(-48.0, 48.0);
final position = scrollController.position;
final target = (position.pixels + delta).clamp(
  position.minScrollExtent,
  position.maxScrollExtent,
);
unawaited(
  scrollController.animateTo(
    target,
    duration: const Duration(milliseconds: 48),
    curve: Curves.linear,
  ),
);
```

Call `HapticFeedback.selectionClick()` only after `_moveEntryToDay` succeeds. An invalid or failed drop keeps the existing error notice and returns to the source; Task 12 adds the shared optimistic presentation snapshot used for an animated rollback.

- [ ] **Step 9: Run tests and commit the movement semantics**

Run:

```bash
dart format lib/features/trip_detail/trip_timeline_screen.dart lib/features/trip_detail/widgets/reorderable_row.dart lib/features/trip_detail/entry_action_route_screen.dart test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/entry_action_route_screen_test.dart
flutter test test/ui/tp_app_bar_test.dart test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/entry_action_route_screen_test.dart
```

Expected: PASS; same-Day reorder, cross-Day drag, direct Move To Day, full `完成`, and matching inline action visuals all remain available at standard and 200% text.

Commit:

```bash
git add lib/features/trip_detail/trip_timeline_screen.dart lib/features/trip_detail/widgets/reorderable_row.dart lib/features/trip_detail/entry_action_route_screen.dart test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/entry_action_route_screen_test.dart
git commit -m "refactor: align itinerary movement with HIG"
```

---

### Task 5: Migrate remaining immediate-selection and read-only bottom sheets

**Files:**
- Modify: `lib/features/trip_detail/entry_poi_screen.dart:350-427`
- Modify: `lib/features/account/account_sessions_screen.dart:437-537`
- Modify: `test/features/trip_detail/entry_poi_screen_test.dart`
- Modify: `test/features/account/account_sessions_screen_test.dart`

**Interfaces:**
- Consumes: `showAppSelectionSheet<T>` and `showAppContentSheet<T>`
- Produces: immediate row selection with no Done; read-only session details with Close

- [ ] **Step 1: Add failing semantic assertions to existing tests**

For POI alternate/master selection tests, assert:

```dart
expect(find.text('選擇地點'), findsOneWidget);
expect(find.text('取消'), findsOneWidget);
expect(find.text('完成'), findsNothing);
```

For session detail tests, assert:

```dart
expect(find.byKey(const ValueKey('app-sheet-close')), findsOneWidget);
expect(find.text('取消'), findsNothing);
```

- [ ] **Step 2: Run tests and confirm they fail**

Run:

```bash
flutter test test/features/trip_detail/entry_poi_screen_test.dart test/features/account/account_sessions_screen_test.dart
```

Expected: FAIL because the POI picker and session details still own `showModalBottomSheet` calls.

- [ ] **Step 3: Replace the POI pickers**

Replace both `_addAlternate` and `_changeMaster` bottom-sheet calls with:

```dart
final selected = await showAppSelectionSheet<_EntryPoiPick>(
  context,
  title: '選擇地點',
  builder: (sheetContext, select) => _AlternateSearchSheet(
    onSelected: select,
  ),
);
```

Add `ValueChanged<_EntryPoiPick> onSelected` to `_AlternateSearchSheet` and remove its direct `Navigator.pop` calls.

- [ ] **Step 4: Replace session details with a content sheet**

Replace `_SessionTile._showDetails` presentation with:

```dart
Future<void> _showDetails(BuildContext context) async {
  await showAppContentSheet<void>(
    context,
    title: '登入裝置',
    builder: (_) => _SessionDetails(session: session),
  );
}
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
dart format lib/features/trip_detail/entry_poi_screen.dart lib/features/account/account_sessions_screen.dart test/features/trip_detail/entry_poi_screen_test.dart test/features/account/account_sessions_screen_test.dart
flutter test test/features/trip_detail/entry_poi_screen_test.dart test/features/account/account_sessions_screen_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/features/trip_detail/entry_poi_screen.dart lib/features/account/account_sessions_screen.dart test/features/trip_detail/entry_poi_screen_test.dart test/features/account/account_sessions_screen_test.dart
git commit -m "refactor: unify selection and content sheets"
```

---

### Task 6: Migrate editable bottom sheets and protect dirty input

**Files:**
- Modify: `lib/features/trip_detail/widgets/entry_edit_sheet.dart:36-457`
- Modify: `lib/features/trip_detail/widgets/travel_edit_sheet.dart:1-317`
- Modify: `lib/features/trip_detail/notes/note_edit_sheet.dart:1-307`
- Modify: `lib/features/favorites/favorites_screen.dart:254-310`
- Modify: `lib/features/chat/ai_consent_sheet.dart:1-207`
- Modify: `lib/features/offline/conflict_resolve_sheet.dart:1-241`
- Modify: `test/features/trip_detail/widgets/entry_edit_sheet_test.dart`
- Create: `test/features/trip_detail/widgets/travel_edit_sheet_test.dart`
- Modify: `test/features/trip_detail/notes/note_edit_sheet_test.dart`
- Modify: `test/features/favorites/favorites_screen_test.dart`
- Create: `test/features/chat/ai_consent_sheet_test.dart`
- Create: `test/features/offline/conflict_resolve_sheet_test.dart`
- Modify: `test/app/adaptive_sheet_test.dart`

**Interfaces:**
- Consumes: `AppSheetFormController` and `showAppFormSheet()`
- Produces: every editable sheet returns success instead of popping itself
- Preserves: native `showDatePicker` and `showTimePicker`

- [ ] **Step 1: Add a dirty-dismiss regression test**

Add to `test/app/adaptive_sheet_test.dart`:

```dart
testWidgets('dirty form asks before Cancel and stays open when kept', (
  tester,
) async {
  final controller = AppSheetFormController();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () => showAppFormSheet(
            context,
            title: '編輯停留點',
            submitLabel: '儲存',
            controller: controller,
            builder: (_) => TextField(
              onChanged: (_) => controller.update(
                dirty: true,
                canSubmit: true,
              ),
            ),
          ),
          child: const Text('開啟'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('開啟'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '京都');
  await tester.tap(find.text('取消'));
  await tester.pumpAndSettle();

  expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
  await tester.tap(find.text('取消').last);
  await tester.pumpAndSettle();
  expect(find.text('編輯停留點'), findsOneWidget);
});
```

- [ ] **Step 2: Run the dismissal test and confirm it fails**

Run:

```bash
flutter test test/app/adaptive_sheet_test.dart
```

Expected: FAIL until form state is connected to the controller and guarded close path.

- [ ] **Step 3: Convert entry, travel, and note editors**

Change `showEntryEditSheet`, `showTravelEditSheet`, and `showNoteEditSheet` to create one controller and call `showAppFormSheet`. The entry editor implementation is:

```dart
final controller = AppSheetFormController();
return showAppFormSheet(
  context,
  title: isEdit ? '編輯停留點' : '新增停留點',
  submitLabel: isEdit ? '儲存' : '新增',
  controller: controller,
  builder: (_) => EntryEditSheet(
    tripId: tripId,
    args: args,
    formController: controller,
  ),
);
```

In each state object, attach submit once and update dirty/valid state from existing field listeners:

```dart
@override
void initState() {
  super.initState();
  widget.formController.attach(_submitForSheet);
}

void _syncFormState() {
  widget.formController.update(
    dirty: _hasChanges,
    canSubmit: _canSubmit,
  );
}

Future<bool> _submitForSheet() async {
  final saved = await _saveWithoutPopping();
  if (saved) widget.formController.update(dirty: false);
  return saved;
}
```

Remove the duplicate bottom submit button from these form sheets; the shared header owns the submit action.

- [ ] **Step 4: Convert filters, consent, and conflict resolution**

Use `showAppFormSheet` for the favorites filter, with `套用` as the submit label and a controller that becomes dirty when a pending filter differs from the active filter:

```dart
final controller = AppSheetFormController();
await showAppFormSheet(
  context,
  title: '篩選收藏',
  submitLabel: '套用',
  controller: controller,
  builder: (_) => _FavoritesFilterForm(
    controller: controller,
    initialRegion: _regionFilter,
    onApply: (region) async {
      setState(() => _regionFilter = region);
      return true;
    },
  ),
);
```

Use the same controller contract for AI consent and conflict resolution. Their submit labels are `允許` and `套用所選版本`; Cancel performs no API call.

- [ ] **Step 5: Run all migrated form tests and commit**

Run:

```bash
dart format lib/features/trip_detail/widgets/entry_edit_sheet.dart lib/features/trip_detail/widgets/travel_edit_sheet.dart lib/features/trip_detail/notes/note_edit_sheet.dart lib/features/favorites/favorites_screen.dart lib/features/chat/ai_consent_sheet.dart lib/features/offline/conflict_resolve_sheet.dart test/app/adaptive_sheet_test.dart
flutter test test/app/adaptive_sheet_test.dart test/features/trip_detail test/features/favorites test/features/chat test/features/offline
```

Expected: PASS.

Commit:

```bash
git add lib/features/trip_detail/widgets/entry_edit_sheet.dart lib/features/trip_detail/widgets/travel_edit_sheet.dart lib/features/trip_detail/notes/note_edit_sheet.dart lib/features/favorites/favorites_screen.dart lib/features/chat/ai_consent_sheet.dart lib/features/offline/conflict_resolve_sheet.dart test/app/adaptive_sheet_test.dart test/features
git commit -m "refactor: unify editable sheets"
```

---

### Task 7: Give routed create/edit/action pages modal task semantics

**Files:**
- Modify: `lib/app/router.dart:170-294`
- Modify: `lib/features/trips/create/create_trip_screen.dart:26-138`
- Modify: `lib/features/trips/edit/edit_trip_screen.dart:19-180`
- Modify: `lib/features/favorites/add_to_trip/add_to_trip_screen.dart:95-325`
- Modify: `lib/features/trip_detail/entry_add_route_screen.dart:38-336`
- Modify: `lib/features/trip_detail/entry_edit_route_screen.dart:11-45`
- Modify: `lib/features/trip_detail/entry_action_route_screen.dart:45-172`
- Modify: `lib/features/account/settings/profile_edit_screen.dart:21-113`
- Modify: `lib/features/account/developer_apps_screen.dart:99-412`
- Modify: `test/features/trips/create/create_trip_screen_test.dart`
- Modify: `test/features/trips/edit/edit_trip_screen_test.dart`
- Modify: `test/features/favorites/add_to_trip/add_to_trip_screen_test.dart`
- Modify: `test/features/trip_detail/entry_add_route_screen_test.dart`
- Create: `test/features/trip_detail/entry_edit_route_screen_test.dart`
- Modify: `test/features/trip_detail/entry_action_route_screen_test.dart`
- Modify: `test/features/account/settings/profile_edit_screen_test.dart`
- Modify: `test/features/account/developer_apps_screen_test.dart`

**Interfaces:**
- Consumes: `TpAppBarRole.modalForm`
- Produces: explicit Cancel plus Create/Save/Add/Copy/Move actions
- Produces: shared dirty-route dismissal using `PopScope`

- [ ] **Step 1: Add failing visible-control tests**

Add equivalent assertions to each existing screen test, using the screen's explicit submit verb:

```dart
expect(find.text('取消'), findsOneWidget);
expect(find.text('建立'), findsOneWidget);
expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
```

For Edit Trip, Profile, and Developer App creation, mutate one field, tap Cancel, and assert the shared confirmation appears:

```dart
await tester.enterText(find.byKey(const ValueKey('edit-title')), '京都七日行');
await tester.tap(find.text('取消'));
await tester.pumpAndSettle();
expect(find.text('捨棄未儲存的變更？'), findsOneWidget);
```

- [ ] **Step 2: Run focused tests and confirm they fail**

Run:

```bash
flutter test test/features/trips/create/create_trip_screen_test.dart test/features/trips/edit/edit_trip_screen_test.dart test/features/favorites/add_to_trip/add_to_trip_screen_test.dart test/features/trip_detail/entry_add_route_screen_test.dart test/features/trip_detail/entry_action_route_screen_test.dart test/features/account/settings/profile_edit_screen_test.dart test/features/account/developer_apps_screen_test.dart
```

Expected: FAIL because these pages still use automatic Back or Close inference.

- [ ] **Step 3: Add one route-level dirty guard**

Add a small reusable widget to `lib/app/adaptive.dart` so route pages and sheets share the same confirmation copy:

```dart
class AppUnsavedChangesController {
  Future<void> Function()? _requestPop;

  Future<void> requestPop() => _requestPop?.call() ?? Future.value();
}

class AppUnsavedChangesGuard extends StatefulWidget {
  const AppUnsavedChangesGuard({
    super.key,
    required this.controller,
    required this.hasChanges,
    required this.child,
  });

  final AppUnsavedChangesController controller;
  final bool hasChanges;
  final Widget child;

  @override
  State<AppUnsavedChangesGuard> createState() =>
      _AppUnsavedChangesGuardState();
}

class _AppUnsavedChangesGuardState extends State<AppUnsavedChangesGuard> {
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    widget.controller._requestPop = requestPop;
  }

  @override
  void didUpdateWidget(covariant AppUnsavedChangesGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._requestPop = null;
      widget.controller._requestPop = requestPop;
    }
  }

  @override
  void dispose() {
    widget.controller._requestPop = null;
    super.dispose();
  }

  Future<void> requestPop() async {
    if (!widget.hasChanges) {
      Navigator.of(context).maybePop();
      return;
    }
    final discard = await showAppConfirm(
      context,
      title: '捨棄未儲存的變更？',
      message: '離開後，本次修改不會保留。',
      confirmLabel: '捨棄',
      isDestructive: true,
    );
    if (!mounted || !discard) return;
    setState(() => _allowPop = true);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || !widget.hasChanges,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(requestPop());
    },
    child: widget.child,
  );
}
```

Each form screen owns one `AppUnsavedChangesController` and passes it to `AppUnsavedChangesGuard`; no private State type or global service is exposed.

- [ ] **Step 4: Convert each routed task AppBar**

Use explicit form semantics:

```dart
appBar: TpAppBar(
  role: TpAppBarRole.modalForm,
  title: const Text('編輯行程'),
  onCancel: dismissController.requestPop,
  primaryActionLabel: '儲存',
  primaryActionEnabled: ctrl.hasChanges && !state.saving,
  onPrimaryAction: ctrl.save,
),
```

Use these labels:

| Screen | Primary label |
|---|---|
| Create Trip | `建立` |
| Edit Trip | `儲存` |
| Add to Trip | `加入` |
| Entry Add | `加入` |
| Entry Edit | `儲存` |
| Entry Copy | `複製` |
| Entry Move | `移動` |
| Profile Edit | `儲存` |
| Developer App New | `建立` |

Remove duplicate bottom submit bars only after the header action is connected and covered by the existing feature test.

- [ ] **Step 5: Mark modal routes as fullscreen dialogs**

Change the top-level create/edit task routes to `pageBuilder` so iOS gets a modal transition while button meaning remains explicit:

```dart
GoRoute(
  path: '/new-trip',
  pageBuilder: (context, state) => const MaterialPage<void>(
    fullscreenDialog: true,
    child: CreateTripScreen(),
  ),
),
GoRoute(
  path: '/edit-trip/:tripId',
  pageBuilder: (context, state) => MaterialPage<void>(
    fullscreenDialog: true,
    child: EditTripScreen(tripId: state.pathParameters['tripId']!),
  ),
),
```

Do not use `fullscreenDialog` to infer the button; `TpAppBarRole` remains authoritative.

- [ ] **Step 6: Run routed-form tests and commit**

Run:

```bash
dart format lib/app/adaptive.dart lib/app/router.dart lib/features/trips/create/create_trip_screen.dart lib/features/trips/edit/edit_trip_screen.dart lib/features/favorites/add_to_trip/add_to_trip_screen.dart lib/features/trip_detail/entry_add_route_screen.dart lib/features/trip_detail/entry_edit_route_screen.dart lib/features/trip_detail/entry_action_route_screen.dart lib/features/account/settings/profile_edit_screen.dart lib/features/account/developer_apps_screen.dart
flutter test test/app/router_test.dart test/features/trips/create/create_trip_screen_test.dart test/features/trips/edit/edit_trip_screen_test.dart test/features/favorites/add_to_trip/add_to_trip_screen_test.dart test/features/trip_detail/entry_add_route_screen_test.dart test/features/trip_detail/entry_action_route_screen_test.dart test/features/account/settings/profile_edit_screen_test.dart test/features/account/developer_apps_screen_test.dart
```

Expected: PASS.

Commit:

```bash
git add lib/app/adaptive.dart lib/app/router.dart lib/features/trips lib/features/favorites/add_to_trip lib/features/trip_detail/entry_add_route_screen.dart lib/features/trip_detail/entry_edit_route_screen.dart lib/features/trip_detail/entry_action_route_screen.dart lib/features/account/settings/profile_edit_screen.dart lib/features/account/developer_apps_screen.dart test/app/router_test.dart test/features
git commit -m "refactor: apply modal semantics to task pages"
```

---

### Task 8: Mark detail, modal, and cold-start deep-link pages explicitly

**Files:**
- Modify: `lib/features/favorites/explore/explore_screen.dart`
- Modify: `lib/features/trip_detail/entry_poi_screen.dart`
- Modify: `lib/features/trip_detail/trip_notes_screen.dart`
- Modify: `lib/features/trip_detail/trip_print_screen.dart`
- Modify: `lib/features/trips/audit/trip_audit_screen.dart`
- Modify: `lib/features/trips/health/trip_health_screen.dart`
- Modify: `lib/features/trips/share/share_screen.dart`
- Modify: `lib/features/trips/collab/collab_screen.dart`
- Modify: `lib/features/account/settings/appearance_screen.dart`
- Modify: `lib/features/account/settings/notifications_screen.dart`
- Modify: `lib/features/account/account_sessions_screen.dart`
- Modify: `lib/features/account/connected_apps_screen.dart`
- Modify: `lib/features/account/developer_apps_screen.dart`
- Modify: `lib/features/auth/account_flow_screens.dart`
- Modify: `lib/features/auth/oauth_consent_screen.dart`
- Modify: `lib/features/invite/invite_screen.dart`
- Modify: `lib/features/share/public_share_screen.dart`
- Modify: `test/app/router_test.dart`
- Modify: `test/features/chat/chat_screen_test.dart`
- Modify: `test/features/trip_detail/trip_timeline_screen_test.dart`
- Modify: `test/features/map/global_map_screen_test.dart`
- Modify: `test/features/favorites/favorites_screen_test.dart`
- Modify: `test/features/favorites/explore/explore_screen_test.dart`
- Modify: `test/features/trip_detail/entry_poi_screen_test.dart`
- Modify: `test/features/trip_detail/trip_notes_screen_test.dart`
- Modify: `test/features/trip_detail/trip_print_screen_test.dart`
- Modify: `test/features/trips/audit/trip_audit_screen_test.dart`
- Modify: `test/features/trips/health/trip_health_screen_test.dart`
- Modify: `test/features/trips/share/share_screen_test.dart`
- Modify: `test/features/trips/collab/collab_screen_test.dart`
- Modify: `test/features/account/settings/appearance_screen_test.dart`
- Modify: `test/features/account/settings/notifications_screen_test.dart`
- Modify: `test/features/account/account_sessions_screen_test.dart`
- Modify: `test/features/account/connected_apps_screen_test.dart`
- Modify: `test/features/account/developer_apps_screen_test.dart`
- Modify: `test/features/auth/oauth_consent_screen_test.dart`
- Modify: `test/features/invite/invite_screen_test.dart`
- Modify: `test/features/share/public_share_screen_test.dart`

**Interfaces:**
- Consumes: `TpAppBarRole.standalone`, `detail`, and `modalContent`; Root destinations are migrated by Task 13
- Produces: no fake Back on cold-start deep links

- [ ] **Step 1: Add route-role assertions**

Extend `test/app/router_test.dart` with these route groups:

```dart
testWidgets('cold-start public deep links do not show a fake Back', (
  tester,
) async {
  for (final location in ['/invite?token=abc', '/s/public-token']) {
    await pumpLocation(tester, location);
    expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
  }
});
```

Use the existing router-test harness rather than adding a second router fixture.

- [ ] **Step 2: Run router tests and confirm they fail where inference leaks**

Run:

```bash
flutter test test/app/router_test.dart
```

Expected: FAIL on pages whose role still depends on whether a route can pop.

- [ ] **Step 3: Assign explicit roles**

Apply these rules:

```dart
const TpAppBar(
  role: TpAppBarRole.standalone,
  title: Text('接受邀請'),
)
```

Use `detail` for Explore, Notes, Print, Audit, Health, POI management, and read-only account settings when opened as normal routes. Use `modalContent` for Account and utility pages only when presented outside the shared sheet engine. Root destinations must use Task 13's `TpRootScaffold`, not `TpAppBar`.

For OAuth consent, keep explicit `拒絕` and `允許` actions and set the AppBar role to `standalone`; a generic Back must never bypass the authorization result.

For Invite, Public Share, password reset, and email verification cold-start pages, use `standalone` and keep their explicit CTA back to Login or into the App.

- [ ] **Step 4: Run route and screen tests and commit**

Run:

```bash
dart format lib/features test/app/router_test.dart
flutter test test/app/router_test.dart test/features/auth test/features/invite test/features/share test/features/chat test/features/map test/features/favorites test/features/trip_detail
```

Expected: PASS.

Commit:

```bash
git add lib/features test/app/router_test.dart test/features
git commit -m "refactor: declare page navigation roles"
```

---

### Task 9: Remove legacy sheet APIs and add static enforcement

**Files:**
- Modify: `lib/app/adaptive.dart`
- Modify: `test/ui/shared_ui_usage_test.dart`

**Interfaces:**
- Removes: `showAppLargeSheet` and `showAppLargeScreenSheet`
- Enforces: no feature-owned platform sheet APIs

- [ ] **Step 1: Add a failing source-usage test**

Add to `test/ui/shared_ui_usage_test.dart`:

```dart
test('features use only semantic app sheet wrappers', () {
  final featureFiles = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  const forbidden = [
    'showModalBottomSheet',
    'showCupertinoModalPopup',
    'showGeneralDialog',
    'showAppLargeSheet',
    'showAppLargeScreenSheet',
  ];

  final violations = <String>[];
  for (final file in featureFiles) {
    final source = file.readAsStringSync();
    for (final token in forbidden) {
      if (source.contains(token)) violations.add('${file.path}: $token');
    }
  }

  expect(violations, isEmpty, reason: violations.join('\n'));
});
```

- [ ] **Step 2: Run the static test and confirm the known migrations are complete**

Run:

```bash
flutter test test/ui/shared_ui_usage_test.dart
```

Expected: PASS because Tasks 3–6 migrate every current feature-owned sheet API found in the repository inventory.

- [ ] **Step 3: Remove the two legacy wrappers and their private content widgets**

Delete `showAppLargeSheet`, `showAppLargeScreenSheet`, `_AppLargeSheetContent`, and `_AppLargeScreenSheetContent`. Keep `showDatePicker`, `showTimePicker`, and `showAppActionSheet`; they represent different native interactions and are not legacy large-sheet APIs.

- [ ] **Step 4: Run formatting, analysis, and the full test suite**

Run:

```bash
dart format lib test
flutter analyze
flutter test
```

Expected: `flutter analyze` reports no issues and all tests pass.

- [ ] **Step 5: Run iOS simulator interaction verification**

Verify in both Light and Dark appearances:

```text
1. Open each of the four root tabs: no Back or Close.
2. Open trip picker: centered title, leading Cancel, checkmark, immediate selection.
3. Open Account: Close dismisses all; Appearance uses Back to Account.
4. Open Create/Edit/Add forms: Cancel plus explicit submit verb.
5. Modify a form, then test Cancel, swipe down, barrier tap, and system back: one discard confirmation.
6. Open Notes/Print/Audit/Share/Collab/Health from the trip menu: one near-full sheet and one Close path.
7. Set text size to 200%: title and toolbar actions remain reachable and do not overlap.
8. Enable Reduce Motion and Reduce Transparency: sheet remains usable and dismissible.
```

Expected: every exit performs exactly one navigation action and returns to the initiating page.

- [ ] **Step 6: Commit the enforcement and cleanup**

```bash
git add lib test
git commit -m "test: enforce shared HIG sheet presentation"
```

---

### Task 10: Give compact navigation one Liquid Glass recipe

**Files:**
- Modify: lib/ui/tp_glass_surface.dart:1-78
- Modify: lib/ui/tp_horizontal_selector.dart:1-204
- Modify: lib/features/shell/apple_root_tab_bar.dart:1-137
- Modify: lib/theme/tokens.dart:4-90
- Modify: test/ui/tripline_ui_test.dart
- Modify: test/features/shell/app_shell_test.dart

**Interfaces:**
- Produces: LiquidGlassSettings tpNavigationGlassSettings(BuildContext context)
- Produces: TpColorsLight.navigationSelection and TpColorsDark.navigationSelection
- Preserves: AppleRootTabBar as the root-destination widget
- Preserves: TpHorizontalSelector as the itinerary/map mode-and-Day widget
- Preserves: platformViewBackdrop as a rendering compatibility flag only
- Does not change: TpGlassSurface settings for POI accessories, sheets, menus, or large content surfaces

- [ ] **Step 1: Add failing selector-optics tests**

Add this test beside the existing TpHorizontalSelector tests in test/ui/tripline_ui_test.dart:

~~~dart
testWidgets(
  'navigation selector keeps one optical recipe over a platform view',
  (tester) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Column(
            children: [
              TpHorizontalSelector<int>(
                key: const ValueKey('standard-navigation-selector'),
                value: 1,
                options: const [
                  TpScopeOption(value: 0, label: '總覽'),
                  TpScopeOption(value: 1, label: 'DAY 1'),
                ],
                onSelected: (_) {},
              ),
              TpHorizontalSelector<int>(
                key: const ValueKey('map-navigation-selector'),
                platformViewBackdrop: true,
                value: 1,
                options: const [
                  TpScopeOption(value: 0, label: '總覽'),
                  TpScopeOption(value: 1, label: 'DAY 1'),
                ],
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    GlassContainer trackFor(String key) => tester.widget<GlassContainer>(
      find
          .descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(GlassContainer),
          ),
    );

    final standard = trackFor('standard-navigation-selector');
    final map = trackFor('map-navigation-selector');
    expect(standard.platformViewBackdrop, isFalse);
    expect(map.platformViewBackdrop, isTrue);
    expect(map.settings?.glassColor, standard.settings?.glassColor);
    expect(map.settings?.thickness, standard.settings?.thickness);
    expect(map.settings?.blur, standard.settings?.blur);
    expect(map.settings?.lightIntensity, standard.settings?.lightIntensity);
    expect(map.settings?.ambientStrength, standard.settings?.ambientStrength);
    expect(map.settings?.refractiveIndex, standard.settings?.refractiveIndex);
    expect(map.settings?.saturation, standard.settings?.saturation);
    expect(
      map.settings?.standardOpacityMultiplier,
      standard.settings?.standardOpacityMultiplier,
    );

    final selected = tester.widget<GlassButton>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey('standard-navigation-selector'),
            ),
            matching: find.byType(GlassButton),
          ),
    );
    expect(selected.settings?.blur, standard.settings?.blur);
    expect(
      selected.settings?.refractiveIndex,
      standard.settings?.refractiveIndex,
    );
  },
);
~~~

- [ ] **Step 2: Add a failing Root Tab regression test**

Add this test to test/features/shell/app_shell_test.dart:

~~~dart
testWidgets('root branches keep one navigation glass recipe', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: buildShellRouter(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  GlassTabBar rootBar() => tester.widget<GlassTabBar>(
    find.descendant(
      of: find.byKey(const ValueKey('apple-root-tab-bar')),
      matching: find.byType(GlassTabBar),
    ),
  );

  final standard = rootBar();
  expect(standard.platformViewBackdrop, isFalse);

  await tester.tap(find.bySemanticsLabel('地圖'));
  await tester.pumpAndSettle();

  final map = rootBar();
  expect(map.platformViewBackdrop, isTrue);
  expect(map.settings?.glassColor, standard.settings?.glassColor);
  expect(map.settings?.thickness, standard.settings?.thickness);
  expect(map.settings?.blur, standard.settings?.blur);
  expect(map.settings?.lightIntensity, standard.settings?.lightIntensity);
  expect(map.settings?.ambientStrength, standard.settings?.ambientStrength);
  expect(map.settings?.refractiveIndex, standard.settings?.refractiveIndex);
  expect(
    map.settings?.standardOpacityMultiplier,
    standard.settings?.standardOpacityMultiplier,
  );
  expect(map.indicatorSettings?.blur, map.settings?.blur);
  expect(
    map.indicatorSettings?.refractiveIndex,
    map.settings?.refractiveIndex,
  );
  expect(TpColorsLight.rootTabSelection, TpColorsLight.dayThumb);
});
~~~

- [ ] **Step 3: Run the focused tests and confirm the existing mismatch**

Run:

~~~bash
flutter test test/ui/tripline_ui_test.dart test/features/shell/app_shell_test.dart
~~~

Expected: FAIL because TpHorizontalSelector currently changes blur and refractive index when platformViewBackdrop is enabled, and both selected indicators currently override the base optics.

- [ ] **Step 4: Add the one compact-navigation settings function**

Add above TpGlassSurface in lib/ui/tp_glass_surface.dart:

~~~dart
LiquidGlassSettings tpNavigationGlassSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return LiquidGlassSettings(
    glassColor: isDark
        ? const Color(0x70121214)
        : const Color(0x70FFFBF5),
    thickness: 16,
    blur: 16,
    chromaticAberration: 0,
    lightIntensity: isDark ? 0.56 : 0.62,
    ambientStrength: isDark ? 0.06 : 0.10,
    refractiveIndex: 1.06,
    saturation: 1.02,
    standardOpacityMultiplier: isDark ? 0.52 : 0.40,
    platformViewFallbackColor: isDark
        ? const Color(0x66121214)
        : const Color(0x5CFFFBF5),
  );
}
~~~

Do not route TpGlassSurface.build through this function. Large surfaces intentionally retain their thicker, size-aware recipe.

- [ ] **Step 5: Make Root Tab and Day selector consume the shared settings**

In lib/features/shell/apple_root_tab_bar.dart, import the existing glass module:

~~~dart
import '../../ui/tp_glass_surface.dart';
~~~

Replace the local glassTint, fallbackTint, and LiquidGlassSettings construction with:

~~~dart
final glassSettings = tpNavigationGlassSettings(context);
final selectionTint = isDark
    ? TpColorsDark.navigationSelection
    : TpColorsLight.navigationSelection;
~~~

Use the same selection tint and base optics:

~~~dart
indicatorColor: selectionTint,
indicatorSettings: glassSettings.copyWith(
  glassColor: selectionTint,
  platformViewFallbackColor: selectionTint,
),
~~~

Keep this property unchanged because GoogleMap still needs the alternate rendering path:

~~~dart
platformViewBackdrop: selectedIndex == 2,
~~~

In lib/ui/tp_horizontal_selector.dart, import the existing glass module:

~~~dart
import 'tp_glass_surface.dart';
~~~

Replace the local track settings construction with:

~~~dart
final trackSettings = tpNavigationGlassSettings(context);
~~~

Replace the selected settings with a tint-only copy:

~~~dart
final selectedColor = isDark
    ? TpColorsDark.navigationSelection
    : TpColorsLight.navigationSelection;
final selectedSettings = trackSettings.copyWith(
  glassColor: selectedColor,
  platformViewFallbackColor: selectedColor,
);
~~~

Keep GlassContainer.platformViewBackdrop wired to widget.platformViewBackdrop. Delete the conditional blur and refractive-index values; no feature-level call site changes are needed.

- [ ] **Step 6: Make the selected tint one token per appearance**

Replace the Light selection tokens in lib/theme/tokens.dart with:

~~~dart
static const navigationSelection = Color(0x2EA97A4A);
static const rootTabSelection = navigationSelection;
static const dayThumb = navigationSelection;
~~~

Replace the Dark selection tokens with:

~~~dart
static const navigationSelection = Color(0x38E0BC90);
static const rootTabSelection = navigationSelection;
static const dayThumb = navigationSelection;
~~~

These values preserve the Tripline warm accent at 18% in Light and 22% in Dark. Do not add a second selection token unless a future control has a different semantic role.

- [ ] **Step 7: Format, test, and visually verify the four required states**

Run:

~~~bash
dart format lib/ui/tp_glass_surface.dart lib/ui/tp_horizontal_selector.dart lib/features/shell/apple_root_tab_bar.dart lib/theme/tokens.dart test/ui/tripline_ui_test.dart test/features/shell/app_shell_test.dart
flutter test test/ui/tripline_ui_test.dart test/features/shell/app_shell_test.dart
flutter analyze
~~~

Expected: focused tests pass and flutter analyze reports no issues.

Capture and compare these simulator states at the same device size:

~~~text
1. Light 行程：Root Tab + 行程/地圖/Day selector.
2. Light 地圖：Root Tab + 行程/地圖/Day selector over Google Map.
3. Dark 行程：same geometry and navigation-selection tint behavior.
4. Dark 地圖：same optics with PlatformView fallback.
~~~

Accept natural brightness differences caused by the content beneath the glass. Reject any difference in 44pt height, capsule radius, border treatment, blur strength, selection opacity, or typography.

- [ ] **Step 8: Commit the compact-navigation glass source**

~~~bash
git add lib/ui/tp_glass_surface.dart lib/ui/tp_horizontal_selector.dart lib/features/shell/apple_root_tab_bar.dart lib/theme/tokens.dart test/ui/tripline_ui_test.dart test/features/shell/app_shell_test.dart
git commit -m "refactor: share navigation glass settings"
~~~

### Task 11: Unify weather state and make Timeline metadata adaptive

**Files:**
- Modify: `lib/features/trip_detail/day_weather.dart:272-453`
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart:630-690`
- Modify: `lib/features/trip_detail/widgets/timeline_entry_tile.dart:19-281`
- Modify: `test/features/trip_detail/day_weather_test.dart`
- Modify: `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`
- Modify: `test/features/trip_detail/trip_timeline_screen_test.dart`

**Interfaces:**
- Reuses: `DayWeatherPreview`, `DayWeatherCard`, `dayWeatherProvider`, `TimelineEntry.startTime`, `TimelineEntry.endTime`, `EntryPoiInfo.category`, and `poiCategoryLabel`
- Produces: one weather surface that changes from labeled sample to live data in place
- Produces: a two-line start/end range, localized Google category row, complete VoiceOver range, and standard/accessibility Timeline layouts
- Preserves: existing forecast fetcher, weather expansion, POI tone, rating, duration, edit callback, and rail numbering

- [ ] **Step 1: Add failing weather-state tests**

Add `dart:async` to `test/features/trip_detail/day_weather_test.dart`, then add:

```dart
testWidgets('DayWeatherCard keeps the labeled preview until live data arrives', (
  tester,
) async {
  final completer = Completer<TripWeatherHourly>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dayWeatherFetcherProvider.overrideWithValue(
          (request) => completer.future,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: DayWeatherCard(day: _okinawaDay)),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('day-weather-preview-1')), findsOneWidget);
  expect(find.text('天氣示意'), findsOneWidget);
  expect(find.text('正在更新預報'), findsOneWidget);

  completer.complete(
    TripWeatherHourly(
      temps: [for (var h = 0; h < 24; h++) 24],
      rains: [for (var h = 0; h < 24; h++) 20],
      codes: [for (var h = 0; h < 24; h++) 1],
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('day-weather-live-1')), findsOneWidget);
  expect(find.text('天氣示意'), findsNothing);
});

testWidgets('forecast outside the range stays explicitly labeled as sample', (
  tester,
) async {
  final date = DateTime.now().add(const Duration(days: 30));
  final dateText =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final day = TripDay(
    id: 99,
    dayNum: 3,
    date: dateText,
    version: 1,
    timeline: _okinawaDay.timeline,
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DayWeatherCard(day: day)),
      ),
    ),
  );

  expect(find.text('天氣示意'), findsOneWidget);
  expect(find.text('天氣預報將於出發前 16 天開放'), findsOneWidget);
});
```

Run:

```bash
flutter test test/features/trip_detail/day_weather_test.dart
```

Expected: FAIL because loading and out-of-range states currently collapse to `_WeatherMessageRow` instead of retaining the preview geometry.

- [ ] **Step 2: Make `DayWeatherCard` the only Timeline weather entry point**

Extend `DayWeatherPreview` without adding another preview widget:

```dart
const DayWeatherPreview({
  super.key,
  required this.dayNum,
  this.statusText,
});

final int dayNum;
final String? statusText;
```

Render `statusText` below the existing condition/rain row using `bodySmall` and `onSurfaceVariant`. Replace `_DayWeatherCardState.build` with one `AnimatedSwitcher` state surface:

```dart
@override
Widget build(BuildContext context) {
  final dayDate = widget.day.date;
  final weatherDay = buildWeatherDay(widget.day);
  if (dayDate == null || weatherDay == null) {
    return DayWeatherPreview(
      dayNum: widget.day.dayNum,
      statusText: '尚無可用預報位置',
    );
  }

  final diff = _daysUntil(dayDate);
  if (diff != null && diff > 16) {
    return DayWeatherPreview(
      dayNum: widget.day.dayNum,
      statusText: '天氣預報將於出發前 16 天開放',
    );
  }

  final request = TripWeatherRequest(
    dayId: widget.day.id,
    dayDate: dayDate,
    weatherDay: weatherDay,
    tripStart: widget.tripStart,
    tripEnd: widget.tripEnd,
    timezone: widget.timezone,
  );

  final content = ref.watch(dayWeatherProvider(request)).when<Widget>(
    loading: () => DayWeatherPreview(
      dayNum: widget.day.dayNum,
      statusText: '正在更新預報',
    ),
    error: (error, stackTrace) => DayWeatherPreview(
      dayNum: widget.day.dayNum,
      statusText: '暫時無法取得預報',
    ),
    data: (hourly) {
      if (!hourly.hasData) {
        return DayWeatherPreview(
          dayNum: widget.day.dayNum,
          statusText: '目前沒有可用預報',
        );
      }
      final summary = _WeatherSummary.fromHourly(hourly);
      return KeyedSubtree(
        key: ValueKey('day-weather-live-${widget.day.dayNum}'),
        child: _WeatherForecastPanel(
          dayNum: widget.day.dayNum,
          hourly: hourly,
          summary: summary,
          locationCount: weatherDay.locations
              .map((location) => location.name)
              .toSet()
              .length,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
      );
    },
  );

  return AnimatedSwitcher(
    duration: TpMotion.resolve(context, const Duration(milliseconds: 200)),
    switchInCurve: TpMotion.appleEase,
    switchOutCurve: TpMotion.appleEase,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: child,
    ),
    child: content,
  );
}
```

Replace `DayWeatherPreview(dayNum: day.dayNum)` in `_DaySection` with:

```dart
DayWeatherCard(day: day),
```

Do not keep both widgets in the Timeline.

- [ ] **Step 3: Add failing time-range, category, and large-text tests**

Extend the `pumpTile` helper in `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`:

```dart
Future<void> pumpTile(
  WidgetTester tester,
  TimelineEntry entry, {
  int number = 1,
  bool isFirst = false,
  bool isLast = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: TimelineEntryTile(
            entry: entry,
            number: number,
            isFirst: isFirst,
            isLast: isLast,
          ),
        ),
      ),
    ),
  );
}
```

Add:

```dart
testWidgets('shows start and end time and announces the complete range', (
  tester,
) async {
  final semantics = tester.ensureSemantics();
  await pumpTile(
    tester,
    const TimelineEntry(
      id: 40,
      sortOrder: 0,
      version: 1,
      startTime: '09:30',
      endTime: '11:00',
      title: '清水寺',
    ),
  );

  expect(find.text('09:30'), findsOneWidget);
  expect(find.text('– 11:00'), findsOneWidget);
  expect(find.bySemanticsLabel(contains('09:30 到 11:00')), findsOneWidget);
  semantics.dispose();
});

testWidgets('Google primary type is the first secondary row', (tester) async {
  await pumpTile(
    tester,
    const TimelineEntry(
      id: 41,
      sortOrder: 0,
      version: 1,
      title: '一蘭拉麵',
      master: EntryPoiInfo(
        poiId: 501,
        type: 'restaurant',
        category: 'ramen_restaurant',
      ),
    ),
  );

  expect(find.byKey(const ValueKey('entry-category-41')), findsOneWidget);
  expect(find.text('拉麵店'), findsOneWidget);
  expect(find.text('ramen_restaurant'), findsNothing);
});

testWidgets('accessibility text uses stacked layout without overflow', (
  tester,
) async {
  await pumpTile(
    tester,
    const TimelineEntry(
      id: 42,
      sortOrder: 0,
      version: 1,
      startTime: '09:30',
      endTime: '11:00',
      title: '很長但仍需要完整閱讀的景點名稱',
      master: EntryPoiInfo(
        poiId: 502,
        category: 'tourist_attraction',
      ),
    ),
    textScaler: const TextScaler.linear(2),
  );

  expect(
    find.byKey(const ValueKey('timeline-entry-accessibility-42')),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
  expect(find.text('很長但仍需要完整閱讀的景點名稱'), findsOneWidget);
});
```

Run:

```bash
flutter test test/features/trip_detail/widgets/timeline_entry_tile_test.dart
```

Expected: FAIL because only the start time is displayed, category is mixed into a compact Wrap, and the row never switches layout.

- [ ] **Step 4: Adapt `TimelineEntryTile` instead of clamping text**

Inside `TimelineEntryTile.build`, derive the values once:

```dart
final startTime = (entry.startTime ?? entry.time ?? '').trim();
final endTime = entry.endTime?.trim() ?? '';
final categoryLabel =
    poiCategoryLabel(entry.master?.category) ??
    kPoiTypeLabels[entry.master?.type];
final timeSemantics = startTime.isEmpty
    ? null
    : endTime.isEmpty
        ? startTime
        : '$startTime 到 $endTime';
final accessibilityLayout =
    MediaQuery.textScalerOf(context).scale(17) >= 23;
```

Replace the hard-coded time `TextStyle(fontSize: 12)` with a private `_EntryTimeRange` that uses `theme.textTheme.labelMedium`, tabular figures, and renders `– $endTime` only when it exists. Extract the existing rail markup into `_TimelineRail` in the same file so both layouts share the same numbered line.

Build the standard layout as the existing time／rail／card row. For accessibility sizes, use this reduced-column structure:

```dart
return KeyedSubtree(
  key: ValueKey('timeline-entry-accessibility-${entry.id}'),
  child: IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimelineRail(
          entryId: entry.id,
          number: number,
          isFirst: isFirst,
          isLast: isLast,
          color: tone.deep,
          lineColor: railLineColor,
        ),
        const SizedBox(width: TpSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EntryTimeRange(startTime: startTime, endTime: endTime),
              const SizedBox(height: TpSpacing.s2),
              entryContent,
              if (trailing != null)
                Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
              const SizedBox(height: TpSpacing.s3),
            ],
          ),
        ),
      ],
    ),
  ),
);
```

Use `timeSemantics` in the existing combined semantics label. Do not set a global maximum text scale.

In `_EntryCard`, remove category from `metaItems` and render it immediately below the title:

```dart
if (categoryLabel != null)
  Padding(
    padding: const EdgeInsets.only(top: TpSpacing.s1),
    child: Row(
      key: ValueKey('entry-category-${entry.id}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.tag,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            categoryLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  ),
```

Keep duration, master name, and rating in the following `Wrap`. At accessibility size, allow the title and category to grow vertically; do not add a new truncation limit.

- [ ] **Step 5: Run focused tests and commit Timeline data presentation**

Run:

```bash
dart format lib/features/trip_detail/day_weather.dart lib/features/trip_detail/trip_timeline_screen.dart lib/features/trip_detail/widgets/timeline_entry_tile.dart test/features/trip_detail/day_weather_test.dart test/features/trip_detail/widgets/timeline_entry_tile_test.dart test/features/trip_detail/trip_timeline_screen_test.dart
flutter test test/features/trip_detail/day_weather_test.dart test/features/trip_detail/widgets/timeline_entry_tile_test.dart test/features/trip_detail/trip_timeline_screen_test.dart
```

Expected: PASS; no fake weather is presented as live data, time/category semantics are complete, and the 200% layout has no overflow.

Commit:

```bash
git add lib/features/trip_detail/day_weather.dart lib/features/trip_detail/trip_timeline_screen.dart lib/features/trip_detail/widgets/timeline_entry_tile.dart test/features/trip_detail/day_weather_test.dart test/features/trip_detail/widgets/timeline_entry_tile_test.dart test/features/trip_detail/trip_timeline_screen_test.dart
git commit -m "feat: adapt itinerary timeline content"
```

---

### Task 12: Replace the Timeline column with one section-linked Sliver scroll

**Files:**
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart:202-886`
- Modify: `test/features/trip_detail/trip_timeline_screen_test.dart`

**Interfaces:**
- Reuses: `TpHorizontalSelector<int>`, `TpMotion`, existing Day and entry keys, `_DaySection`, and the Task 4 drag callbacks
- Produces: pinned `_DaySelectorHeaderDelegate`, one `CustomScrollView`, local scroll-linked `_activeDayNum`, one `_TimelineScrollEdge`, and local optimistic entry lists
- Preserves: map action, initial Day/entry deep-link focus, edit mode, same-Day reorder, cross-Day move, travel recomputation, and provider refresh
- Does not produce: a second Day selector, vertical paging, nested scrolling, a scroll-spy dependency, or provider mutation during layout/build

- [ ] **Step 1: Add failing pinned-selector and scroll-link tests**

Add a two-section fixture to `test/features/trip_detail/trip_timeline_screen_test.dart`:

```dart
import 'package:tripline/ui/tp_horizontal_selector.dart';
```

```dart
List<TripDay> _scrollSpyDays() => [
  for (var day = 1; day <= 2; day++)
    TripDay(
      id: day,
      dayNum: day,
      date: '2026-07-${(17 + day).toString().padLeft(2, '0')}',
      version: 1,
      timeline: [
        for (var index = 0; index < 12; index++)
          TimelineEntry(
            id: day * 100 + index,
            sortOrder: index,
            startTime: '${(8 + index).toString().padLeft(2, '0')}:00',
            endTime: '${(9 + index).toString().padLeft(2, '0')}:00',
            title: 'DAY $day 景點 $index',
            version: 1,
          ),
      ],
    ),
];
```

Add:

```dart
testWidgets('itinerary uses one pinned Sliver selector without overview', (
  tester,
) async {
  await _pumpTimeline(tester, fetchDays: _scrollSpyDays);
  await tester.pumpAndSettle();

  expect(find.byType(CustomScrollView), findsOneWidget);
  expect(find.byType(PageView), findsNothing);
  expect(
    find.byKey(const ValueKey('trip-timeline-day-overview')),
    findsNothing,
  );

  final selector = find.byKey(
    const ValueKey('trip-timeline-view-day-selector'),
  );
  final topBefore = tester.getTopLeft(selector).dy;
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
  await tester.pumpAndSettle();
  expect(tester.getTopLeft(selector).dy, closeTo(topBefore, 0.5));
});

testWidgets('vertical scroll updates Day selection and tapping Day scrolls back', (
  tester,
) async {
  await _pumpTimeline(tester, fetchDays: _scrollSpyDays);
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('day-section-2')),
    400,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('trip-timeline-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();

  var selector = tester.widget<TpHorizontalSelector<int>>(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
  );
  expect(selector.value, 2);

  await tester.tap(find.byKey(const ValueKey('day-pill-1')));
  await tester.pumpAndSettle();
  selector = tester.widget<TpHorizontalSelector<int>>(
    find.byKey(const ValueKey('trip-timeline-view-day-selector')),
  );
  expect(selector.value, 1);
  expect(
    tester.getTopLeft(find.byKey(const ValueKey('day-section-1'))).dy,
    greaterThanOrEqualTo(tester.getBottomLeft(
      find.byKey(const ValueKey('trip-timeline-view-day-selector')),
    ).dy - 1),
  );
});
```

Run:

```bash
flutter test test/features/trip_detail/trip_timeline_screen_test.dart \
  --plain-name 'itinerary uses one pinned Sliver selector without overview'
flutter test test/features/trip_detail/trip_timeline_screen_test.dart \
  --plain-name 'vertical scroll updates Day selection and tapping Day scrolls back'
```

Expected: FAIL because the current selector is outside a `SingleChildScrollView`, still includes `總覽`, and scrolling never changes `_activeDayNum`.

- [ ] **Step 2: Build one pinned `CustomScrollView` and local Day synchronization**

Add the rendering imports to `trip_timeline_screen.dart`:

```dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart' show RenderAbstractViewport;
```

Add to `_TimelineBodyState`:

```dart
static const _selectorExtent = 64.0;
final _selectorAnchorKey = GlobalKey();
bool _daySyncScheduled = false;
int? _programmaticDayNum;

bool _handleTimelineScroll(ScrollNotification notification) {
  if (notification.depth != 0 || _programmaticDayNum != null) return false;
  if (_daySyncScheduled) return false;
  _daySyncScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _daySyncScheduled = false;
    if (mounted && _programmaticDayNum == null) _syncActiveDayFromViewport();
  });
  return false;
}

void _syncActiveDayFromViewport() {
  final selectorBox =
      _selectorAnchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (selectorBox == null || !selectorBox.hasSize || widget.days.isEmpty) return;
  final activationY = selectorBox.localToGlobal(
    Offset(0, selectorBox.size.height),
  ).dy;
  var next = widget.days.first.dayNum;
  for (final day in widget.days) {
    final box = _daySectionKeys[day.dayNum]?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) continue;
    if (box.localToGlobal(Offset.zero).dy <= activationY + 1) {
      next = day.dayNum;
    } else {
      break;
    }
  }
  if (next != _activeDayNum) setState(() => _activeDayNum = next);
}
```

Replace `_scrollToDay` with a pinned-header-aware offset calculation:

```dart
Future<void> _scrollToDay(int dayNum) async {
  final targetContext = _daySectionKeys[dayNum]?.currentContext;
  if (targetContext == null || !_scrollController.hasClients) return;
  final object = targetContext.findRenderObject();
  if (object == null) return;
  final viewport = RenderAbstractViewport.of(object);
  final reveal = viewport.getOffsetToReveal(object, 0).offset;
  final position = _scrollController.position;
  final target = (reveal - _selectorExtent).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  _programmaticDayNum = dayNum;
  setState(() => _activeDayNum = dayNum);
  await _scrollController.animateTo(
    target,
    duration: TpMotion.resolve(targetContext, TpMotion.normal),
    curve: TpMotion.appleEase,
  );
  _programmaticDayNum = null;
  if (mounted) _syncActiveDayFromViewport();
}
```

Replace `_TimelineBodyState.build` with one `NotificationListener` and `CustomScrollView`:

```dart
return NotificationListener<ScrollNotification>(
  onNotification: _handleTimelineScroll,
  child: CustomScrollView(
    key: const ValueKey('trip-timeline-scroll'),
    controller: _scrollController,
    slivers: [
      SliverPersistentHeader(
        pinned: true,
        delegate: _DaySelectorHeaderDelegate(
          extent: _selectorExtent,
          child: KeyedSubtree(
            key: _selectorAnchorKey,
            child: _buildDaySelector(context),
          ),
        ),
      ),
      for (final day in widget.days)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s4),
          sliver: SliverToBoxAdapter(
            child: KeyedSubtree(
              key: ValueKey('day-section-${day.dayNum}'),
              child: _DaySection(
                key: _daySectionKeys[day.dayNum],
                day: day,
                allDays: widget.days,
                tripId: widget.tripId,
                entryKeys: _entryKeys,
                focusedEntryId: widget.initialEntryId,
                scrollController: _scrollController,
                isEditing: widget.isEditing,
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: TpSpacing.s8)),
    ],
  ),
);
```

Move the selector markup to this method; keep the `地圖` action and remove the `value: 0` overview option:

```dart
Widget _buildDaySelector(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(
      TpSpacing.s3,
      TpSpacing.s2,
      TpSpacing.s3,
      TpSpacing.s1,
    ),
    child: TpHorizontalSelector<int>(
      key: const ValueKey('trip-timeline-view-day-selector'),
      value: _activeDayNum,
      options: [
        const TpScopeOption(
          value: -1,
          label: '地圖',
          icon: CupertinoIcons.map,
          isAction: true,
          key: ValueKey('trip-timeline-map'),
        ),
        for (final day in widget.days)
          TpScopeOption(
            value: day.dayNum,
            label: 'DAY ${day.dayNum}',
            key: ValueKey('day-pill-${day.dayNum}'),
          ),
      ],
      onSelected: (value) {
        if (value == -1) {
          final dayNum = _activeDayNum > 0
              ? _activeDayNum
              : widget.days.firstOrNull?.dayNum;
          GoRouter.maybeOf(context)?.go(
            '/map?tripId=${Uri.encodeQueryComponent(widget.tripId)}'
            '${dayNum == null ? '' : '&day=$dayNum'}',
          );
          return;
        }
        HapticFeedback.selectionClick();
        unawaited(_scrollToDay(value));
      },
    ),
  );
}
```

Add a private `SliverPersistentHeaderDelegate` in the same file. Its child uses the existing `TpHorizontalSelector` and one 12pt `_TimelineScrollEdge` below it:

```dart
class _DaySelectorHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DaySelectorHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        if (overlapsContent)
          const Positioned(
            left: 0,
            right: 0,
            bottom: -12,
            height: 12,
            child: _TimelineScrollEdge(),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DaySelectorHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}
```

Implement the one soft edge in the same file:

```dart
class _TimelineScrollEdge extends StatelessWidget {
  const _TimelineScrollEdge();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return IgnorePointer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: 0.12),
                  surface.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Do not add a shadow, opaque toolbar background, or second glass settings object.

- [ ] **Step 3: Add local optimistic lists for reorder settle and rollback**

Add a local presentation map to `_TimelineBodyState`; it mirrors provider data but does not replace the repository as source of truth:

```dart
late Map<int, List<TimelineEntry>> _visibleEntriesByDayId;

Map<int, List<TimelineEntry>> _entriesFromDays(List<TripDay> days) => {
  for (final day in days) day.id: List<TimelineEntry>.of(day.timeline),
};

Map<int, List<TimelineEntry>> _snapshotEntries() => {
  for (final entry in _visibleEntriesByDayId.entries)
    entry.key: List<TimelineEntry>.of(entry.value),
};

void _restoreEntries(Map<int, List<TimelineEntry>> snapshot) {
  if (!mounted) return;
  setState(() => _visibleEntriesByDayId = snapshot);
}
```

Initialize it in `initState` and replace it from `widget.days` in `didUpdateWidget` when the provider emits a new list.

Add the two preview callbacks:

```dart
Map<int, List<TimelineEntry>> _previewReorder(
  int dayId,
  int oldIndex,
  int newIndex,
) {
  final snapshot = _snapshotEntries();
  final entries = List<TimelineEntry>.of(_visibleEntriesByDayId[dayId] ?? const []);
  if (newIndex > oldIndex) newIndex -= 1;
  final moved = entries.removeAt(oldIndex);
  entries.insert(newIndex, moved);
  setState(() => _visibleEntriesByDayId[dayId] = entries);
  return snapshot;
}

Map<int, List<TimelineEntry>> _previewCrossDayMove({
  required TimelineEntry entry,
  required int sourceDayId,
  required int targetDayId,
  int? beforeEntryId,
}) {
  final snapshot = _snapshotEntries();
  final source = List<TimelineEntry>.of(
    _visibleEntriesByDayId[sourceDayId] ?? const [],
  )..removeWhere((item) => item.id == entry.id);
  final target = List<TimelineEntry>.of(
    _visibleEntriesByDayId[targetDayId] ?? const [],
  );
  final index = beforeEntryId == null
      ? target.length
      : target.indexWhere((item) => item.id == beforeEntryId);
  target.insert(index < 0 ? target.length : index, entry);
  setState(() {
    _visibleEntriesByDayId[sourceDayId] = source;
    _visibleEntriesByDayId[targetDayId] = target;
  });
  return snapshot;
}
```

Pass each visible list plus these callbacks into `_DaySection`. `_reorder` and `_moveEntryToDay` take a snapshot before the repository call. On success keep the preview until the provider emits canonical data; on exception call `_restoreEntries(snapshot)` before showing the existing notice. This gives `ReorderableListView` and cross-Day drops an immediate settling layout without changing API payloads or adding model `copyWith` methods.

Add one failure test that stubs `reorderEntries` to throw, performs a move, and expects the original entry to return to its original Day after `pumpAndSettle`.

- [ ] **Step 4: Verify scrolling, motion accessibility, and commit**

Run:

```bash
dart format lib/features/trip_detail/trip_timeline_screen.dart test/features/trip_detail/trip_timeline_screen_test.dart
flutter test test/features/trip_detail/trip_timeline_screen_test.dart
flutter test test/features/trip_detail/day_weather_test.dart test/features/trip_detail/widgets/timeline_entry_tile_test.dart test/ui/tripline_ui_test.dart
flutter analyze
```

Expected: PASS; the itinerary has one vertical `CustomScrollView`, no overview option, pinned selector geometry, scroll-linked active Day, successful programmatic Day navigation, immediate reorder presentation, and failure rollback.

Capture the same itinerary at Light, Dark, 200% text, Reduce Motion, and Reduce Transparency. Reject selector movement, duplicate edge blur, content hidden under the pinned selector, queued Day animations, or Timeline overflow.

Commit:

```bash
git add lib/features/trip_detail/trip_timeline_screen.dart test/features/trip_detail/trip_timeline_screen_test.dart
git commit -m "refactor: link itinerary days to sliver scroll"
```

---

### Task 13: Replace every Root page with one fixed full-width Glass Header

**Files:**
- Create: `lib/ui/tp_root_scaffold.dart`
- Modify: `lib/ui/trip_title_button.dart`
- Modify: `lib/ui/tp_glass_surface.dart`
- Delete: `lib/ui/tp_root_scroll_scaffold.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Verify: `lib/features/chat/chat_message.dart`
- Modify: `lib/features/trips/trips_list_screen.dart`
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart`
- Modify: `lib/features/map/global_map_screen.dart`
- Modify: `lib/features/trip_detail/trip_map_screen.dart`
- Modify: `lib/features/favorites/favorites_screen.dart`
- Modify: `lib/features/shell/app_shell.dart`
- Create: `test/ui/tp_root_scaffold_test.dart`
- Modify: `test/features/chat/chat_screen_test.dart`
- Modify: `test/features/trips/trips_list_screen_test.dart`
- Modify: `test/features/trip_detail/trip_timeline_screen_test.dart`
- Modify: `test/features/map/global_map_screen_test.dart`
- Modify: `test/features/favorites/favorites_screen_test.dart`
- Modify: `test/ui/shared_ui_usage_test.dart`

**Interfaces:**
- Produces: `TpRootHeaderConfig`, `TpRootGeometry`, `TpRootScaffold`, `TpRootGlassHeader`, and `TpRootScrollView`
- Reuses: `TpHeaderTitle`, `TpHeaderActionRow`, `TpToolbarGlassButton`, `TpAccountAvatarButton`, `TripTitleButton`, and Task 10's shared glass settings
- Removes: `TpRootScrollScaffold`, `_MapRootAppBar`, root `TpAppBar` usage, and feature-owned header padding
- Preserves: current chat composer, existing `ChatMessage.submittedBy`／`senderName` data flow, Timeline state, map overlays, favorites filters, Root Tab routing, and account/sheet actions

- [ ] **Step 1: Add failing Root geometry and semantics tests**

Create `test/ui/tp_root_scaffold_test.dart` with the shared contract:

```dart
testWidgets('root header is one fixed capsule over full bleed content', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: TpRootScaffold(
          header: const TpRootHeaderConfig(title: Text('京都五日行')),
          body: const ColoredBox(
            key: ValueKey('full-bleed-body'),
            color: Colors.blue,
          ),
        ),
      ),
    ),
  );

  final header = find.byKey(const ValueKey('tp-root-glass-header'));
  expect(header, findsOneWidget);
  expect(tester.getRect(header).top, 52); // safe-area 44 + 8
  expect(tester.getRect(header).left, 16);
  expect(tester.getSize(header).height, 56);
  expect(find.byType(SliverAppBar), findsNothing);
  expect(find.byType(AppBar), findsNothing);
  expect(
    tester.getTopLeft(find.byKey(const ValueKey('full-bleed-body'))).dy,
    0,
  );
});

testWidgets('root header has one glass surface and supports Favorites actions', (
  tester,
) async {
  await tester.pumpWidget(_rootHarness(actionCount: 4));
  expect(
    find.descendant(
      of: find.byKey(const ValueKey('tp-root-glass-header')),
      matching: find.byKey(const ValueKey('tp-glass-surface')),
    ),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('tp-root-header-action-0')), findsOneWidget);
  expect(find.byKey(const ValueKey('tp-root-header-action-3')), findsOneWidget);
  expect(() => _buildRoot(actionCount: 5), throwsAssertionError);
});

testWidgets('scroll content starts clear then passes under fixed header', (
  tester,
) async {
  await tester.pumpWidget(_rootScrollHarness());
  final headerBefore = tester.getRect(
    find.byKey(const ValueKey('tp-root-glass-header')),
  );
  final firstBefore = tester.getRect(find.text('第一筆'));
  expect(firstBefore.top, greaterThan(headerBefore.bottom));

  await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
  await tester.pump();

  expect(
    tester.getRect(find.byKey(const ValueKey('tp-root-glass-header'))),
    headerBefore,
  );
  expect(find.byKey(const ValueKey('tp-root-soft-edge')), findsOneWidget);
});
```

Extend feature tests with these visible-title contracts:

```dart
expect(find.byKey(const ValueKey('tp-root-glass-header')), findsOneWidget);
expect(find.byKey(const ValueKey('trip-title-button')), findsOneWidget); // chat/trip/map
expect(find.text('收藏'), findsOneWidget); // favorites only
expect(find.byKey(const ValueKey('tp-app-bar-back')), findsNothing);
expect(find.byKey(const ValueKey('tp-app-bar-close')), findsNothing);
```

Add a Dynamic Type test at 200% and an action-spacing assertion: every action has a 44pt target, the gap is 8pt, and the final action ends 16pt from the capsule's content edge.

Extend `favorites_screen_test.dart` with the approved HIG behavior:

```dart
expect(find.byKey(const ValueKey('favorites-search-action')), findsOneWidget);
expect(find.byKey(const ValueKey('favorites-sort-menu')), findsOneWidget);
expect(find.byKey(const ValueKey('favorites-add-action')), findsOneWidget);

await tester.tap(find.byKey(const ValueKey('favorites-search-action')));
await tester.pump();
expect(find.byKey(const ValueKey('favorites-search-input')), findsOneWidget);
expect(find.byKey(const ValueKey('favorites-add-action')), findsNothing);
expect(find.byKey(const ValueKey('favorites-search-close')), findsOneWidget);

await tester.tap(find.byKey(const ValueKey('favorites-sort-menu')));
await tester.pumpAndSettle();
expect(find.text('最近加入'), findsOneWidget);
expect(find.text('最早加入'), findsOneWidget);
expect(find.text('名稱'), findsOneWidget);
expect(find.text('地區'), findsOneWidget);
expect(find.text('篩選條件'), findsOneWidget);
```

Extend `chat_screen_test.dart` with the approved participant identity and full-bleed contracts:

```dart
expect(find.text('Ray Chiu'), findsOneWidget); // current-account display name
expect(find.text('lean'), findsOneWidget); // collaborator email fallback

final collaborator = find.byKey(
  const ValueKey('chat-message-collaborator'),
);
final collaboratorContext = tester.element(collaborator);
final collaboratorAccent = CupertinoColors.systemIndigo.resolveFrom(
  collaboratorContext,
);
final collaboratorLabel = tester.widget<Text>(
  find.byKey(const ValueKey('chat-message-collaborator-label')),
);
expect(collaboratorLabel.style?.color, collaboratorAccent);

final collaboratorBox = tester.widget<DecoratedBox>(collaborator);
final decoration = collaboratorBox.decoration as BoxDecoration;
expect(
  decoration.color,
  Color.alphaBlend(
    collaboratorAccent.withValues(alpha: 0.10),
    Theme.of(collaboratorContext).colorScheme.surfaceContainerHigh,
  ),
);

final headerBefore = tester.getRect(
  find.byKey(const ValueKey('tp-root-glass-header')),
);
await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
await tester.pump();
expect(
  tester.getRect(find.byKey(const ValueKey('tp-root-glass-header'))),
  headerBefore,
);
expect(find.text('較早的訊息'), findsOneWidget);
```

Repeat the collaborator color assertion under Dark with alpha `0.18`. The test resolves `CupertinoColors.systemIndigo` through the current context instead of hard-coding one appearance's value.

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run:

```bash
flutter test test/ui/tp_root_scaffold_test.dart test/features/chat/chat_screen_test.dart test/features/trip_detail/trip_timeline_screen_test.dart test/features/map/global_map_screen_test.dart test/features/favorites/favorites_screen_test.dart
```

Expected: FAIL because Root pages still mix `TpRootScrollScaffold`, `TpAppBar`, `_MapRootAppBar`, and page-specific layout.

- [ ] **Step 3: Implement the Root layout boundary**

Create `lib/ui/tp_root_scaffold.dart` with app-owned geometry:

```dart
@immutable
class TpRootHeaderConfig {
  const TpRootHeaderConfig({
    required this.title,
    this.actions = const <Widget>[],
  }) : assert(actions.length <= 4);

  final Widget title;
  final List<Widget> actions;
}

abstract final class TpRootGeometry {
  static const double topGap = 8;
  static const double horizontalInset = 16;
  static const double headerHeight = 56;
  static const double actionGap = 8;

  static double headerTop(BuildContext context) =>
      MediaQuery.paddingOf(context).top + topGap;

  static double headerBottom(BuildContext context) =>
      headerTop(context) + headerHeight;

  static double initialContentTop(BuildContext context) =>
      headerBottom(context) + TpSpacing.s3;
}

class TpRootScaffold extends StatelessWidget {
  const TpRootScaffold({
    super.key,
    required this.header,
    required this.body,
    this.showSoftEdge = false,
  });

  final TpRootHeaderConfig header;
  final Widget body;
  final bool showSoftEdge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (showSoftEdge)
            Positioned(
              key: const ValueKey('tp-root-soft-edge'),
              top: TpRootGeometry.headerBottom(context),
              left: 0,
              right: 0,
              child: const TpSoftScrollEdge(),
            ),
          Positioned(
            top: TpRootGeometry.headerTop(context),
            left: TpRootGeometry.horizontalInset,
            right: TpRootGeometry.horizontalInset,
            child: TpRootGlassHeader(config: header),
          ),
        ],
      ),
    );
  }
}
```

`TpRootGlassHeader` must render one `TpGlassSurface`, a left-aligned `TpHeaderTitle`, and one `TpHeaderActionRow`. It must not wrap each action in another glass unless the action itself is the shared circular `TpToolbarGlassButton`; the outer capsule owns the refraction layer. `TpHeaderActionRow` distinguishes icon and text actions: icon actions occupy 44×44pt, while `TpToolbarTextButton` uses intrinsic/flexible width with a minimum 44pt height. This prevents `完成` from being clipped to `完` and keeps the same spacing logic in Root, detail, and sheet headers.

`TpRootScrollView` builds the one `CustomScrollView`, inserts `SliverToBoxAdapter(height: TpRootGeometry.initialContentTop(context))` before feature slivers, and appends `TpRootTabGeometry.clearance(context) + TpSpacing.s4`. Its refresh variant owns `RefreshIndicator.adaptive`; feature pages do not recreate these insets.

- [ ] **Step 4: Migrate all four Root destinations and delete the old path**

Apply these title/action rules:

| Screen | Header title | Trailing actions |
|---|---|---|
| Chat | current `TripTitleButton` | account; a second action only if the existing chat behavior requires it |
| Selected itinerary | current `TripTitleButton`; reorder mode uses `調整順序` | More or intrinsic-width `完成`, account |
| Global/selected map | current `TripTitleButton` | map action/More, account |
| Favorites normal | text `收藏` | search, sort menu, add, account |
| Favorites searching | autofocus `AppSearchField` | sort menu, close search, account |
| No-selected-trip list | text `我的行程` | add/More, account according to the existing workflow, max two |

Keep Chat's composer and map controls as body overlays. Chat messages and the Timeline use their one vertical scroll surface with `TpRootGeometry.initialContentTop(context)` as initial scroll padding instead of wrapping the whole body below the Header, so their content passes under the fixed capsule like Favorites. Position the map Day selector from `TpRootGeometry.headerBottom(context) + TpSpacing.s2`, not a duplicated top formula. Remove `_MapRootAppBar`, all root `Scaffold.appBar` values, root `TpAppBar` calls, `TpRootScrollScaffold`, and feature-owned 16pt/8pt action spacing.

In Chat, reuse the already populated `ChatMessage.senderName` and `submittedBy`; do not change API models. Pass the authenticated account display name and email into the bubble renderer. Resolve each label in this order: self display name → self email local part → `你`; collaborator message sender name → submitted email local part → `協作者`; assistant → `Tripline AI`. Keep self on Tripline accent and AI on a neutral surface. Resolve `CupertinoColors.systemIndigo` from the current context for collaborator label/tint, then alpha-blend it onto the current surface (subtle Light tint, slightly stronger Dark tint). Do not add a new ThemeExtension, dependency, or reusable content-category palette.

Favorites uses `CupertinoIcons.search`, `CupertinoIcons.line_horizontal_3_decrease`, `CupertinoIcons.add`, and the shared account avatar. The sort trigger is `TpMoreMenuButton<_FavoriteSort>` with `triggerChild` set to the three-line icon. Its menu contains newest, oldest, name, and region choices plus a separated Filter entry that opens the existing filter sheet. The selected `TpActionItem` has `selected: true`. Add uses `context.push('/favorites/explore')`; do not duplicate the Explore implementation. Search mode replaces the title with the existing `AppSearchField`, hides Add, keeps account trailing, and removes the former inline search field from the list.

Extend `test/ui/shared_ui_usage_test.dart` so `lib/features/**` cannot instantiate `AppBar`, `SliverAppBar`, or `GlassAppBar`, and so `tp_root_scroll_scaffold.dart` cannot return.

- [ ] **Step 5: Verify Root behavior, screenshots, and commit**

Run:

```bash
dart format lib/ui/tp_root_scaffold.dart lib/ui/trip_title_button.dart lib/features/chat/chat_screen.dart lib/features/trips/trips_list_screen.dart lib/features/trip_detail/trip_timeline_screen.dart lib/features/map/global_map_screen.dart lib/features/trip_detail/trip_map_screen.dart lib/features/favorites/favorites_screen.dart test/ui/tp_root_scaffold_test.dart test/features
flutter test test/ui/tp_root_scaffold_test.dart test/ui/shared_ui_usage_test.dart
flutter test test/features/chat test/features/trips/trips_list_screen_test.dart test/features/trip_detail/trip_timeline_screen_test.dart test/features/map/global_map_screen_test.dart test/features/favorites
flutter analyze
```

Capture all four Root destinations in Light, Dark, 200% text, Reduce Transparency, and a map PlatformView. Capture Chat with self, collaborator, and AI messages; verify author fallback and dynamic Indigo contrast in Light/Dark. Capture Favorites in normal, search-active, and sort-menu states. Reject a centered title, duplicate glass layer, opaque map gradient, header movement, fewer than 44pt targets, action drift, chat/Timeline content that cannot pass under the Header, content hidden on initial load, or Root Tab overlap.

Commit only these files:

```bash
git add lib/ui/tp_root_scaffold.dart lib/ui/trip_title_button.dart lib/ui/tp_glass_surface.dart lib/ui/tp_root_scroll_scaffold.dart lib/features/chat/chat_screen.dart lib/features/trips/trips_list_screen.dart lib/features/trip_detail/trip_timeline_screen.dart lib/features/map/global_map_screen.dart lib/features/trip_detail/trip_map_screen.dart lib/features/favorites/favorites_screen.dart lib/features/shell/app_shell.dart test/ui/tp_root_scaffold_test.dart test/ui/shared_ui_usage_test.dart test/features
git commit -m "refactor: unify root pages under glass header"
```

---

### Task 14: Replace `google_maps_flutter` with a package-neutral `google_navigation_flutter` engine

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `android/settings.gradle.kts`
- Modify: `android/app/build.gradle.kts`
- Modify: `ios/Podfile`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Verify/Modify: `ios/Runner/Info.plist`
- Modify: `lib/features/map/map_adapter.dart`
- Create: `lib/features/map/map_canvas_mobile.dart`
- Create: `lib/features/map/map_canvas_web.dart`
- Create: `lib/features/map/trip_map_overlay_synchronizer.dart`
- Create: `lib/features/map/trip_map_marker_icon_registry.dart`
- Create: `lib/features/map/trip_map_cluster_projector.dart`
- Modify: `lib/features/map/map_style.dart`
- Modify: `lib/features/trip_detail/trip_map_screen.dart`
- Modify: `test/helpers/fake_trip_map.dart`
- Create: `test/features/map/map_platform_config_test.dart`
- Modify: `test/features/map/map_adapter_test.dart`
- Create: `test/features/map/trip_map_cluster_projector_test.dart`
- Modify: `test/features/trip_detail/trip_map_screen_test.dart`
- Modify: `.github/workflows/mobile.yml`

**Interfaces:**
- Produces: package-neutral `TripMapController`, `TripMapCanvasConfig`, `TripMapCanvasBuilder`, `GoogleMapPoiSelection`, and overlay/cluster services
- Mobile renderer owns: `GoogleMapsMapView`, `GoogleMapViewController`, `Marker`, `Polyline`, `ImageDescriptor`, and plugin event conversion
- Web renderer owns: non-embedded fallback only; it never imports `google_navigation_flutter`
- Removes: `GoogleTripMapController`, `GoogleMap`, `BitmapDescriptor`, `ClusterManager`, and every `google_maps_flutter` import/dependency
- Preserves: numbered Tripline markers, user marker, route styling, Day/POI zoom 12, map padding, Reduce Motion, marker taps, and 12+ marker clustering

- [ ] **Step 1: Add failing dependency/platform guards**

Create `test/features/map/map_platform_config_test.dart`:

```dart
test('map SDK and platform floors are locked consistently', () {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final androidApp = File('android/app/build.gradle.kts').readAsStringSync();
  final androidSettings = File('android/settings.gradle.kts').readAsStringSync();
  final podfile = File('ios/Podfile').readAsStringSync();
  final xcode = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();

  expect(pubspec, contains('google_navigation_flutter: ^0.10.0'));
  expect(pubspec, isNot(contains('google_maps_flutter:')));
  expect(androidApp, contains('minSdk = 24'));
  expect(androidApp, contains('desugar_jdk_libs_nio:2.1.5'));
  expect(
    androidSettings,
    contains('com.android.application") version "8.13.2"'),
  );
  expect(androidSettings, contains('version "2.3.0"'));
  expect(podfile, contains("platform :ios, '16.0'"));
  expect(xcode, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0')));
  expect(xcode, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0'));
});

test('feature code cannot import a Google map plugin', () {
  for (final entity in Directory('lib/features').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    if (entity.path.endsWith('map_canvas_mobile.dart')) continue;
    expect(source, isNot(contains('google_navigation_flutter')),
        reason: entity.path);
    expect(source, isNot(contains('google_maps_flutter')),
        reason: entity.path);
  }
});
```

Run `flutter test test/features/map/map_platform_config_test.dart`; expected: FAIL on the old dependency and platform values.

- [ ] **Step 2: Do the dependency spike and platform migration first**

Change `pubspec.yaml` to remove `google_maps_flutter` and add `google_navigation_flutter: ^0.10.0`. Run `flutter pub get` and commit the resolved version in `pubspec.lock`.

In `android/settings.gradle.kts`, update the Android Gradle Plugin to `8.13.2` and the Kotlin Android plugin from `2.2.20` to `2.3.0`. These are the minimums enforced by the resolved 0.10.0 Android AAR metadata, which is stricter than the package README. In `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    minSdk = 24
}

compileOptions {
    isCoreLibraryDesugaringEnabled = true
    // Preserve the existing sourceCompatibility/targetCompatibility values.
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")
}
```

Merge these blocks into the existing file; do not replace signing, flavors, namespace, or release optimization.

Set iOS 16.0 in `ios/Podfile` and every `IPHONEOS_DEPLOYMENT_TARGET` build setting. Keep the existing truthful location purpose strings. Do not add `UIBackgroundModes: location` or initialize a navigation session for this map-only design. If the plugin's actual iOS build/runtime rejects that least-privilege setup, stop this task, capture the exact error, and return to the dependency decision before adding a background entitlement.

Keep `.github/workflows/mobile.yml` on the same `flutter pub get` plus Android debug/release and iOS archive paths. Add a focused map-platform config test to its existing test step if the workflow uses targeted tests; do not create a second CI workflow for this migration.

Confirm the existing API-key injection still reads secrets rather than committing a key. Record the external Cloud Console checklist in the PR: billing enabled, Navigation SDK for Android/iOS enabled, key restricted by Android package/SHA and iOS bundle ID, API restrictions include Navigation SDK plus Maps SDK for Android/iOS, and Google attributions/license text is reachable in the existing account/legal UI.

Run the compile spike before adapter work:

```bash
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

Expected: both mobile platforms compile with the package installed. Do not continue to adapter work with only one platform building.

- [ ] **Step 3: Add failing package-neutral controller and overlay tests**

Extend `test/features/map/map_adapter_test.dart` to assert:

```dart
test('plugin POI is converted to the app-owned selection DTO', () {
  final selection = GoogleMapPoiSelection(
    placeId: 'place-1',
    name: '清水寺',
    point: const TripMapPoint(34.9948, 135.7850),
  );
  expect(selection.placeId, 'place-1');
  expect(selection.point.latitude, closeTo(34.9948, 0.0001));
});

test('controller queues camera work until the renderer attaches', () async {
  final platform = FakeTripMapPlatformController();
  final controller = TripMapController();
  final move = controller.move(const TripMapPoint(35, 135), 12);
  controller.attach(platform);
  await move;
  expect(platform.moves.single.zoom, 12);
});

test('overlay reconciliation updates only changed semantic IDs', () async {
  final platform = FakeTripMapOverlayPlatform();
  final sync = TripMapOverlaySynchronizer(platform);
  await sync.sync(markers: [_marker('a'), _marker('b')], routes: [_route('r')]);
  await sync.sync(markers: [_marker('a'), _marker('c')], routes: [_route('r')]);
  expect(platform.removedMarkerSemanticIds, ['b']);
  expect(platform.addedMarkerSemanticIds, containsAll(['a', 'b', 'c']));
  expect(platform.clearCount, 0);
});
```

Use app-owned fake interfaces; tests must not construct `GoogleMapViewController` or a PlatformView.

- [ ] **Step 4: Implement the conditional canvas and mobile renderer**

Keep app-owned values in `map_adapter.dart` and use a conditional export/factory for mobile versus web. Rename `GoogleTripMapController` to `TripMapController`; its private platform delegate exposes only the camera/padding operations Tripline needs.

In `map_canvas_mobile.dart`, the widget shape is:

```dart
GoogleMapsMapView(
  key: config.mapKey,
  onViewCreated: _handleViewCreated,
  initialCameraPosition: CameraPosition(
    target: _toGoogle(initialTarget),
    zoom: config.initialZoom,
  ),
  initialMapType: MapType.normal,
  initialMapColorScheme: isDark
      ? MapColorScheme.dark
      : MapColorScheme.light,
  initialCompassEnabled: true,
  initialMapToolbarEnabled: false,
  initialZoomControlsEnabled: false,
  initialPadding: config.initialPadding,
  onMapClicked: (point) => config.onTap?.call(_fromGoogle(point)),
  onPoiClicked: (poi) => config.onGooglePoiSelected?.call(
    GoogleMapPoiSelection(
      placeId: poi.placeID,
      name: poi.name,
      point: _fromGoogle(poi.latLng),
    ),
  ),
  onMarkerClicked: _handlePlatformMarkerClicked,
  onCameraIdle: _handleCameraIdle,
);
```

`_handleViewCreated` attaches a private controller adapter, sets padding/appearance, registers missing Tripline marker PNG bytes with `registerBitmapImage`, then asks `TripMapOverlaySynchronizer` to add `MarkerOptions` and `PolylineOptions`. Preserve `consumeTapEvents: true` for Tripline markers so the SDK does not auto-move/zoom or show an info window before Tripline handles the click.

The synchronizer must keep the plugin-returned `Marker.markerId`/`Polyline.polylineId` handles mapped to stable app semantic IDs. Config changes update/remove/add only affected handles. Dispose listeners and clear owned handles without calling a global image clear that could affect another map instance.

Map appearance follows the explicit App theme, not local clock time. Keep native Google POI labels visible; do not apply a JSON/cloud style that hides business, transit, park, or landmark POIs.

`map_canvas_web.dart` renders a bounded fallback with current place/trip context and a labeled `在 Google 地圖開啟` action. It does not import either Google map Flutter package.

- [ ] **Step 5: Replace plugin clustering with pure-Dart Tripline clustering**

Add `test/features/map/trip_map_cluster_projector_test.dart`:

```dart
test('nearby clusterable markers share a stable cluster at zoom 12', () {
  final result = const TripMapClusterProjector().project(
    markers: [_markerAt('a', 25.0330, 121.5650), _markerAt('b', 25.0332, 121.5652)],
    zoom: 12,
  );
  expect(result.single.memberIds, ['a', 'b']);
  expect(result.single.glyph, '2');
});

test('non-clusterable user marker is never absorbed', () {
  final result = const TripMapClusterProjector().project(
    markers: [_markerAt('poi', 25, 121), _userMarkerAt(25, 121)],
    zoom: 12,
  );
  expect(result.where((item) => item.memberIds.contains('user')).single.isCluster,
      isFalse);
});

test('zooming in separates markers without changing semantic IDs', () {
  final projector = const TripMapClusterProjector();
  final clustered = projector.project(markers: _denseMarkers, zoom: 12);
  final separated = projector.project(markers: _denseMarkers, zoom: 17);
  expect(clustered.length, lessThan(separated.length));
  expect(separated.expand((item) => item.memberIds).toSet(),
      _denseMarkers.map((item) => item.id).toSet());
});
```

Use Web Mercator normalized coordinates and a documented logical-pixel bucket; do not depend on plugin LatLng types. Recompute only on camera idle and only when the integer zoom bucket or marker set changes. A cluster click calls `TripMapController.fitPoints` for its member points. A normal Tripline marker click invokes the original callback.

- [ ] **Step 6: Verify map parity on both platforms and commit**

Run:

```bash
dart format lib/features/map lib/features/trip_detail/trip_map_screen.dart test/features/map test/features/trip_detail/trip_map_screen_test.dart test/helpers/fake_trip_map.dart
flutter test test/features/map/map_platform_config_test.dart test/features/map/map_adapter_test.dart test/features/map/trip_map_cluster_projector_test.dart test/features/trip_detail/trip_map_screen_test.dart
flutter test test/features/map test/features/trip_detail
flutter analyze
flutter build apk --debug
flutter build ios --simulator --no-codesign
rg -n "google_maps_flutter|GoogleTripMapController|ClusterManager" pubspec.yaml lib android ios && exit 1 || true
```

Manually verify iOS and Android: native POI labels visible, Day and POI zoom exactly 12, route width/style intact, Tripline numbered markers intact, 12+ markers cluster, cluster tap fits members, map light/dark follows App appearance, and Root/Day/POI/Tab glass overlays do not steal map gestures.

Commit:

```bash
git add pubspec.yaml pubspec.lock android/settings.gradle.kts android/app/build.gradle.kts ios/Podfile ios/Runner.xcodeproj/project.pbxproj ios/Runner/Info.plist lib/features/map lib/features/trip_detail/trip_map_screen.dart test/features/map test/features/trip_detail/trip_map_screen_test.dart test/helpers/fake_trip_map.dart .github/workflows/mobile.yml
git commit -m "refactor: replace trip map engine"
```

---

### Task 15: Add native Google POI accessory state and HIG-compliant external opening

**Files:**
- Create: `lib/features/map/google_maps_external_launcher.dart`
- Create: `lib/features/trip_detail/google_poi_accessory_card.dart`
- Modify: `lib/features/map/map_adapter.dart`
- Modify: `lib/features/map/map_canvas_mobile.dart`
- Modify: `lib/features/map/map_canvas_web.dart`
- Modify: `lib/features/trip_detail/trip_map_screen.dart`
- Create: `test/features/map/google_maps_external_launcher_test.dart`
- Create: `test/features/trip_detail/google_poi_accessory_card_test.dart`
- Modify: `test/features/trip_detail/trip_map_screen_test.dart`
- Modify: `test/features/map/global_map_screen_test.dart`

**Interfaces:**
- Produces: immutable `GoogleMapPoiSelection`, `GoogleMapsExternalLauncher`, `GooglePoiAccessoryCard`, and injectable launcher provider/callback
- Consumes: `TripMapCanvasConfig.onGooglePoiSelected`, `onTap`, `onMarkerClicked`, and the existing `TpBottomAccessory` slot
- Preserves: Tripline active entry ID, PageController page, Day selection, zoom 12, and original entry-card behavior
- Does not produce: a Place Details API call, backend write, favorite, trip entry, automatic context switch, or confirmation alert

- [ ] **Step 1: Add failing URL and launcher tests**

Create `test/features/map/google_maps_external_launcher_test.dart`:

```dart
test('builds a precise encoded Google Maps Universal URL', () {
  final uri = GoogleMapsExternalLauncher.buildSearchUri(
    const GoogleMapPoiSelection(
      placeId: 'ChIJ-test',
      name: '清水寺 Kyoto',
      point: TripMapPoint(34.9948, 135.7850),
    ),
  );
  expect(uri.scheme, 'https');
  expect(uri.host, 'www.google.com');
  expect(uri.path, '/maps/search/');
  expect(uri.queryParameters['api'], '1');
  expect(uri.queryParameters['query'], '清水寺 Kyoto');
  expect(uri.queryParameters['query_place_id'], 'ChIJ-test');
});

test('falls back to coordinates when a POI has no usable name', () {
  final uri = GoogleMapsExternalLauncher.buildSearchUri(
    const GoogleMapPoiSelection(
      placeId: '',
      name: '',
      point: TripMapPoint(34.9948, 135.7850),
    ),
  );
  expect(uri.queryParameters['query'], '34.9948,135.785');
  expect(uri.queryParameters.containsKey('query_place_id'), isFalse);
});

test('open returns false instead of swallowing launcher failure', () async {
  final launcher = GoogleMapsExternalLauncher(
    launch: (_, {required mode}) async => false,
  );
  expect(await launcher.open(_selection), isFalse);
});
```

The production implementation uses `Uri.https` and `LaunchMode.externalApplication`; it does not probe a custom URL scheme or show a preflight alert.

- [ ] **Step 2: Add failing accessory swap/restore tests**

Extend `test/features/trip_detail/trip_map_screen_test.dart` using the existing fake map builder:

```dart
testWidgets('Google POI temporarily replaces the Tripline accessory', (
  tester,
) async {
  late TripMapCanvasConfig config;
  await _pumpMap(tester, mapBuilder: (value) {
    config = value;
    return const ColoredBox(color: Colors.blue);
  });

  expect(find.byKey(const ValueKey('trip-map-poi-page-view')), findsOneWidget);
  config.onGooglePoiSelected!(_selection);
  await tester.pump();

  expect(find.byKey(const ValueKey('google-poi-accessory')), findsOneWidget);
  expect(find.text('在 Google 地圖開啟'), findsOneWidget);
  expect(find.byKey(const ValueKey('trip-map-poi-page-view')), findsNothing);

  await tester.tap(find.byKey(const ValueKey('google-poi-close')));
  await tester.pump();
  expect(find.byKey(const ValueKey('trip-map-poi-page-view')), findsOneWidget);
});

testWidgets('map tap and Tripline marker restore the prior page at zoom 12', (
  tester,
) async {
  final harness = await _pumpControllableMap(tester, initialPage: 2);
  harness.selectGooglePoi(_selection);
  await tester.pump();
  harness.tapMap(const TripMapPoint(35, 135));
  await tester.pump();
  expect(find.byKey(const ValueKey('entry-card-13')), findsOneWidget);

  harness.selectGooglePoi(_selection);
  harness.tapTriplineMarker('map-pin-13');
  await tester.pump();
  expect(find.byKey(const ValueKey('entry-card-13')), findsOneWidget);
  expect(harness.lastMove.zoom, 12);
});

testWidgets('Google POI selection does not move the camera', (tester) async {
  final harness = await _pumpControllableMap(tester);
  final before = harness.moves.length;
  harness.selectGooglePoi(_selection);
  await tester.pump();
  expect(harness.moves.length, before);
});
```

Add `google_poi_accessory_card_test.dart` for 200% text, 44pt close/open targets, semantic label `在 Google 地圖開啟清水寺，將離開 Tripline`, and Light/Dark/Reduce Transparency rendering.

- [ ] **Step 3: Implement selection state without corrupting Tripline state**

Add to `_TripMapViewState`:

```dart
GoogleMapPoiSelection? _selectedGooglePoi;

void _selectGooglePoi(GoogleMapPoiSelection selection) {
  setState(() => _selectedGooglePoi = selection);
}

void _clearGooglePoi() {
  if (_selectedGooglePoi == null) return;
  setState(() => _selectedGooglePoi = null);
}
```

Pass `_selectGooglePoi` to `TripMapCanvasConfig.onGooglePoiSelected` and `_clearGooglePoi` to its blank-map callback. At the start of `_selectStop`, clear `_selectedGooglePoi` in the same `setState` that updates `_activeEntryId`. Never reset `_activeEntryId`, `_selectedTabIndex`, or `_pageController` when a native POI is selected.

Refactor `_buildPoiAccessory` so `TpBottomAccessory` remains mounted once:

```dart
child: AnimatedSwitcher(
  duration: TpMotion.resolve(context, TpMotion.fast),
  child: _selectedGooglePoi == null
      ? _buildTriplinePoiPager(visibleStops)
      : GooglePoiAccessoryCard(
          key: const ValueKey('google-poi-accessory'),
          selection: _selectedGooglePoi!,
          onClose: _clearGooglePoi,
          onOpen: () => _openGooglePoi(_selectedGooglePoi!),
        ),
),
```

Reduce Motion resolves the switch to zero/near-zero duration. Do not stack a second `TpBottomAccessory`, sheet, dialog, or Snackbar over the POI dock.

- [ ] **Step 4: Implement the explicit external action and failure state**

`GoogleMapsExternalLauncher.buildSearchUri` uses the POI name as `query`, falls back to a stable latitude/longitude string, and includes `query_place_id` only when non-empty. `open` delegates to `launchUrl(uri, mode: LaunchMode.externalApplication)` and returns the result.

`_openGooglePoi` awaits the injected launcher. On `false` or exception, keep the card selected and call `showAppError(context, '無法開啟 Google 地圖，請稍後再試')`. On success, do not display an extra success notice.

`GooglePoiAccessoryCard` uses the same glass/accessory recipe as the Tripline POI dock, one close button, one labeled secondary action, the map-pin/external-link symbol, Dynamic Type, and a small Tripline accent. It does not imitate Google's brand UI or use an unlabeled icon-only external action.

On web, use the same URI builder and browser launch behavior. The web fallback and selected native mobile POI must not fork URL construction.

- [ ] **Step 5: Verify gestures, accessibility, fallback, and commit**

Run:

```bash
dart format lib/features/map/google_maps_external_launcher.dart lib/features/map/map_adapter.dart lib/features/map/map_canvas_mobile.dart lib/features/map/map_canvas_web.dart lib/features/trip_detail/google_poi_accessory_card.dart lib/features/trip_detail/trip_map_screen.dart test/features/map/google_maps_external_launcher_test.dart test/features/trip_detail/google_poi_accessory_card_test.dart test/features/trip_detail/trip_map_screen_test.dart
flutter test test/features/map/google_maps_external_launcher_test.dart test/features/trip_detail/google_poi_accessory_card_test.dart test/features/trip_detail/trip_map_screen_test.dart test/features/map/global_map_screen_test.dart
flutter test test/features/map test/features/trip_detail
flutter analyze
```

On iOS and Android, tap a native restaurant/station/landmark POI, verify the card replaces rather than covers the Tripline pager, close it, tap blank map, tap a Tripline marker, and open Google Maps both with and without the Google Maps App installed. Confirm no automatic zoom and no confirmation alert.

Commit:

```bash
git add lib/features/map/google_maps_external_launcher.dart lib/features/map/map_adapter.dart lib/features/map/map_canvas_mobile.dart lib/features/map/map_canvas_web.dart lib/features/trip_detail/google_poi_accessory_card.dart lib/features/trip_detail/trip_map_screen.dart test/features/map/google_maps_external_launcher_test.dart test/features/trip_detail/google_poi_accessory_card_test.dart test/features/trip_detail/trip_map_screen_test.dart test/features/map/global_map_screen_test.dart
git commit -m "feat: open native map POIs in Google Maps"
```

---

### Task 16: Simplify the full refactor, prove plan completion, and gate remote push on review

**Files:**
- Modify/Delete: every compatibility-only file identified by the completed Tasks 1–15
- Modify: `test/ui/shared_ui_usage_test.dart`
- Modify: `docs/superpowers/specs/2026-07-18-hig-action-semantics-favorite-undo-design.md` only if implementation differs from the approved design for a documented reason
- Modify: `docs/superpowers/plans/2026-07-18-hig-navigation-sheet-semantics.md` checkboxes/status as each task is completed
- Generate locally, do not commit unless the repository convention requires it: screenshot/review artifacts

**Interfaces:**
- Removes: dead Root/header/sheet/map compatibility layers, duplicate glass recipes, unused action models, and stale imports
- Enforces: one Root header path, one semantic sheet engine, one compact-navigation optics source, one mobile Google map SDK, and one Universal URL builder
- Gates: remote push on formatter/tests/analyze/builds/screenshots, simplification, plan completion audit, gstack `/review`, Codex adversarial/structured review, and resolved findings

- [ ] **Step 1: Run a scoped simplification pass before review**

Review the full merge-base diff, not only the last commit:

```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
BASE=${BASE:-master}
git fetch origin "$BASE" --quiet
DIFF_BASE=$(git merge-base "origin/$BASE" HEAD)
git diff "$DIFF_BASE" --stat
git diff "$DIFF_BASE" --name-only
dart fix --dry-run
```

Apply only fixes relevant to changed files. Do not run a blind repository-wide `dart fix --apply` in a dirty worktree.

Delete or merge all of these when unused:

- `TpRootScrollScaffold`, `_MapRootAppBar`, feature-owned Root app bars, duplicate header geometry, and per-page action padding.
- `showAppLargeSheet`, `showAppLargeScreenSheet`, direct platform sheet calls, duplicate drag handles, and duplicate selection/form presentation code.
- `TpMenuAction`, `AppSheetAction`, or any action model superseded by `TpActionItem`.
- `GoogleTripMapController`, `google_maps_flutter` converters/imports, `ClusterManager`, duplicate URL builders, and clear-and-redraw overlay code.
- Duplicate Light/Dark glass numbers outside the designated token/settings source.
- Temporary migration aliases, ignored lints, debug prints, demo labels, unreachable branches, and tests that only assert deleted compatibility behavior.

Keep abstractions that own a real boundary: semantic sheet variants, Root scaffold/header, plugin-neutral map interfaces, overlay synchronizer, pure-Dart cluster projector, and external launcher. Simplification must reduce ownership duplication, not inline everything back into feature screens.

- [ ] **Step 2: Strengthen static architecture guards**

Extend `test/ui/shared_ui_usage_test.dart` to fail when:

```dart
const forbiddenFeatureTokens = <String>[
  'showModalBottomSheet(',
  'showCupertinoModalPopup(',
  'showGeneralDialog(',
  'GlassAppBar(',
  'SliverAppBar(',
  'google_maps_flutter',
  'GoogleMapsNavigator.initializeNavigationSession',
];
```

Add explicit assertions that:

- `lib/features/**` does not instantiate raw `AppBar(` except an allowlisted platform/example boundary with a written reason.
- only `map_canvas_mobile.dart` imports `google_navigation_flutter`.
- `pubspec.yaml` contains one Google map SDK dependency.
- only `tp_glass_surface.dart` defines compact navigation `LiquidGlassSettings` values.
- only `adaptive.dart` touches platform sheet presentation APIs.
- the removed legacy files/symbols do not exist.

- [ ] **Step 3: Run the full verification matrix**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test test/ui test/app
flutter test test/features
flutter test
flutter analyze
flutter build apk --debug
flutter build ios --simulator --no-codesign
git diff --check
```

If any command fails, fix the root cause and restart this matrix from the first failed command, then rerun the final `flutter test` and `flutter analyze` after all fixes.

Capture a named screenshot matrix for Chat, itinerary, map with Tripline POI, map with Google native POI, favorites, trip selection sheet, account sheet, form sheet, and destructive confirmation:

- Light and Dark.
- Default text and 200% text.
- Reduce Motion on/off where motion is visible.
- Reduce Transparency on/off for glass fallback.
- iOS simulator and one Android emulator/device for map PlatformView behavior.

Compare geometry against the final mockup: Root Header top/width/height, Root Tab bottom clearance, Day selector, POI accessory, sheet detents, 44pt actions, and single-layer glass. Save only final approved images; remove superseded process screenshots before commit.

- [ ] **Step 4: Run plan-completion, code, design, and adversarial review before push**

First run an independent code review over the complete merge-base diff. Review correctness, state/data loss, concurrency and PlatformView lifecycle, permissions/privacy, accessibility, performance, tests, and maintainability. Record findings with file/line evidence and severity; no P0/P1 may remain open. A "looks good" summary without reading the full diff and verification evidence does not satisfy this gate.

Invoke the gstack `/review` workflow against the detected remote base branch. It must:

1. Audit every actionable item in this plan as DONE/CHANGED/PARTIAL/NOT DONE/UNVERIFIABLE.
2. Report scope drift against this approved whole-plan refactor; this plan's expanded architecture is in scope, unrelated cleanup is not.
3. Run the critical checklist plus testing, maintainability, performance, design, and any scope-triggered specialists.
4. Run the always-on adversarial pass.
5. Run Codex adversarial review when Codex is authenticated.
6. Because this refactor will exceed 200 changed lines, run Codex structured review and require `GATE: PASS` with no unresolved P1.
7. Auto-fix mechanical findings, ask for judgment on non-mechanical findings, persist the review result, and never push by itself.

Treat simplification warnings, missing plan items, stale docs, test gaps, PlatformView lifecycle leaks, overlay races, permission overreach, URL encoding, and accessibility regressions as real findings. Do not mark an item complete from a touched filename alone.

If `/review` changes code, rerun Step 3 in full and invoke `/review` again. Required final state:

- Plan completion has no PARTIAL/NOT DONE item unless the user explicitly records an intentional scope change.
- The independent code review has no unresolved P0/P1 and every accepted lower-severity finding is either fixed or explicitly documented for user judgment.
- gstack review status is clean with no unresolved critical/informational findings accepted for this release.
- Codex structured gate is PASS.
- Screenshot matrix is approved.

- [ ] **Step 5: Create the final local commit and only then allow remote push**

Inspect staging explicitly:

```bash
git status --short
git diff --cached --stat
git diff --cached --check
```

Stage only intentional refactor, tests, final spec/plan, and final approved artifacts. Do not use `git add -A` in the existing dirty worktree.

Create a final cleanup/review commit if needed:

```bash
git commit -m "refactor: finalize Tripline HIG map experience"
```

Before any `git push`, show the user:

- branch and base,
- final commits,
- full verification results,
- gstack review status and quality score,
- independent code-review status and remaining accepted findings,
- Codex gate,
- remaining external Cloud Console checks, if any,
- exact files staged/committed.

Only after all gates are green may the implementation session run the explicit push command. A request to “push” does not authorize skipping any gate recorded here.

### Task 17: Convert the manual HIG and native-map verification matrix into automated release gates

**Files:**
- Create: `test/flows/hig_regression_matrix_test.dart`
- Create: `test/features/map/trip_map_marker_icon_registry_test.dart`
- Create: `patrol_test/native_map_smoke_test.dart`
- Create: `android/app/src/androidTest/java/com/raychiu/tripline/MainActivityTest.java`
- Create: `ios/RunnerUITests/RunnerUITests.m`
- Create: `.github/workflows/mobile-e2e.yml`
- Modify: `integration_test/app_smoke_test.dart`
- Modify: `test/features/chat/chat_screen_test.dart`
- Modify: `test/features/map/map_adapter_test.dart`
- Modify: `test/features/map/map_canvas_web_test.dart`
- Modify: `test/api/cache/conflict_resolve_test.dart`
- Modify: `test/features/trip_detail/day_weather_test.dart`
- Modify: `test/features/trips/create/create_trip_controller_test.dart`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `.gitignore`
- Modify: `android/app/build.gradle.kts`
- Modify: `ios/Podfile`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `.github/workflows/mobile.yml`

**Interfaces:**
- Produces: a fast deterministic PR gate, a device-level Patrol smoke suite, and named screenshot artifacts for every approved appearance/accessibility state
- Consumes: the existing `TriplineApp`, `TpRootScaffold`, semantic sheet wrappers, `TripMapCanvasConfig`, `TripMapController`, package-neutral map callbacks, and provider overrides
- Preserves: no production test mode, no authentication bypass in shipping code, no backend writes, zoom 12, native Google POIs, Tripline marker precedence, and existing Light/Dark theme ownership
- Pins: `patrol: 4.6.1` with `patrol_cli 4.4.0`, matching the official `google_navigation_flutter` example and Patrol compatibility table for Flutter 3.44.6

- [x] **Step 1: Turn review-discovered regressions into failing tests first**

Add a chat widget test that makes `fetchRequests` throw a 401 `ApiError`, pumps `ChatScreen`, and asserts the auth-expired banner's top is at or below `TpRootGeometry.initialContentTop(context)`. Run:

```bash
flutter test test/features/chat/chat_screen_test.dart --plain-name '登入過期 banner 不會被 Root Header 遮住'
```

Expected: FAIL because the banner currently starts at the top of the Stack. Then add the smallest shared top inset around the banner region and rerun until PASS.

Add a map-controller queue test that attaches a platform whose first camera operation throws and whose second succeeds:

```dart
final first = controller.move(const TripMapPoint(25, 121), 12);
final second = controller.move(const TripMapPoint(26, 122), 12);
await expectLater(first, throwsStateError);
await expectLater(second, completes);
```

Run `flutter test test/features/map/map_adapter_test.dart`; verify the new case fails for the intended reason before changing production code, then implement only the queue-recovery behavior required by the test.

- [x] **Step 2: Automate the deterministic HIG matrix without a native PlatformView**

Create `test/flows/hig_regression_matrix_test.dart`. Pump the approved root pages and reusable sheet/form controls with fake repositories and `fakeTripMapBuilder`, then iterate these exact `MediaQueryData`/theme states:

```dart
const matrix = <({Brightness brightness, double textScale, bool reduceMotion, bool reduceTransparency})>[
  (brightness: Brightness.light, textScale: 1, reduceMotion: false, reduceTransparency: false),
  (brightness: Brightness.dark, textScale: 1, reduceMotion: false, reduceTransparency: false),
  (brightness: Brightness.light, textScale: 2, reduceMotion: false, reduceTransparency: false),
  (brightness: Brightness.dark, textScale: 2, reduceMotion: false, reduceTransparency: false),
  (brightness: Brightness.light, textScale: 1, reduceMotion: true, reduceTransparency: true),
  (brightness: Brightness.dark, textScale: 1, reduceMotion: true, reduceTransparency: true),
];
```

For every state assert:

- Root Header remains fixed while Chat and Timeline content scroll behind it.
- Root actions, Back, Close, Cancel, Done, reorder, search, sort, and add expose at least 44×44 logical-point hit regions.
- trip picker, account, notes, print, audit, share, collaboration, health, edit, and destructive confirmation can open and dismiss through their documented semantic action.
- no `FlutterError`, overflow indicator, hidden initial content, or Root Tab overlap occurs.
- map Day and POI focus requests remain exactly zoom 12.
- native Google POI selection replaces only the accessory, blank-map tap restores the Tripline accessory, and Tripline marker selection remains authoritative.

Run `flutter test test/flows/hig_regression_matrix_test.dart` after each new assertion. A test that passes before its assertion is added is not evidence; each regression assertion must be observed failing against a deliberately incomplete harness or the current defect before going green.

- [x] **Step 3: Close the pure-Dart and web gaps reported by the testing review**

Add focused tests, one failing behavior at a time, for:

- `TripMapMarkerIconRegistry`: same effective style reuses one bitmap; different glyph/style/DPR yields a different bitmap.
- web map canvas: blank tap, Google POI fallback, external URL callback, and absent web API fallback remain non-crashing.
- conflict resolver: ours, multi-field, repository error, and retry paths.
- `DayWeatherCard`: provider error and empty-hourly fallback.
- create-trip controller: edits set `hasChanges`; reset/submission clears it.

Run each file directly during RED/GREEN, then run:

```bash
flutter test test/features/map test/api/cache/conflict_resolve_test.dart test/features/trip_detail/day_weather_test.dart test/features/trips/create/create_trip_controller_test.dart
```

Expected: all PASS with no skipped branch that is available on the current host.

- [x] **Step 4: Expand the real app integration flow without production services**

Extend `integration_test/app_smoke_test.dart` with provider-owned fixtures only. The suite must:

1. launch logged out and stop at Login without a production request;
2. log in through the visible fields and reach the trip list;
3. open a trip, switch itinerary/map Day, open/close Notes, and return;
4. visit Chat, Itinerary, Map, and Favorites through the shared Root Tab;
5. open trip picker and account sheets, navigate one nested detail with Back, then close the sheet with Close;
6. verify favorite search/sort and the current Undo capability state without mutating production data.

Run on a booted simulator/emulator:

```bash
flutter test integration_test/app_smoke_test.dart -d "$DEVICE_ID"
```

Expected: PASS and no request to the production API host.

- [x] **Step 5: Add Patrol for native Google Map and system-boundary smoke tests**

Add exact Patrol package/native runner configuration, keep tests under `patrol_test/`, and ignore generated `patrol_test/test_bundle.dart`. `native_map_smoke_test.dart` must pump a standalone `MaterialApp` containing `buildTripMapCanvas` so it needs neither login nor backend state. It must verify:

- `onMapReady` fires on the real `GoogleMapsMapView`;
- Light and Dark app theme changes update the native map color scheme without switching to clock-based night mode;
- Tripline numbered markers and route overlays render without a platform exception;
- Day and Tripline POI actions keep camera zoom 12;
- location permission can be accepted through Patrol when displayed;
- native map gestures are still accepted around Root/Day/POI/Tab overlays;
- tapping one stable, fixed-coordinate native POI can produce `GoogleMapPoiSelection`, and the external-open action changes apps/web without an in-app confirmation. The POI callback assertion is enabled with `E2E_EXPECT_GOOGLE_POI=true` on Test Lab; local runs without a valid Maps key still exercise the native view, overlays, zoom, and theme lifecycle.

The native-POI case is a smoke signal, not the sole contract assertion: POI name text is not pinned because Google map data and localization can change. The deterministic callback/accessory/URL assertions remain in Flutter tests.

Run:

```bash
dart pub global activate patrol_cli 4.4.0
patrol doctor
patrol test -t patrol_test/native_map_smoke_test.dart --device "$DEVICE_ID"
```

Expected: PASS on one iOS simulator and one Android device/emulator with Google Play services.

- [x] **Step 6: Replace ad-hoc screenshots with named CI artifacts**

The deterministic app-owned suite captures these names: `chat`, `itinerary`, `map-tripline-poi`, `map-native-google-poi`, `favorites`, `trip-picker`, `account`, `form`, and `destructive-confirm`. It suffixes each with host platform, Light/Dark, text scale, Reduce Motion, and Reduce Transparency state. Patrol/Test Lab retains the native device video, screenshots, logs, and matrix result without pretending unstable PlatformView frames are deterministic goldens. Store run output only under `build/test-artifacts/` or the private Test Lab result directory; do not commit process screenshots or unstable PlatformView goldens.

CI uploads the directory even on failure. Geometry remains assertion-based; screenshots are review evidence, not pixel-perfect gates for the native map tiles.

- [x] **Step 7: Add fast PR and Firebase Test Lab device E2E workflows**

Keep `.github/workflows/mobile.yml` as the fast PR gate. Add `.github/workflows/mobile-e2e.yml` to build Patrol's native test bundles in GitHub Actions and execute them on the external Firebase Test Lab device farm:

- `workflow_dispatch` for `ios`, `android`, or `all`;
- a weekday Android native-smoke schedule at 02:30 Asia/Taipei;
- Android build on `ubuntu-24.04`, followed by `gcloud firebase test android run --type instrumentation --use-orchestrator` against an ARM virtual or physical device with Google Play services;
- iOS build on `macos-26`, followed by `gcloud firebase test ios run` against a Firebase physical iPhone using the packaged `.xctestrun` and `Release-iphoneos` products;
- pinned `patrol_cli 4.4.0`;
- Google Cloud authentication through GitHub OIDC Workload Identity Federation, not a long-lived service-account JSON key;
- repository variables `FIREBASE_TEST_LAB_PROJECT_ID`, `GCP_WORKLOAD_IDENTITY_PROVIDER`, and `GCP_TEST_LAB_SERVICE_ACCOUNT`; map keys remain GitHub secrets;
- `patrol build android --target patrol_test/native_map_smoke_test.dart --dart-define E2E_EXPECT_GOOGLE_POI=true`, then upload `app-debug.apk` and `app-debug-androidTest.apk` to Test Lab;
- `patrol build ios --target patrol_test/native_map_smoke_test.dart --dart-define E2E_EXPECT_GOOGLE_POI=true --release`, zip `Release-iphoneos` plus the generated `.xctestrun`, then upload the archive to Test Lab;
- one stable low-cost device per scheduled run; broader physical-device matrices are manual release gates only;
- Test Lab video, screenshot, JUnit/native report, matrix URL, and failure-log artifact uploads;
- concurrency cancellation for stale E2E runs;
- a release-gate output consumed before TestFlight/Play internal upload.

The job must preserve Test Lab's non-zero exit code: `0` is PASS, `10` is a test failure, and infrastructure/unsupported-matrix exit codes remain BLOCKED/FAIL rather than being swallowed. Spark quota is sufficient for a one-device smoke matrix (up to 10 virtual and 5 physical runs per day); Blaze overage must be protected by the one-device default and a Google Cloud budget alert.

- [x] **Step 8: Gate release on the real favorite-restore backend contract**

The release workflow must perform an authenticated staging contract smoke before mobile upload: create a disposable favorite, delete it, call `POST /poi-favorites/:id/restore`, verify owner scoping and successful restore, delete the fixture, and fail closed when the endpoint or migration is absent. Do not point this smoke at production and do not enable the Flutter Undo affordance solely because mocks pass.

The backend implementation remains owned by `docs/backend-tasks/2026-07-18-poi-favorites-undo-restore-api.md`. If staging credentials are absent, TestFlight and Play upload remain blocked with an explicit contract-gate message.

Implementation evidence (2026-07-19): `.github/workflows/mobile.yml` invokes
`tool/verify_favorite_restore_contract.sh` before external-device and upload
jobs, validates an exact HTTPS origin/environment pair plus server-side mutation
binding, and fails closed when protected values are missing. Runtime status is **BLOCKED**, not
PASS: the backend must deploy `GET /api/environment-identity` plus the
server-side `X-Expected-Environment-ID` mutation guard, a reviewed commit must
add the exact deployed origin and stable environment ID to
`tool/staging-release-environments.txt`, and the `mobile-release` environment
still needs the staging URL/origin, two disposable account cookie sets, fixture POI ID, and
`STAGING_CONTRACT_GUARD=tripline-staging-favorite-restore-v1` after the backend
migration is deployed.

- [x] **Step 9: Run and record the automated replacement matrix**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test patrol_test
flutter test test/ui test/app test/flows
flutter test
flutter test integration_test/app_smoke_test.dart -d "$IOS_SIMULATOR_ID"
patrol test -t patrol_test/native_map_smoke_test.dart --device "$IOS_SIMULATOR_ID"
patrol test -t patrol_test/native_map_smoke_test.dart --device "$ANDROID_DEVICE_ID"
flutter analyze
flutter build apk --debug
flutter build ios --simulator --no-codesign
git diff --check
```

Manual QA is no longer an unrecorded release condition. Any case that cannot run must be reported as BLOCKED with its missing device, API key, staging credential, or runner label; it may not be silently counted as PASS.

Execution record (2026-07-19): the canonical command, run, SHA, artifact-count,
and blocker table is
[`docs/mobile-e2e.md`](../../mobile-e2e.md#2026-07-19-verification-record).
Local deterministic, visual, iOS simulator, and native-map checks pass; the
exact-master Android build and product-equivalent Firebase Android device run
also pass. Firebase iOS, the staging favorite-restore contract, and the
current-master TestFlight upload remain explicitly BLOCKED by the credentials
listed in that record.

Commit:

```bash
git add docs/superpowers/plans/2026-07-18-hig-navigation-sheet-semantics.md pubspec.yaml pubspec.lock .gitignore android/app/build.gradle.kts android/app/src/androidTest ios/Podfile ios/Runner.xcodeproj/project.pbxproj ios/RunnerUITests lib/features/chat/chat_screen.dart integration_test patrol_test test .github/workflows/mobile.yml .github/workflows/mobile-e2e.yml
git commit -m "test: automate Tripline release verification"
```

---

## Self-Review

- Spec coverage: Back, Close, Cancel, Done, fixed Root Glass Header, root-title trip switching, nested content sheets, form sheets, immediate selection, dirty dismissal, distinct detents, feature-call-site migration, legacy API removal, reorder mode, Move To Day, HIG symbols, direct Done, the non-drag movement alternative, shared compact-navigation glass, weather state replacement, start/end time, Google category, Dynamic Type, pinned Sliver scrolling, Day synchronization, drag representation, insertion feedback, optimistic settle, map-engine migration, native Google POI selection, external opening, and rollback each have a task and a runnable check.
- Scope boundary: this is intentionally a whole-plan structural refactor. Favorite undo and backend API tests retain their separate data-contract tasks, while the Flutter UI, Root Shell, sheet engine, Timeline, navigation glass, and map adapter may be reorganized to reach one owner per role.
- Dependency check: `google_navigation_flutter ^0.10.0` is the only new production dependency and replaces `google_maps_flutter`; the plan keeps installed `liquid_glass_widgets`, Flutter `PopScope`, native Slivers, and `url_launcher`, with no second map, visibility, scroll-spy, or positioned-list package.
- Type consistency: `TpActionItem`, `TpActionRole`, `TpAppBarRole`, `TpSheetHeader`, `AppSheetFormController`, all semantic `showApp...Sheet` signatures, `TpRootScaffold`, `TripMapController`, `GoogleMapPoiSelection`, and `GoogleMapsExternalLauncher` are introduced before their consumers according to Required Execution Order.
- Data-loss check: both route forms and sheet forms use the same confirmation copy and prevent unconfirmed dismissal.
- Movement check: `pencil` remains reserved for editing data, `line_horizontal_3` identifies reorder, `folder` appears only with the `移到其他 Day` label, and all movement controls retain 44pt hit regions.
- Cleanup check: the final source-usage test prevents regression to feature-owned Root/AppBar/sheet APIs, generic legacy wrappers, multiple Google map SDKs, plugin leakage, and duplicate navigation-glass values.
- Glass check: Root Header, Root Tab, and itinerary/map selector remain separate semantic widgets; compact navigation shares one optical recipe and selection tint, Root Header uses one full-width glass surface, PlatformView only changes the rendering path, and larger sheets/accessories remain size-aware.
- Timeline check: `DayWeatherCard` is the only Timeline weather entry, the selector has no overview option, one `CustomScrollView` owns vertical movement, active Day changes only from post-frame scroll observation, and accessibility sizes reduce columns instead of clamping text.
- Map check: mobile uses map-only `GoogleMapsMapView`, app types do not expose plugin types, Tripline markers/routes/clusters and zoom 12 remain stable, native Google POI selection swaps one accessory slot without mutating trip state, and web uses the same Universal URL builder.
- Platform/privacy check: Android API 24, Kotlin 2.3.0, iOS 16, API-key restrictions, attribution, and mobile builds are explicit; the plan refuses to add background location merely to satisfy an unverified package assumption.
- Landing check: scoped simplification, independent merge-base code review, full verification, screenshot QA, gstack `/review`, Codex adversarial/structured review, resolved findings, and a final evidence summary all gate remote push.
