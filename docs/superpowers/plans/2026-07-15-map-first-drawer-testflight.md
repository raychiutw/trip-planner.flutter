# Tripline Map First Drawer to TestFlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the approved Apple Music/HIG redesign with shared UI primitives, the C Map First Drawer interaction, and publish the verified build to TestFlight.

**Architecture:** Keep the merged Google Maps, Riverpod, GoRouter, and Liquid Glass implementation. Add one shared toolbar/scope layer and one reusable bottom-accessory container, then migrate the remaining root/detail screens to those contracts. Map day selection, active stop, marker selection, horizontal paging, fixed accessory geometry, and camera padding remain one state machine inside `TripMapScreen`; no second domain model or navigation framework is added.

**Tech Stack:** Flutter 3.44.6, Dart 3.11, Riverpod 3, GoRouter 17, google_maps_flutter, Flutter widget tests, GitHub Actions, App Store Connect/TestFlight.

## Global Constraints

- The selected design is C / V3: one `地圖 · DAY NN` scope capsule and a fixed-height horizontally paged POI accessory; fixed DAY tabs, vertical detents, and the old 104pt list must not remain.
- The work covers every Flutter root/detail screen; existing code may be kept, refactored, or replaced.
- Shared page title, toolbar/menu, scope, glass, root-tab clearance, and bottom-accessory behavior are mandatory.
- Root toolbars expose at most two trailing actions; iOS-style more uses a horizontal ellipsis.
- Mockup C's teal is not a production color. V3 dark tokens are canvas `#121214`, surface `#1C1C1E`, elevated surface `#2C2C2E`, foreground `#F5F5F7`, muted `#A1A1A6`, and soft-brown chrome accent `#CBA06E`.
- Root expanded title height is at most 108pt below the safe area and collapses to a geometrically centered inline title.
- The POI accessory is 88pt at standard text (76pt card + 12pt indicator), switches to a non-draggable 144pt accessibility geometry at ≥120% Dynamic Type, has no vertical drag/collapse behavior, and uses horizontal pages with viewport fraction 0.84 to match the V3 HTML's 84% scroll-snap rail.
- Interactive targets are at least 44×44pt and remain operable at 200% text scale.
- Root tab navigation remains five destinations and is never used for POI/day actions.
- Existing API contracts, Google Maps SDK integration, and `GITHUB_RUN_ID` build numbering remain unchanged.
- No new dependency is added.

---

### Task 1: Shared toolbar, scope, and bottom-accessory primitives

**Files:**
- Create: `lib/ui/tp_app_bar.dart`
- Create: `lib/ui/tp_scope_menu.dart`
- Create: `lib/ui/tp_bottom_accessory.dart`
- Modify: `lib/theme/tokens.dart`
- Modify: `lib/theme/app_theme.dart`
- Modify: `lib/ui/tp_root_scroll_scaffold.dart`
- Test: `test/ui/tripline_ui_test.dart`
- Test: `test/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `TpAppBar({required Widget title, List<Widget> actions, bool automaticallyImplyLeading})`.
- Produces: `TpMoreMenuButton<T>({required List<PopupMenuEntry<T>> items, required ValueChanged<T> onSelected})`.
- Produces: `TpScopeMenu<T>({required String label, required T value, required List<TpScopeOption<T>> options, required ValueChanged<T> onSelected})`.
- Produces: `TpBottomAccessory({required Widget child})`, a fixed 88pt transparent rail host with no gesture state; each POI page owns its V3 glass card.

- [x] **Step 1: Add failing primitive tests**

```dart
testWidgets('shared toolbar rejects more than two actions and uses horizontal ellipsis', (tester) async {
  await tester.pumpWidget(app(Scaffold(
    appBar: TpAppBar(
      title: const Text('行程'),
      actions: [TpMoreMenuButton<int>(items: const [], onSelected: (_) {})],
    ),
  )));
  expect(find.byIcon(CupertinoIcons.ellipsis), findsOneWidget);
  expect(find.byIcon(Icons.more_vert), findsNothing);
});

testWidgets('bottom accessory is fixed and leaves paging to its child', (tester) async {
  await tester.pumpWidget(app(const Scaffold(body: TpBottomAccessory(
    child: Text('horizontal pages'),
  ))));
  expect(tester.getSize(find.byType(TpBottomAccessory)).height, 88);
  expect(find.byType(AnimatedContainer), findsNothing);
});

test('V3 dark palette is neutral with soft-brown accent', () {
  final scheme = AppTheme.dark().colorScheme;
  expect(scheme.surface, const Color(0xFF1C1C1E));
  expect(scheme.primary, const Color(0xFFCBA06E));
  expect(TpColorsDark.background, const Color(0xFF121214));
});
```

- [x] **Step 2: Run the new tests and confirm they fail**

Run: `flutter test test/ui/tripline_ui_test.dart`

Expected: compilation fails because the three shared primitives do not exist.

- [x] **Step 3: Implement the primitives**

```dart
enum TpAccessoryDetent { collapsed, medium }

class TpScopeOption<T> {
  const TpScopeOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class TpAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TpAppBar({super.key, required this.title, this.actions = const [], this.automaticallyImplyLeading = true});
  final Widget title;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
```

`TpAppBar` asserts `actions.length <= 2`, centers the title, preserves 44pt slots, and delegates colors/scroll edge to the existing `AppBarTheme`. `TpBottomAccessory` is a fixed 88pt transparent rail host and deliberately owns no vertical gesture or expand/collapse state; horizontal pages render their own V3 glass cards. `TpRootScrollScaffold` sets `toolbarHeight: 56`, `collapsedHeight: 56`, `expandedHeight: 108`, and `centerTitle: true` on its shared `SliverAppBar.large`.

- [x] **Step 4: Format and verify**

Run: `dart format lib/theme/tokens.dart lib/theme/app_theme.dart lib/ui/tp_app_bar.dart lib/ui/tp_scope_menu.dart lib/ui/tp_bottom_accessory.dart lib/ui/tp_root_scroll_scaffold.dart test/theme/app_theme_test.dart test/ui/tripline_ui_test.dart`

Run: `flutter test test/ui/tripline_ui_test.dart`

Expected: PASS.

### Task 2: Root and detail page migration

**Files:**
- Modify: `lib/features/trips/trips_list_screen.dart`
- Modify: `lib/features/favorites/favorites_screen.dart`
- Modify: `lib/features/account/account_screen.dart`
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/map/global_map_screen.dart`
- Modify: `lib/features/trip_detail/entry_poi_screen.dart`
- Modify: `lib/features/trip_detail/trip_map_screen.dart`
- Modify: `lib/features/trip_detail/trip_notes_screen.dart`
- Modify: `lib/features/trip_detail/trip_print_screen.dart`
- Modify: `lib/features/trips/create/create_trip_screen.dart`
- Modify: `lib/features/trips/edit/edit_trip_screen.dart`
- Modify: `lib/features/trips/share/share_screen.dart`
- Modify: `lib/features/trips/collab/collab_screen.dart`
- Modify: `lib/features/account/account_sessions_screen.dart`
- Modify: `lib/features/account/connected_apps_screen.dart`
- Modify: `lib/features/account/developer_apps_screen.dart`
- Modify: `lib/features/account/settings/appearance_screen.dart`
- Modify: `lib/features/account/settings/notifications_screen.dart`
- Modify: `lib/features/account/settings/profile_edit_screen.dart`
- Modify: `lib/features/auth/oauth_consent_screen.dart`
- Modify: `lib/features/favorites/add_to_trip/add_to_trip_screen.dart`
- Modify: `lib/features/favorites/explore/explore_screen.dart`
- Modify: `lib/features/share/public_share_screen.dart`
- Test: `test/ui/shared_ui_usage_test.dart`
- Test: matching widget tests under `test/features/`

**Interfaces:**
- Consumes: `TpRootScrollScaffold`, `TpAppBar`, and `TpMoreMenuButton`.
- Produces: no page-owned root title geometry and no vertical more icon.

- [x] **Step 1: Add failing migration assertions**

```dart
expect(find.byType(TpRootScrollScaffold), findsOneWidget);
final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
expect(appBar.expandedHeight, 108);
expect(find.byIcon(Icons.more_vert), findsNothing);
```

Add these assertions to trips, favorites, account, and representative detail-screen tests. `test/ui/shared_ui_usage_test.dart` recursively scans `lib/features` and fails when a Dart file contains either `appBar: AppBar(` or `SliverAppBar.large(`; shared construction is allowed only in `lib/ui`.

- [x] **Step 2: Confirm the migration tests fail**

Run: `flutter test test/features/trips/trips_list_screen_test.dart test/features/favorites/favorites_screen_test.dart test/features/account/account_screen_test.dart test/features/trip_detail/trip_timeline_screen_test.dart`

Expected: FAIL because root screens still own `SliverAppBar.large` and detail screens still own `AppBar`.

- [x] **Step 3: Migrate screens without changing business callbacks**

Trips, favorites, and account pass their current slivers/actions into `TpRootScrollScaffold`. Chat uses `TpAppBar` because its reverse chat list cannot share the root `CustomScrollView`. Detail screens replace `AppBar` with `TpAppBar`; popup menus with a trailing action use `TpMoreMenuButton`. Existing routing, provider invalidation, form submission, and menu command handlers remain unchanged.

- [x] **Step 4: Verify the screen suite**

Run: `flutter test test/features/trips test/features/favorites test/features/account test/features/chat test/features/trip_detail`

Expected: PASS.

### Task 3: Shared trip section scope

**Files:**
- Create: `lib/features/trip_detail/widgets/trip_section_menu.dart`
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart`
- Modify: `lib/features/trip_detail/trip_notes_screen.dart`
- Modify: `lib/features/trip_detail/trip_map_screen.dart`
- Test: `test/features/trip_detail/trip_timeline_screen_test.dart`
- Test: `test/features/trip_detail/trip_notes_screen_test.dart`
- Test: `test/features/trip_detail/trip_map_screen_test.dart`

**Interfaces:**
- Produces: `TripSectionMenu(section, tripId, selectedDayIndex, days, onSectionSelected, onDaySelected)`.
- Consumes: `TpScopeMenu` and the existing GoRouter locations.

- [x] **Step 1: Add failing navigation tests**

```dart
expect(find.byKey(const ValueKey('trip-section-scope')), findsOneWidget);
expect(find.text('行程'), findsOneWidget);
expect(find.byKey(const ValueKey('trip-secondary-map')), findsNothing);
expect(find.byKey(const ValueKey('trip-secondary-notes')), findsNothing);
```

Map asserts one `trip-section-scope`, no `trip-map-day-tabs`, and a visible label `地圖 · 總覽`. Notes asserts `筆記` and can navigate back to itinerary/map from the same menu.

- [x] **Step 2: Confirm failure**

Run: `flutter test test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/trip_notes_screen_test.dart test/features/trip_detail/trip_map_screen_test.dart`

Expected: FAIL because the timeline still renders two tonal buttons and the map still renders fixed day pills.

- [x] **Step 3: Implement one trip scope**

```dart
enum TripSection { itinerary, map, notes }

String tripSectionLabel(TripSection value) => switch (value) {
  TripSection.itinerary => '行程',
  TripSection.map => '地圖',
  TripSection.notes => '筆記',
};
```

Timeline renders `行程 ▾`; notes renders `筆記 ▾`; map renders `地圖 · 總覽 ▾` or `地圖 · DAY NN ▾`. Map menu contains itinerary, notes, overview, and all days but remains one visible capsule. Timeline keeps its content-level sticky DAY strip because it controls the itinerary scroll, not map filtering.

- [x] **Step 4: Verify**

Run: `flutter test test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/trip_notes_screen_test.dart test/features/trip_detail/trip_map_screen_test.dart`

Expected: PASS.

### Task 4: Map First horizontal POI state and camera synchronization

**Files:**
- Inspect: `lib/features/map/map_adapter.dart` (existing `initialPadding` already feeds native `GoogleMap.padding`; no duplicate API added)
- Modify: `lib/features/trip_detail/trip_map_screen.dart`
- Reuse: `test/helpers/fake_trip_map.dart`
- Verify: `test/features/map/map_adapter_test.dart`
- Modify: `test/features/trip_detail/trip_map_screen_test.dart`

**Interfaces:**
- Existing `TripMapCanvasConfig.initialPadding` feeds `GoogleMap.padding`.
- One active entry id drives marker z-index, PageView page, drawer summary, and camera focus.

- [x] **Step 1: Replace fixed-layout tests with C tests**

```dart
expect(find.byKey(const ValueKey('trip-map-day-tabs')), findsNothing);
expect(find.byType(PageView), findsOneWidget);
expect(tester.getSize(find.byKey(const ValueKey('trip-map-poi-drawer'))).height, 88);
expect(find.byType(AnimatedContainer), findsNothing);
```

Add tests for swipe-to-marker focus, marker-to-card page, missing-coordinate entries remaining in the accessory with `尚無位置`, first/last page reachability, 0.84 viewport fraction, absence of vertical drag/collapse behavior, and bottom map padding at least `88 + TpSpacing.navHeight + TpSpacing.s3`.

- [x] **Step 2: Confirm C tests fail**

Run: `flutter test test/features/trip_detail/trip_map_screen_test.dart test/features/map/map_adapter_test.dart`

Expected: FAIL against fixed DAY tabs and fixed 104pt cards.

- [x] **Step 3: Implement the horizontal accessory**

Use a `Stack`: map fills the body; centered `TripSectionMenu` follows the V3 phone mockup; locate/reset controls retain their existing function; fixed `TpBottomAccessory` sits above the root tab. Its child is a `PageView.builder` with `PageController(viewportFraction: 0.84)`, a 12pt page indicator, and per-page glass cards. Because the POI model has no image, cards use the marker number badge rather than a fake thumbnail. Marker tap animates to the matching page. Page change updates active entry and focuses only when coordinates exist. Day selection resets to the first stop in that scope, fits mapped points, and reloads route polylines. No-coordinate stops never create markers but remain in accessory data. Do not add a vertical gesture recognizer, grabber, detent, or collapse control.

- [x] **Step 4: Verify map behavior**

Run: `flutter test test/features/map test/features/trip_detail/trip_map_screen_test.dart`

Expected: PASS.

### Task 5: Full verification and TestFlight delivery

**Files:**
- Modify: `VERSION`, `pubspec.yaml`, and `CHANGELOG.md` only if the current release version has already been uploaded.
- Use: `.github/workflows/mobile.yml` without changing the existing signing secret contract unless verification proves a failure.

- [x] **Step 1: Run repository verification**

Run: `dart format --output=none --set-exit-if-changed .`

Run: `flutter analyze --no-fatal-infos`

Run: `flutter test`

Run: `flutter build ios --release --no-codesign`

Expected: every command exits 0.

- [x] **Step 2: Run visual/runtime acceptance**

Verify 320×568, 390×844, 430×932, light/dark, 200% text, disabled animations, high contrast, first/last horizontal POI, marker selection, and root-tab clearance. Capture screenshots for trips expanded/collapsed, timeline toolbar/scope, and the fixed map POI accessory.

- [x] **Step 3: Commit, push, and land**

Run: `git diff --check`

Commit only the verified implementation, tests, plan, and approved design document. Push `feat/map-first-drawer-testflight`, create a PR against `master`, wait for required checks, and merge without rewriting unrelated history.

- [x] **Step 4: Dispatch and monitor TestFlight**

Run: `gh workflow run mobile.yml --ref master`

Monitor the new run until `Analyze and test`, signing, IPA build, and `Upload IPA to TestFlight` are all successful. Then inspect App Store Connect evidence from the action output/API and require the uploaded build to finish Apple processing; upload start alone is not completion.

Completed via PR #49 and workflow run `29430478068`: Tripline `0.7.0` build `29430478068` finished App Store Connect processing with status `VALID`.
