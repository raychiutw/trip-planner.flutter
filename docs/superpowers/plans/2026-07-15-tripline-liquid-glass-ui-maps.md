# Tripline Liquid Glass UI and Google Maps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Replace the mixed Material/Web root experience with one accessible Tripline UI system, an Apple-style Liquid Glass root tab experience, and Google Maps behavior matching the Web product on iOS and Android.

**Architecture:** Evolve the existing theme into a small set of shared primitives, then migrate screens by information hierarchy rather than by color. Root scroll notifications drive the shell's compact tab state without coupling feature screens to navigation. Map domain models stay stable while the adapter changes to Google Maps and the existing route API supplies real polylines.

**Tech Stack:** Flutter 3.44.6, Dart, Riverpod, GoRouter StatefulShellRoute, google_maps_flutter, geolocator, Sembast, iOS Google Maps SDK, Android manifest placeholders, GitHub Actions.

## Global Constraints

- Five root tabs remain 聊天、行程、地圖、收藏、帳號 and are navigation only.
- Liquid Glass is restricted to navigation and control layers; content surfaces use standard materials.
- Interactive targets are at least 44×44pt; body text baseline is 17pt and support text is at least 11pt.
- Disable animations when MediaQuery.disableAnimations is true; use a more opaque surface in high-contrast mode.
- Keep the wood-brown Tripline brand palette.
- Do not commit Google Maps API keys or print them in CI.
- Do not draw straight-line fallback routes when the route API fails.
- Backend changes are additive and happen in a separate worktree only if current APIs cannot support structured AI actions or human-readable metadata.

---

### Task 1: Liquid Glass root tab system

**Files:**
- Create: lib/ui/tp_glass_surface.dart
- Create: lib/features/shell/apple_root_tab_bar.dart
- Modify: lib/features/shell/app_shell.dart
- Modify: lib/theme/tokens.dart
- Modify: lib/theme/app_theme.dart
- Test: test/features/shell/app_shell_test.dart
- Test: test/ui/tp_glass_surface_test.dart

**Interfaces:**
- Produces: TpGlassSurface({required Widget child, BorderRadius borderRadius, EdgeInsetsGeometry padding})
- Produces: AppleRootTabBar({required int selectedIndex, required ValueChanged<int> onSelected, required bool minimized})
- Produces: RootTabScrollSignal, a Notification carrying bool minimized.

- [ ] **Step 1: Write failing shell tests**

Add tests that assert five Semantics nodes named by the root labels, no NavigationBar, selected state on 聊天, branch switching, vertical down-scroll compaction, vertical up-scroll expansion, and horizontal-scroll immunity.

- [ ] **Step 2: Verify the tests fail**

Run: flutter test test/features/shell/app_shell_test.dart
Expected: FAIL because AppleRootTabBar and the new semantics do not exist.

- [ ] **Step 3: Implement the shared glass and tab interfaces**

TpGlassSurface clips a BackdropFilter blur, selects light/dark tint from ColorScheme, raises opacity when MediaQuery.highContrast is true, and paints one subtle border and shadow. AppleRootTabBar uses five fixed destination records with outline/filled Cupertino icons, 44pt targets, explicit selected semantics, and AnimatedSize/AnimatedOpacity durations set to Duration.zero when animations are disabled.

- [ ] **Step 4: Connect vertical scroll direction to the shell**

Wrap navigationShell with NotificationListener<ScrollNotification>. Ignore nonvertical metrics and Flutter Web. Positive ScrollUpdateNotification.scrollDelta minimizes; negative delta or metrics.pixels <= 0 expands. Selecting any tab expands before calling goBranch.

- [ ] **Step 5: Verify and commit**

Run: dart format lib/ui/tp_glass_surface.dart lib/features/shell/apple_root_tab_bar.dart lib/features/shell/app_shell.dart test/features/shell/app_shell_test.dart test/ui/tp_glass_surface_test.dart
Run: flutter test test/features/shell/app_shell_test.dart test/ui/tp_glass_surface_test.dart
Expected: PASS.

Commit: git commit -m "feat(ui): add Liquid Glass root tab system"

### Task 2: Shared root, content, settings, and state primitives

**Files:**
- Create: lib/ui/tp_root_scroll_scaffold.dart
- Create: lib/ui/tp_content_surface.dart
- Create: lib/ui/tp_settings_group.dart
- Create: lib/ui/tp_state_view.dart
- Test: test/ui/tp_root_scroll_scaffold_test.dart
- Test: test/ui/tp_settings_group_test.dart
- Test: test/ui/tp_state_view_test.dart

**Interfaces:**
- Produces: TpRootScrollScaffold(title, actions, slivers, onRefresh)
- Produces: TpContentSurface(child, onTap, semanticLabel)
- Produces: TpSettingsGroup(title, children) and TpSettingsRow(title, subtitle, value, onTap, trailing, destructive)
- Produces: TpStateView(kind, title, message, actionLabel, onAction) where kind is loading, empty, noResults, offline, permission, error.

- [ ] **Step 1: Write failing primitive tests**

Assert large and inline title behavior, maximum two visible actions with overflow, 44pt settings rows, destructive semantics, six state kinds, retry callback, 200% text scale without overflow, and bottom content inset for the floating tab.

- [ ] **Step 2: Verify failure**

Run: flutter test test/ui
Expected: FAIL because the primitives do not exist.

- [ ] **Step 3: Implement primitives using existing tokens**

Keep one 4pt spacing scale. TpRootScrollScaffold uses SliverAppBar.large for roots and passes root vertical ScrollNotifications. TpContentSurface has no blur. TpSettingsGroup draws inset grouped sections with internal dividers. TpStateView uses one primary recovery action and skeleton slots for loading.

- [ ] **Step 4: Verify and commit**

Run: flutter test test/ui
Expected: PASS.

Commit: git commit -m "feat(ui): add Tripline layout primitives"

### Task 3: Root trips, favorites, chat, and account migration

**Files:**
- Modify: lib/features/trips/trips_list_screen.dart
- Modify: lib/features/favorites/favorites_screen.dart
- Modify: lib/features/chat/chat_screen.dart
- Modify: lib/features/account/account_screen.dart
- Modify: lib/features/account/account_sessions_screen.dart
- Modify: matching tests under test/features/trips, test/features/favorites, test/features/chat, test/features/account

**Interfaces:**
- Consumes: TpRootScrollScaffold, TpContentSurface, TpSettingsGroup, TpStateView.
- Produces: root screens with a common title, state, spacing, and action hierarchy.

- [ ] **Step 1: Add failing screen assertions**

Trips: no FAB, toolbar has 新增行程, no oversized numeric cover. Favorites: selection controls absent until selection mode and one filter trigger. Chat: structured loading state rather than a lone spinner. Account: grouped settings rows and developer tools nested under 進階.

- [ ] **Step 2: Run focused tests to confirm failure**

Run: flutter test test/features/trips test/features/favorites test/features/chat test/features/account
Expected: FAIL on the new hierarchy assertions.

- [ ] **Step 3: Migrate each screen**

Use at most two visible trailing actions, move low-frequency actions to named menus, remove decorative cards, keep business callbacks unchanged, and preserve loading/error data flow.

- [ ] **Step 4: Verify and commit**

Run: flutter test test/features/trips test/features/favorites test/features/chat test/features/account
Expected: PASS.

Commit: git commit -m "feat(ui): align root screens with Apple hierarchy"

### Task 4: Forms and trip-detail action hierarchy

**Files:**
- Modify: lib/features/auth/login_screen.dart
- Modify: lib/features/auth/account_flow_screens.dart
- Modify: lib/features/trip_detail/trip_timeline_screen.dart
- Modify: lib/features/trip_detail/widgets/timeline_entry_tile.dart
- Modify: corresponding auth and trip_detail tests

**Interfaces:**
- Consumes: shared input theme, TpContentSurface, toolbar overflow rule.
- Produces: persistent labels, field-level errors, password visibility/rules, and a detail toolbar with back/edit/more only.

- [ ] **Step 1: Write failing tests**

Assert visible Email/密碼 labels after values are entered, field-level login error mapping, loading submit text retention, trip detail has no more than two trailing actions, and reorder controls exist only in edit mode.

- [ ] **Step 2: Verify failure**

Run: flutter test test/features/auth test/features/trip_detail
Expected: FAIL on the new form and toolbar assertions.

- [ ] **Step 3: Implement the hierarchy changes**

Use InputDecoration.labelText rather than hint-only fields. Keep Email on authentication failure. Place map/notes in content-level secondary navigation and move print/history/share to the named more menu.

- [ ] **Step 4: Verify and commit**

Run: flutter test test/features/auth test/features/trip_detail
Expected: PASS.

Commit: git commit -m "feat(ui): simplify forms and trip detail actions"

### Task 5: Google Maps adapter and trip map behavior

**Files:**
- Modify: pubspec.yaml
- Modify: lib/features/map/map_adapter.dart
- Modify: lib/features/map/global_map_screen.dart
- Modify: lib/features/trip_detail/trip_map_screen.dart
- Modify: lib/api/trip_repository.dart
- Create: lib/features/map/trip_map_view_model.dart
- Create: lib/features/map/route_polyline_repository.dart
- Modify: matching map tests

**Interfaces:**
- Produces: GoogleTripMapController implementing focus, fit, locate, and dispose.
- Produces: TripMapViewModel with visiblePoints, activePointId, selectedDay, routes, and cardIndex.
- Produces: RoutePolylineRepository.fetch(from, to) returning List<LatLng> or an empty list on a recoverable route failure.

- [ ] **Step 1: Replace dependency and write failing pure-Dart tests**

Remove flutter_map and add google_maps_flutter. Test all/day filtering, active/past markers, missing coordinates, single-point bounds, route failure without a straight fallback, and card/marker synchronization.

- [ ] **Step 2: Verify failure**

Run: flutter test test/features/map test/features/trip_detail/trip_map_screen_test.dart
Expected: FAIL until the Google adapter and view model exist.

- [ ] **Step 3: Implement the Google adapter**

Render GoogleMap with Marker, Polyline, camera callbacks, map padding for cards/tab, and a local marker clustering strategy for dense overview data. Keep domain point/route types stable.

- [ ] **Step 4: Align root map with the Web product**

Persist the last opened trip id in the existing Sembast cache. Root /map opens that trip, falls back to the first visible trip, or shows one 新增行程 empty action. Remove tile presets and layer menus.

- [ ] **Step 5: Verify and commit**

Run: flutter test test/features/map test/features/trip_detail/trip_map_screen_test.dart
Expected: PASS.

Commit: git commit -m "feat(map): align Flutter with Google Maps trip view"

### Task 6: iOS, Android, and CI key injection

**Files:**
- Modify: ios/Runner/AppDelegate.swift
- Modify: ios/Runner/Info.plist
- Modify: ios/Flutter/Debug.xcconfig
- Modify: ios/Flutter/Release.xcconfig
- Create: ios/Flutter/Secrets.xcconfig.example
- Modify: android/app/build.gradle.kts
- Modify: android/app/src/main/AndroidManifest.xml
- Create: android/maps.properties.example
- Modify: .gitignore
- Modify: .github/workflows/mobile.yml
- Create: test/platform/maps_configuration_test.dart

**Interfaces:**
- iOS build setting: GOOGLE_MAPS_IOS_API_KEY.
- Android manifest placeholder: GOOGLE_MAPS_ANDROID_API_KEY.
- CI secrets: GOOGLE_MAPS_IOS_API_KEY and GOOGLE_MAPS_ANDROID_API_KEY.

- [ ] **Step 1: Write configuration tests**

Read the tracked platform files and assert key placeholders exist, old generic MAPS_API_KEY is absent from workflow injection, and no tracked file contains a key value.

- [ ] **Step 2: Verify failure**

Run: flutter test test/platform/maps_configuration_test.dart
Expected: FAIL until the separate placeholders and templates exist.

- [ ] **Step 3: Implement secure injection**

AppDelegate reads GOOGLE_MAPS_IOS_API_KEY from Info.plist and calls GMSServices.provideAPIKey. Gradle loads an ignored local properties file or environment variable into the Android manifest placeholder. CI writes only ephemeral local files and never echoes values.

- [ ] **Step 4: Verify and commit**

Run: flutter test test/platform/maps_configuration_test.dart
Run: git grep -n -E 'AIza[0-9A-Za-z_-]{20,}' -- . ':!pubspec.lock'
Expected: test PASS and grep returns no matches.

Commit: git commit -m "build(maps): secure iOS and Android key injection"

### Task 7: Accessibility, responsive, and runtime regression pass

**Files:**
- Modify: tests affected by discovered regressions only
- Create: docs/design-review/2026-07-15-completion-matrix.md

**Interfaces:**
- Produces: one evidence row for every finding in the 2026-07-14 audit and the 2026-07-15 second opinion.

- [ ] **Step 1: Run static and unit verification**

Run: dart format --output=none --set-exit-if-changed .
Run: flutter analyze --no-fatal-infos
Run: flutter test
Expected: all exit 0.

- [ ] **Step 2: Run build verification**

Run: flutter build apk --debug
Run: flutter build ios --debug --no-codesign
Expected: both exit 0 with locally injected map keys.

- [ ] **Step 3: Run visual/accessibility matrix**

Verify 390×844 and 320×568, light/dark, text scale 1.0 and 2.0, animations disabled, high contrast, keyboard open, map card selected, loading/empty/error, and screen-reader labels for all icon-only controls.

- [ ] **Step 4: Complete evidence and commit**

Record file/test/screenshot evidence for every audit finding in docs/design-review/2026-07-15-completion-matrix.md.

Commit: git commit -m "docs: complete Apple HIG design verification"

### Task 8: Backend additive contract only if Flutter evidence requires it

**Files:**
- Worktree: /Users/ray/Projects/trip-planner/.worktrees/tripline-mobile-contract
- Modify only the existing chat/action response schema, handler, tests, and API documentation discovered through the Web code graph.

**Interfaces:**
- New response fields are optional and additive.
- Existing Web clients continue to parse the unchanged fields.

- [ ] **Step 1: Prove the client cannot use existing structured metadata**

Trace the current chat response and mutation preview path. Skip this task entirely if existing metadata is sufficient.

- [ ] **Step 2: Add a failing compatibility test in the backend worktree**

Assert the legacy response fields remain and the optional structured action includes a human-readable label, preview payload, and mutation confirmation requirement.

- [ ] **Step 3: Implement the smallest additive response and verify the backend suite**

Run the backend repository's documented test, lint, and typecheck commands.
Expected: all exit 0.

- [ ] **Step 4: Commit, merge, then update Flutter**

Merge the isolated backend branch only after its full verification passes. Update Flutter parsing and tests in a separate commit.

Commit: git commit -m "feat(api): expose mobile action previews"
