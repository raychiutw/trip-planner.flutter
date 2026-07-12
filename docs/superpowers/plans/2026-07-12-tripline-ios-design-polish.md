# Tripline iOS Design Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all 30 findings from the 2026-07-12 Tripline iOS design audit without changing API contracts.

**Architecture:** Keep existing screens, routes, Riverpod providers, and Material 3 theme. Add only small shared presentation helpers where the same formatting is reused, then simplify each screen in place with existing adaptive components.

**Tech Stack:** Flutter, Dart, Material 3, Riverpod, GoRouter, intl, flutter_test, mocktail.

## Global Constraints

- No new dependencies or image assets.
- Keep all touch targets at least 44 pt.
- Do not change API payloads, routes, persistence, or backend behavior.
- Write or update a focused widget test before each behavior change and observe RED before GREEN.
- All 30 findings in `~/.gstack/projects/trip-planner-flutter/designs/design-audit-20260712/design-audit-tripline-ios.md` must be mapped to a task below.

---

### Task 1: Human-readable account and security presentation

**Files:**
- Modify: `lib/features/account/account_sessions_screen.dart`
- Modify: `lib/features/account/connected_apps_screen.dart`
- Modify: `lib/features/account/developer_apps_screen.dart`
- Modify: `lib/features/account/account_screen.dart`
- Test: `test/features/account/account_sessions_screen_test.dart`
- Test: `test/features/account/connected_apps_screen_test.dart`
- Test: `test/features/account/developer_apps_screen_test.dart`
- Test: `test/features/account/account_screen_test.dart`

**Interfaces:**
- Consumes: existing session and OAuth model timestamps.
- Produces: localized relative/absolute time labels, user-facing device labels, grouped advanced settings.

- [ ] **Step 1: Write failing account presentation tests**

```dart
expect(find.textContaining('T14:'), findsNothing);
expect(find.textContaining('IP 指紋'), findsNothing);
expect(find.textContaining('178381'), findsNothing);
expect(find.text('進階'), findsOneWidget);
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/features/account/account_sessions_screen_test.dart test/features/account/connected_apps_screen_test.dart test/features/account/developer_apps_screen_test.dart test/features/account/account_screen_test.dart`

Expected: FAIL because raw ISO/epoch values and developer rows are still rendered.

- [ ] **Step 3: Implement minimal presentation fixes**

Use `intl` to format local time, omit IP hashes from the list, map unknown current sessions to a user-facing device label, suppress empty OAuth separators, and move developer-only rows under a single `進階` section.

- [ ] **Step 4: Run account tests and verify GREEN**

Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/account test/features/account
git commit -m "style(account): clarify security and app access"
```

### Task 2: Core trip list, timeline, map, notes, and print hierarchy

**Files:**
- Modify: `lib/features/trips/trips_list_screen.dart`
- Modify: `lib/features/trip_detail/trip_timeline_screen.dart`
- Modify: `lib/features/map/global_map_screen.dart`
- Modify: `lib/features/trip_detail/trip_notes_screen.dart`
- Modify: `lib/features/trip_detail/trip_print_screen.dart`
- Test: matching files under `test/features/trips`, `test/features/trip_detail`, and `test/features/map`

**Interfaces:**
- Consumes: existing trip summaries, days, entries, markers, and navigation callbacks.
- Produces: compact labeled cards, overflow app-bar actions, single-day-first map, semantic markers, fullscreen print flow.

- [ ] **Step 1: Write failing hierarchy and semantics tests**

```dart
expect(find.text('位旅伴'), findsWidgets);
expect(find.byTooltip('更多行程操作'), findsOneWidget);
expect(find.bySemanticsLabel(contains('第 1 站')), findsWidgets);
expect(find.byType(BottomNavigationBar), findsNothing);
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `flutter test test/features/trips/trips_list_screen_test.dart test/features/trip_detail/trip_timeline_screen_test.dart test/features/map/global_map_screen_test.dart test/features/trip_detail/trip_notes_screen_test.dart test/features/trip_detail/trip_print_screen_test.dart`

Expected: FAIL on missing labels, overflow action, marker semantics, and current print navigation chrome.

- [ ] **Step 3: Implement core hierarchy fixes**

Remove the unlabeled hero number from trip cards; condense metadata into labeled rows; keep one timeline app-bar action plus overflow; shorten and center day pills; hide reorder affordances outside edit interaction; default maps to a single day and reduce overview markers; add marker semantics; snap bottom place cards; use grouped note rows; hide the shell navigation on print routes.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips lib/features/trip_detail lib/features/map test/features/trips test/features/trip_detail test/features/map
git commit -m "style(trips): focus list timeline and map hierarchy"
```

### Task 3: Chat, favorites, and explore scanning

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`
- Modify: `lib/features/favorites/favorites_screen.dart`
- Modify: `lib/features/favorites/explore/explore_screen.dart`
- Test: `test/features/chat/chat_screen_test.dart`
- Test: `test/features/favorites/favorites_screen_test.dart`
- Test: `test/features/favorites/explore/explore_screen_test.dart`

**Interfaces:**
- Consumes: existing chat markdown, request actions, favorite callbacks, and explore filters.
- Produces: collapsed long replies, action-oriented choices, single-primary-action favorite rows, accessible region menu, adaptive explore layout.

- [ ] **Step 1: Write failing scanning tests**

```dart
expect(find.text('顯示完整回覆'), findsOneWidget);
expect(find.byTooltip('加入行程'), findsWidgets);
expect(find.bySemanticsLabel(contains('地區篩選')), findsOneWidget);
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/features/chat/chat_screen_test.dart test/features/favorites/favorites_screen_test.dart test/features/favorites/explore/explore_screen_test.dart`

Expected: FAIL because long responses are fully expanded and the region control lacks button semantics.

- [ ] **Step 3: Implement minimal scanning fixes**

Collapse long assistant responses after a short preview with an explicit expansion control; replace emoji-only structure with text/action controls where available; make favorite rows navigate as one object with one visible add action; expose un-favorite through swipe/detail; use a semantic menu button; use a full-width explore card when only one result exists.

- [ ] **Step 4: Run tests and verify GREEN**

Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat lib/features/favorites test/features/chat test/features/favorites
git commit -m "style(discovery): make chat and favorites scannable"
```

### Task 4: Forms, settings, login, and theme consistency

**Files:**
- Modify: `lib/features/auth/login_screen.dart`
- Modify: `lib/features/trips/create/create_trip_screen.dart`
- Modify: `lib/features/trips/edit/edit_trip_screen.dart`
- Modify: `lib/features/account/settings/notifications_screen.dart`
- Modify: `lib/features/account/settings/appearance_screen.dart`
- Modify: `lib/theme/app_theme.dart`
- Test: matching auth, trip create/edit, account settings, and theme tests

**Interfaces:**
- Consumes: existing controllers, submit callbacks, theme mode provider, and route names.
- Produces: user-facing copy, one primary CTA per form, native grouped settings, layered dark surfaces.

- [ ] **Step 1: Write failing copy and theme tests**

```dart
expect(find.text('電子郵件'), findsOneWidget);
expect(find.text('SEO'), findsNothing);
expect(find.text('公開分享'), findsOneWidget);
expect(find.text('日期未定'), findsOneWidget);
```

- [ ] **Step 2: Run focused tests and verify RED**

Run: `flutter test test/features/auth test/features/trips/create test/features/trips/edit test/features/account/settings`

Expected: FAIL because old copy and structure remain.

- [ ] **Step 3: Implement form and theme fixes**

Move the login content upward and add existing recovery/signup routes; normalize email copy; move destination search into the field action; rename date modes; replace SEO/publish copy with trip introduction/public sharing; use inset grouped notification rows; preserve system/light/dark options while using layered dark surfaces and neutral text; reduce decorative borders and uniform card radii through existing theme tokens.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Run full verification**

```bash
flutter analyze
flutter test
flutter build ios --simulator
```

Expected: all exit 0.

- [ ] **Step 6: Re-run visual audit**

Launch the app on the existing iOS simulator and capture login, chat, trips, timeline, map, favorites, account, sessions, connected apps, and dark mode screenshots. Verify every F-001–F-030 item against current rendering.

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "style(app): finish iOS design system polish"
```
