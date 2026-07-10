# iOS HIG A+ Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve every finding in the 2026-07-10 iOS audit and prove A+ readiness with automated accessibility tests plus iPhone simulator regression evidence.

**Architecture:** Keep the existing router, providers, screens, and design tokens. Fix shared theme defects once, then make the smallest adaptive or semantic change in each responsible widget. Use existing Flutter and iOS platform features only.

**Tech Stack:** Flutter, Dart, Material 3, Cupertino icons, flutter_test, flutter_map, iOS Info.plist.

## Global Constraints

- Keep Tripline's warm brown, sage, and pink identity.
- Do not add packages or create a parallel design-system abstraction.
- No production UI text below 11pt.
- Every audited interactive target must be at least 44×44pt.
- Maximum Dynamic Type must render without overflow.
- Icon-only controls need a localized tooltip or semantic label.
- Custom selectors need button role and selected state.
- Preserve current callbacks, providers, routes, and Android behavior.
- Write a failing regression test before each nontrivial fix.

---

### Task 1: Shared color, typography, and tab-bar foundation

**Files:**
- Modify: `lib/theme/tokens.dart:4-48`
- Modify: `lib/theme/app_theme.dart:307-332`
- Modify: `lib/features/trips/trip_card.dart:105-116`
- Modify: `test/theme/app_theme_test.dart`
- Modify: `test/features/trips/trip_card_test.dart`
- Modify: `test/features/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: `TpColorsLight`, `NavigationBarThemeData`, `TripCard`.
- Produces: contrast-safe tone foregrounds, 11pt minimum eyebrow text, iOS-style tab tint without a Material pill.

- [ ] **Step 1: Add failing token, typography, and navigation tests**

```dart
testWidgets('light tone foregrounds use readable semantic text', (tester) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const Scaffold()));
  final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
  expect(scheme.onSecondaryContainer, scheme.onSurface);
  expect(scheme.onTertiaryContainer, scheme.onSurface);
});

testWidgets('TripCard eyebrow is at least 11pt', (tester) async {
  await pumpCard(tester);
  final text = tester.widget<Text>(find.textContaining('天'));
  expect(text.style?.fontSize, greaterThanOrEqualTo(11));
});

testWidgets('selected tab has tint without Material pill', (tester) async {
  await tester.pumpWidget(buildShellRouter());
  final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
  final theme = NavigationBarTheme.of(tester.element(find.byType(NavigationBar)));
  expect(bar.destinations, hasLength(5));
  expect(theme.indicatorColor, Colors.transparent);
});
```

- [ ] **Step 2: Run the focused tests and confirm they fail**

Run: `flutter test test/theme/app_theme_test.dart test/features/trips/trip_card_test.dart test/features/shell/app_shell_test.dart`

Expected: failures for tone foreground, 10pt eyebrow, and nontransparent navigation indicator.

- [ ] **Step 3: Apply the minimal shared fixes**

```dart
// AppTheme.light ColorScheme
onSecondaryContainer: TpColorsLight.foreground,
onTertiaryContainer: TpColorsLight.foreground,

// NavigationBarThemeData
indicatorColor: Colors.transparent,
overlayColor: WidgetStatePropertyAll(Colors.transparent),

// TripCard eyebrow
fontSize: 11,
```

- [ ] **Step 4: Run focused tests and contrast calculation**

Run: `flutter test test/theme/app_theme_test.dart test/features/trips/trip_card_test.dart test/features/shell/app_shell_test.dart`

Expected: all pass; source-token contrast for information text is at least 4.5:1.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart lib/features/trips/trip_card.dart test/theme/app_theme_test.dart test/features/trips/trip_card_test.dart test/features/shell/app_shell_test.dart
git commit -m "style(design): HIG-004 — improve contrast and iOS tab styling"
```

### Task 2: Maximum Dynamic Type without overflow

**Files:**
- Modify: `lib/features/trip_detail/trip_notes_screen.dart:232-256`
- Modify: `lib/features/trip_detail/widgets/day_pills.dart:73-123`
- Modify: `lib/features/trips/trips_list_screen.dart:300-470`
- Modify: `test/features/trip_detail/trip_notes_screen_test.dart`
- Modify: `test/features/trip_detail/widgets/day_pills_test.dart`
- Modify: `test/features/trips/trips_list_screen_test.dart`

**Interfaces:**
- Consumes: current notes section rows, day callbacks, trip tab filtering.
- Produces: flexing notes header, vertically unconstrained day pills, and large-text trip filters that remain operable.

- [ ] **Step 1: Add AXXXL regression wrappers to existing tests**

```dart
Widget withAxxxl(Widget child) => MediaQuery(
  data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
  child: child,
);

testWidgets('notes section has no exception at AXXXL', (tester) async {
  await pumpNotes(tester, wrapper: withAxxxl);
  expect(tester.takeException(), isNull);
  expect(find.byKey(const ValueKey('notes-count-flights')), findsOneWidget);
});

testWidgets('day pills remain tappable at AXXXL', (tester) async {
  await pumpDays(tester, wrapper: withAxxxl);
  expect(tester.takeException(), isNull);
  expect(tester.getSize(find.byKey(const ValueKey('day-pill-1'))).height, greaterThanOrEqualTo(44));
});
```

- [ ] **Step 2: Run and confirm the current overflow**

Run: `flutter test test/features/trip_detail/trip_notes_screen_test.dart test/features/trip_detail/widgets/day_pills_test.dart test/features/trips/trips_list_screen_test.dart`

Expected: the notes test reports a RenderFlex overflow before the fix.

- [ ] **Step 3: Make headers and selectors adaptive**

```dart
title: Wrap(
  spacing: TpSpacing.s2,
  runSpacing: TpSpacing.s1,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Text(title, style: theme.textTheme.titleMedium),
    countBadge,
  ],
),

// _DayPill: retain minHeight, remove assumptions that content is exactly 44pt.
constraints: const BoxConstraints(minHeight: TpSpacing.tapMin, minWidth: 64),
padding: const EdgeInsets.symmetric(horizontal: TpSpacing.s3, vertical: TpSpacing.s2),
```

Use `LayoutBuilder` plus `MediaQuery.textScalerOf(context).scale(17) >= 24` in the trip-list filter area to switch the three-way segmented control to a vertical `Column` of full-width 44pt choices. Keep the same `_tab` state and callbacks.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/features/trip_detail/trip_notes_screen_test.dart test/features/trip_detail/widgets/day_pills_test.dart test/features/trips/trips_list_screen_test.dart`

Expected: all pass and `tester.takeException()` is null at 2.0 scaling.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trip_detail/trip_notes_screen.dart lib/features/trip_detail/widgets/day_pills.dart lib/features/trips/trips_list_screen.dart test/features/trip_detail/trip_notes_screen_test.dart test/features/trip_detail/widgets/day_pills_test.dart test/features/trips/trips_list_screen_test.dart
git commit -m "style(design): HIG-001 — support maximum Dynamic Type"
```

### Task 3: VoiceOver names, roles, and selected states

**Files:**
- Modify: `lib/features/trips/trips_list_screen.dart:253-258`
- Modify: `lib/features/trips/widgets/destination_picker.dart:75-140`
- Modify: `lib/features/trip_detail/widgets/day_pills.dart:73-123`
- Modify: `lib/features/trip_detail/trip_map_screen.dart:193-248`
- Modify: `lib/features/account/settings/appearance_screen.dart:27-36`
- Modify icon-only controls returned by the codebase-memory `IconButton|FloatingActionButton|GestureDetector|InkWell` audit when they have no accessible name.
- Modify corresponding existing widget test files.

**Interfaces:**
- Consumes: existing callbacks and visual labels.
- Produces: localized accessibility names plus selected state with no duplicate child announcement.

- [ ] **Step 1: Add failing semantics assertions**

```dart
expect(
  tester.getSemantics(find.byKey(const ValueKey('trips-create-fab'))),
  matchesSemantics(label: '建立新行程', isButton: true, hasTapAction: true),
);

expect(
  tester.getSemantics(find.byKey(const ValueKey('day-pill-1'))),
  matchesSemantics(label: contains('DAY 01'), isButton: true, isSelected: true, hasTapAction: true),
);

expect(
  tester.getSemantics(find.byKey(const ValueKey('theme-dark'))),
  matchesSemantics(label: '深色', isButton: true, isSelected: true, hasTapAction: true),
);
```

- [ ] **Step 2: Run semantics tests and confirm missing labels/states**

Run: `flutter test test/features/shell/app_shell_test.dart test/features/trips/trips_list_screen_test.dart test/features/trips/create/create_trip_screen_test.dart test/features/trip_detail/widgets/day_pills_test.dart test/features/trip_detail/trip_map_screen_test.dart test/features/account/settings/appearance_screen_test.dart`

Expected: current semantics do not match the required labels or selected states.

- [ ] **Step 3: Add native tooltips and minimal Semantics wrappers**

```dart
FloatingActionButton(
  tooltip: '建立新行程',
  onPressed: () => context.push('/new-trip'),
  child: const Icon(CupertinoIcons.add),
)

Semantics(
  button: true,
  selected: isActive,
  label: 'DAY ${day.dayNum.toString().padLeft(2, '0')}，${DayPills.shortDate(day.date)}',
  child: ExcludeSemantics(child: InkWell(onTap: onTap, child: content)),
)

Semantics(
  button: true,
  selected: mode == m,
  label: label,
  child: ExcludeSemantics(child: ListTile(onTap: selectMode, title: Text(label))),
)
```

Use `tooltip:` for every standard `IconButton` and `FloatingActionButton`; use `Semantics` only for custom tap surfaces that cannot expose role/state natively.

- [ ] **Step 4: Run the full semantics-focused group**

Run: `flutter test test/features/shell test/features/trips test/features/trip_detail test/features/account/settings`

Expected: all pass and no duplicate semantics labels are asserted.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "style(design): HIG-002 — complete VoiceOver semantics"
```

Before committing, use `git diff --name-only` and unstage any file not required by this semantics fix.

### Task 4: Accessible map targets and map policy verification

**Files:**
- Modify: `lib/features/map/global_map_screen.dart:85-119`
- Modify: `lib/features/trip_detail/trip_map_screen.dart:263-286`
- Modify: `test/features/map/global_map_screen_test.dart`
- Modify: `test/features/trip_detail/trip_map_screen_test.dart`
- Modify: `test/features/map/map_adapter_test.dart`
- Create: `docs/reference-map-tiles.md`

**Interfaces:**
- Consumes: `TripMapMarker`, `PoiFavorite`, existing accessible entry cards, current OSM tile preset.
- Produces: 44pt favorite marker targets, named/selected semantics, nonduplicated decorative trip pins, and documented OSM compliance.

- [ ] **Step 1: Add failing marker size and semantics tests**

```dart
final marker = find.byKey(const ValueKey('map-fav-f1'));
expect(tester.getSize(marker), const Size.square(44));
expect(
  tester.getSemantics(marker),
  matchesSemantics(label: contains('收藏地點'), isButton: true, hasTapAction: true),
);
```

- [ ] **Step 2: Run current map tests and confirm 28pt failure**

Run: `flutter test test/features/map/global_map_screen_test.dart test/features/trip_detail/trip_map_screen_test.dart test/features/map/map_adapter_test.dart`

Expected: favorite marker size is 28×28 before the fix.

- [ ] **Step 3: Increase only the hit area**

```dart
TripMapMarker(
  point: TripMapPoint(f.poiLat!, f.poiLng!),
  width: TpSpacing.tapMin,
  height: TpSpacing.tapMin,
  child: Semantics(
    button: true,
    selected: _selectedId == f.id,
    label: '收藏地點，${f.poiName}',
    child: GestureDetector(
      key: ValueKey('map-fav-${f.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedId = f.id),
      child: Center(child: SizedBox.square(dimension: 28, child: markerDot)),
    ),
  ),
)
```

Wrap numbered trip-map pins in `ExcludeSemantics`; their entry cards remain the single accessible interaction path. Assert that `FlutterMapCanvas` keeps `userAgentPackageName: 'com.raychiu.tripline'` and visible attribution.

- [ ] **Step 4: Document production tile requirements**

Write `docs/reference-map-tiles.md` with the current endpoint, application User-Agent, visible attribution requirement, caching prohibition, and the condition that a dedicated provider must replace public OSM tiles if usage exceeds the public policy.

- [ ] **Step 5: Run map tests and commit**

Run: `flutter test test/features/map test/features/trip_detail/trip_map_screen_test.dart`

```bash
git add lib/features/map/global_map_screen.dart lib/features/trip_detail/trip_map_screen.dart test/features/map test/features/trip_detail/trip_map_screen_test.dart docs/reference-map-tiles.md
git commit -m "style(design): HIG-003 — make maps touch and VoiceOver accessible"
```

### Task 5: Reduced motion and chat content inset

**Files:**
- Modify: `lib/app/adaptive.dart:345-395`
- Modify: `lib/features/chat/chat_screen.dart:172-222`
- Modify: `test/app/adaptive_test.dart`
- Modify: `test/features/chat/chat_screen_test.dart`

**Interfaces:**
- Consumes: `MediaQuery.disableAnimations`, existing notice state machine, reverse chat list.
- Produces: immediate notice transitions under Reduce Motion and a stable top inset for the oldest visible message.

- [ ] **Step 1: Add failing reduced-motion and inset tests**

```dart
testWidgets('notice does not slide when animations are disabled', (tester) async {
  await pumpNotice(tester, disableAnimations: true);
  final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
  expect(slide.duration, Duration.zero);
});

testWidgets('chat list reserves top spacing for message header', (tester) async {
  await pumpChat(tester);
  final list = tester.widget<ListView>(find.byKey(const ValueKey('chat-list')));
  expect((list.padding! as EdgeInsets).top, TpSpacing.s5);
});
```

- [ ] **Step 2: Run and confirm current fixed-duration/fixed-padding failures**

Run: `flutter test test/app/adaptive_test.dart test/features/chat/chat_screen_test.dart`

- [ ] **Step 3: Respect platform motion preference and increase list top inset**

```dart
final reduceMotion = MediaQuery.disableAnimationsOf(context);
final slideDuration = reduceMotion ? Duration.zero : TpMotion.normal;
final fadeDuration = reduceMotion ? Duration.zero : TpMotion.fast;

padding: const EdgeInsets.fromLTRB(
  TpSpacing.s4,
  TpSpacing.s5,
  TpSpacing.s4,
  TpSpacing.s4,
),
```

- [ ] **Step 4: Run focused tests and commit**

Run: `flutter test test/app/adaptive_test.dart test/features/chat/chat_screen_test.dart`

```bash
git add lib/app/adaptive.dart lib/features/chat/chat_screen.dart test/app/adaptive_test.dart test/features/chat/chat_screen_test.dart
git commit -m "style(design): HIG-008 — respect Reduce Motion and chat insets"
```

### Task 6: Account density and request microcopy

**Files:**
- Modify: `lib/features/account/account_screen.dart:159-257`
- Modify: `lib/features/chat/chat_message.dart:58-63`
- Modify: `test/features/account/account_screen_test.dart`
- Modify: `test/features/chat/chat_message_test.dart`

**Interfaces:**
- Consumes: `AccountStats` and server request summary text.
- Produces: one compact semantic stats group and user-facing request copy without internal IDs.

- [ ] **Step 1: Add failing structure and sanitization tests**

```dart
expect(find.byKey(const ValueKey('account-stats-group')), findsOneWidget);
final messages = rowToMessages(const TripRequest(
  id: 184,
  tripId: 't1',
  message: '旅伴請求加入收藏 (req #184)',
  status: RequestStatus.completed,
));
expect(messages.first.text, '旅伴請求加入收藏');
```

- [ ] **Step 2: Run tests and confirm current card/internal-ID behavior**

Run: `flutter test test/features/account/account_screen_test.dart test/features/chat/chat_message_test.dart`

- [ ] **Step 3: Replace three cards with one grouped surface and sanitize only suffix IDs**

```dart
String _displayUserText(String message) {
  for (final e in _prefixSummaries.entries) {
    if (message.startsWith(e.key)) return e.value;
  }
  return message.replaceFirst(RegExp(r'\s*\(req\s*#\d+\)\s*$'), '').trim();
}
```

Render the three values as equal-width columns inside one `Container` keyed `account-stats-group`, separated by two 1px vertical dividers. Add one merged semantics label containing all three values.

- [ ] **Step 4: Run focused tests and commit**

```bash
git add lib/features/account/account_screen.dart lib/features/chat/chat_message.dart test/features/account/account_screen_test.dart test/features/chat/chat_message_test.dart
git commit -m "style(design): HIG-010 — simplify stats and user-facing copy"
```

### Task 7: iPhone orientation and title-rule verification

**Files:**
- Modify: `ios/Runner/Info.plist:60-64`
- Modify only top-level screen AppBars that violate the approved collection/workspace title rule.
- Modify the corresponding existing screen tests.

**Interfaces:**
- Consumes: existing screen titles and iPad orientation keys.
- Produces: portrait-only iPhone support while preserving all iPad orientations and a tested title hierarchy.

- [ ] **Step 1: Add orientation and title assertions**

Run before editing:

```bash
plutil -extract UISupportedInterfaceOrientations xml1 -o - ios/Runner/Info.plist
plutil -extract 'UISupportedInterfaceOrientations~ipad' xml1 -o - ios/Runner/Info.plist
```

Expected current iPhone output contains portrait, landscape left, and landscape right.

Add widget assertions that Trips, Favorites, and Account retain `SliverAppBar.large`, while Chat and Map retain compact workspace titles.

- [ ] **Step 2: Remove only iPhone landscape values**

```xml
<key>UISupportedInterfaceOrientations</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
</array>
```

Do not change `UISupportedInterfaceOrientations~ipad`.

- [ ] **Step 3: Verify plist and screen tests**

Run: `plutil -lint ios/Runner/Info.plist && flutter test test/features/chat test/features/map test/features/trips/trips_list_screen_test.dart test/features/favorites/favorites_screen_test.dart test/features/account/account_screen_test.dart`

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/Info.plist test/features
git commit -m "style(design): HIG-011 — align iPhone orientation and title hierarchy"
```

### Task 8: Full regression, simulator QA, and A+ audit

**Files:**
- Modify: `.gstack/design-reports/ios-hig-audit-2026-07-10/design-audit-tripline-ios.md`
- Modify: `.gstack/design-reports/ios-hig-audit-2026-07-10/design-baseline.json`
- Create after-fix screenshots in the report screenshots directory.

**Interfaces:**
- Consumes: all previous task outputs.
- Produces: direct evidence for every A+ criterion.

- [ ] **Step 1: Run static and automated verification**

Run: `dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test`

Expected: formatter clean, analyzer clean, all tests pass.

- [ ] **Step 2: Refresh the code graph and audit remaining risks**

Run codebase-memory change detection, then search for remaining unnamed icon-only controls, production UI text below 11pt, fixed small tap targets, and custom animations without a reduced-motion branch.

- [ ] **Step 3: Run iPhone simulator regression**

Verify Login, Trips, Chat, Global Map, Favorites, Account, Appearance, Timeline, Trip Map, Notes, and Create Trip in light/dark, normal/AXXXL, Reduce Motion, and portrait. Capture after screenshots and inspect the accessibility tree.

- [ ] **Step 4: Recompute score**

Update the report finding table with direct source/test/screenshot evidence. Set A+ only if every acceptance criterion is proved and no high or medium finding remains.

- [ ] **Step 5: Commit report pointers if tracked artifacts exist**

Do not force-add ignored `.gstack` artifacts. Commit only tracked documentation changes required by the repository.
