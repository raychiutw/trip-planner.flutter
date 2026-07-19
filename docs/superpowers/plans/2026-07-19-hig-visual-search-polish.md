# Tripline HIG Visual and Search Polish Implementation Plan

> **For Codex:** Execute this plan test-first. Reuse the existing Tripline UI components and the installed `liquid_glass_widgets` package; do not add a new UI dependency.

**Goal:** Align the four primary iOS experiences with the approved HIG semantics and mockups, keep large-text layouts stable, and verify the result in the iOS simulator.

**Architecture:** Fix shared tokens and shared UI primitives first so root tabs, sheets, controls, and search behavior cannot drift between pages. Keep feature-specific policy in the owning screen or controller: local favorites search remains immediate, remote Google POI search is debounced and rejects stale responses, and the Google navigation canvas always requests the light map scheme.

**Tech Stack:** Flutter, Riverpod, GoRouter, `liquid_glass_widgets`, `google_navigation_flutter`, Flutter widget tests, iOS Simulator.

**Map camera invariant:** Default entry, trip switching, Day switching, and Tripline POI focus all use one shared zoom level: `13.0`. Google native POI selection does not move the camera.

---

## Task 1: Lock the approved theme, Glass, and root-tab geometry

**Files:**
- Modify: `test/theme/app_theme_test.dart`
- Modify: `test/ui/tp_glass_surface_test.dart`
- Modify: `test/features/shell/app_shell_test.dart`
- Modify: `lib/theme/tokens.dart`
- Modify: `lib/theme/app_theme.dart`
- Modify: `lib/ui/tp_glass_surface.dart`
- Modify: `lib/features/shell/apple_root_tab_bar.dart`

1. Change tests to require the approved dark hierarchy (`#1C1C1E` canvas, `#2C2C2E` surfaces), warm-light hierarchy (`#FFFBF5`, `#FAF4EA`, `#EADFCF`), subtler bright rims, and the installed Liquid Glass root-tab defaults (16pt horizontal inset, 64pt capsule, 32pt radius, 24pt icons, 4pt icon-label gap, 16pt bottom clearance).
2. Run the three test files and confirm the old values fail.
3. Update only the shared tokens, Glass recipe, and root-tab wrapper. Remove local geometry overrides already supplied by `liquid_glass_widgets`.
4. Rerun the tests and confirm they pass in both light and dark themes.

## Task 2: Make modal and toolbar semantics consistent

**Files:**
- Modify: `test/app/adaptive_sheet_test.dart`
- Modify: `test/app/adaptive_test.dart`
- Modify: `test/features/favorites/favorites_screen_test.dart`
- Modify: `lib/app/adaptive.dart`
- Modify: `lib/ui/tp_root_scaffold.dart`
- Modify: `lib/features/favorites/favorites_screen.dart`

1. Update tests to require a fixed near-full selection sheet (0.93/0.93) with no grabber, leading `取消`, centered title, and immediate selection; content sheets use trailing `×`; nested pages use leading Back plus trailing `×`.
2. Update favorites search tests so entering search shows the text action `取消`, clearing only clears the query, and cancelling clears, unfocuses, and returns to the normal header.
3. Add `ScrollViewKeyboardDismissBehavior.onDrag` to the shared root scroll view and cover it with a widget test.
4. Run the focused tests and confirm the old sheet/search controls fail.
5. Implement the behavior through the existing shared sheet scaffold, toolbar button components, and root scroll view; do not create feature-local copies.
6. Rerun the focused tests.

## Task 3: Make local and remote search follow the approved S1 flow

**Files:**
- Modify: `test/app/adaptive_test.dart`
- Modify: `test/features/favorites/explore/explore_screen_test.dart`
- Modify: `test/features/trip_detail/entry_add_route_screen_test.dart`
- Modify: `test/features/trip_detail/entry_poi_screen_test.dart`
- Modify: `lib/app/adaptive.dart`
- Modify: `lib/features/favorites/explore/explore_screen.dart`
- Modify: `lib/features/trip_detail/entry_add_route_screen.dart`
- Modify: `lib/features/trip_detail/entry_poi_screen.dart`

1. Add a testable optional debounce to the existing `AppSearchField`; immediate callbacks remain the default and remote screens opt into 300 ms.
2. Update remote-search tests to require no request below two characters, live search after 300 ms, no redundant submit button, previous results retained while loading, and stale responses ignored.
3. Require the multi-source POI picker to open without automatically focusing the keyboard.
4. Run the focused tests and confirm failures.
5. Implement the minimum shared debounce in `AppSearchField`; keep minimum length and stale-response rules in the existing feature controllers/state objects.
6. Rerun the tests with fake time/pump durations instead of real waits.
7. For local favorites search, render matching substrings in name, address, and note with `onSurface` plus semibold while retaining `onSurfaceVariant` for unmatched text.

## Task 4: Stabilize the large-text timeline (D1)

**Files:**
- Modify: `test/features/trip_detail/widgets/timeline_entry_tile_test.dart`
- Modify: `test/features/trip_detail/trip_timeline_screen_test.dart`
- Modify: `lib/features/trip_detail/widgets/timeline_entry_tile.dart`
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart`

1. Change tests to require one non-wrapping time string such as `09：30 - 11：00`, including at 200% Dynamic Type.
2. Require the D1 structure at every text size: a 32pt rail, 10pt gap, and one content column shared by the time, entry card, and travel pill. Remove the legacy 120pt time column and the responsive layout fork.
3. Lock the selected geometry and HIG-nearest typography: 22pt marker aligned at the top of its time row (no 16pt top spacer), continuous rail through travel rows, 18pt card radius, 16pt card padding, 64pt minimum travel row, Title 3 time, Title 2 place title, and Body 17 summaries.
4. Run the focused tests and confirm the old time-column and smaller semantic styles fail.
5. Let cards grow vertically while the time range remains one line; adjust drag-feedback and test viewport geometry without shrinking the new layout.
6. Rerun widget and full timeline interaction tests.

## Task 5: Keep the Google map readable in every app appearance

**Files:**
- Modify: `test/features/map/map_canvas_mobile_test.dart`
- Modify: `lib/features/map/map_canvas_mobile.dart`

1. Add a pure test proving both app brightness values map to `MapColorScheme.light`.
2. Run the test and confirm dark appearance currently fails.
3. Route both initial creation and appearance updates through the same always-light helper.
4. Rerun the test and existing map tests.

## Task 6: Update final design references and verify the app

**Files:**
- Modify: `docs/discovery/design.md`
- Modify: `docs/superpowers/specs/2026-07-18-hig-action-semantics-favorite-undo-design.md`
- Modify: `docs/design-sessions/2026-07-17-tripline-final.html`

1. Replace conflicting old values for dark canvas, warm-light surfaces, root-tab geometry, selection-sheet grabber/detents, search dismissal semantics, large-text timeline, and always-light Google map.
2. Treat all seven selected artifacts under `.superpowers/brainstorm/84648-1784467344/content` as the comparison matrix: Dark A, Light C1, Place B1, Search S1, Tab A1, and both D1 timeline references.
3. Run `dart format` on changed Dart files and `flutter analyze`.
4. Run the focused tests, then `flutter test`.
5. Run `flutter build ios --simulator`.
6. Boot an iPhone simulator, launch the app, set light/dark appearance and large text, and capture the four primary pages plus search and sheet states.
7. Compare screenshots against the final mockup; fix only evidenced deviations and rerun the affected tests.
8. Run the repository review/simplify workflow and repeat the final verification commands.
