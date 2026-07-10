# Web Commit Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Flutter-relevant behavior from Web commits merged between 2026-07-10 00:00 +0800 and 2026-07-11, without duplicating behavior Flutter already provides.

**Architecture:** Keep the shared Web API as the source of truth. Extend the existing Flutter models, repository method, travel sheet, day header, and entry edit flow in place; do not add a parallel state layer or new dependency. Existing full-screen POI promotion and persistent `ScrollController` remain the Flutter-native equivalents of the Web interactions.

**Tech Stack:** Flutter, Dart, Riverpod, Dio, flutter_test, mocktail.

## Global Constraints

- Preserve the existing offline mutation and OCC flows.
- Keep every interactive control at least 44×44pt and usable with VoiceOver/Dynamic Type.
- Reuse the existing travel bottom sheet and entry edit sheet.
- Do not port Web-only `tp-request`/tmux code or D1 migration code into Flutter.
- Use failing tests before production changes.

## Commit classification

| Web merge | Flutter action |
|---|---|
| `54aa8a3` preserve scroll on mutations | Already covered by persistent controller and refresh/cross-day regression tests; no change |
| `6ce0f8d` eight travel methods | Extend existing travel sheet and parsing |
| `1a3ffb5` same-place/no-travel | Add model/API/UI support; fixes current null-type crash |
| `7b6c7ea` abort Web restore on manual scroll | Browser-only repeated RAF behavior; no Flutter equivalent needed |
| `b748bef` neutral same-place marker | Render a neutral outlined Flutter travel marker |
| `536830e` remove day custom title | Use date as day headline and ignore legacy title/label for display |
| `acfa425` drop D1 day title column | Backend-only migration; no Flutter migration |
| `a0c7e88` inline time/promote/resort | Reuse existing sheets/screens; add missing travel recompute after time edit |
| `794c72a`, `1571028` tp-request spawn fixes | Web tooling only; no Flutter change |

---

### Task 1: Parse and send the new travel contract

**Files:**
- Modify: `lib/models/entry.dart`
- Modify: `lib/models/segment.dart`
- Modify: `lib/api/trip_repository.dart`
- Test: `test/models/entry_test.dart`
- Test: `test/models/segment_test.dart`
- Test: `test/api/trip_repository_test.dart`

**Interfaces:**
- Consumes: Web day payload `travel.submode`, `travel.sameplace`, segment `noTravel`.
- Produces: `Travel.submode`, `Travel.sameplace`, `TripSegment.noTravel`, and `TripRepository.updateSegment(noTravel:)`.

- [ ] **Step 1: Write failing model tests**

```dart
test('Travel.fromJson accepts sameplace payload with null type', () {
  final travel = Travel.fromJson({
    'type': null,
    'submode': null,
    'sameplace': true,
  });
  expect(travel.type, 'sameplace');
  expect(travel.sameplace, isTrue);
});

test('TripSegment.fromJson parses noTravel', () {
  final segment = TripSegment.fromJson({
    'id': 1,
    'mode': 'driving',
    'version': 2,
    'noTravel': 1,
  });
  expect(segment.noTravel, isTrue);
});
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
flutter test test/models/entry_test.dart test/models/segment_test.dart
```

Expected: FAIL because the fields and null-safe parsing do not exist.

- [ ] **Step 3: Implement the smallest model change**

```dart
final String? submode;
final bool sameplace;

factory Travel.fromJson(Map<String, dynamic> json) {
  final sameplace = json['sameplace'] == true;
  final submode = json['submode'] as String?;
  return Travel(
    type: sameplace ? 'sameplace' : submode ?? json['type'] as String? ?? 'transit',
    submode: submode,
    sameplace: sameplace,
  );
}
```

Add `TripSegment.noTravel`, parsing both `true` and `1`.

- [ ] **Step 4: Add a failing repository request test**

```dart
await repository.updateSegment(
  tripId: 'okinawa',
  segmentId: 5,
  mode: 'driving',
  noTravel: true,
);
expect(requestBody['noTravel'], isTrue);
```

- [ ] **Step 5: Add `bool? noTravel` to `updateSegment` and its request body**

```dart
body: {
  'mode': mode,
  'submode': ?submode,
  'min': ?min,
  'noTravel': ?noTravel,
  'expectedVersion': ?expectedVersion,
},
```

- [ ] **Step 6: Run the three targeted tests and verify GREEN**

```bash
flutter test test/models/entry_test.dart test/models/segment_test.dart test/api/trip_repository_test.dart
```

### Task 2: Expose eight travel methods and same-place in the existing sheet

**Files:**
- Modify: `lib/features/trip_detail/widgets/travel_edit_sheet.dart`
- Modify: `lib/features/trip_detail/widgets/travel_pill.dart`
- Test: `test/features/trip_detail/trip_timeline_screen_test.dart`
- Test: `test/features/trip_detail/widgets/travel_pill_test.dart`

**Interfaces:**
- Consumes: Task 1 model and repository fields.
- Produces: eight method choices, optional auto override, required manual minutes, other-name validation, and same-place submission.

- [ ] **Step 1: Add failing widget tests**

```dart
expect(find.byKey(const ValueKey('travel-method-monorail')), findsOneWidget);
expect(find.byKey(const ValueKey('travel-method-bus')), findsOneWidget);
expect(find.byKey(const ValueKey('travel-method-metro')), findsOneWidget);
expect(find.byKey(const ValueKey('travel-method-train')), findsOneWidget);
expect(find.byKey(const ValueKey('travel-method-hsr')), findsOneWidget);
expect(find.byKey(const ValueKey('travel-method-other')), findsOneWidget);
expect(find.byKey(const ValueKey('travel-method-sameplace')), findsOneWidget);
```

Add one save assertion for `mode: transit, submode: metro, min: 25` and one for `noTravel: true`.

- [ ] **Step 2: Run tests and verify RED**

```bash
flutter test test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/widgets/travel_pill_test.dart
```

- [ ] **Step 3: Replace the 3-item tuple with the Web contract**

```dart
const _methods = [
  (key: 'driving', mode: 'driving', submode: null, label: '駕車', auto: true),
  (key: 'walking', mode: 'walking', submode: null, label: '步行', auto: true),
  (key: 'monorail', mode: 'transit', submode: 'monorail', label: '單軌', auto: true),
  (key: 'bus', mode: 'transit', submode: 'bus', label: '公車', auto: true),
  (key: 'metro', mode: 'transit', submode: 'metro', label: '地鐵', auto: false),
  (key: 'train', mode: 'transit', submode: 'train', label: '火車', auto: false),
  (key: 'hsr', mode: 'transit', submode: 'hsr', label: '高鐵', auto: false),
  (key: 'other', mode: 'transit', submode: null, label: '其他', auto: false),
];
```

Derive `mode/submode/min/noTravel` from the selected key at submit time. Do not create another controller or provider.

- [ ] **Step 4: Render same-place as a neutral outlined pill**

```dart
final sameplace = travel.sameplace;
final borderColor = sameplace ? theme.colorScheme.outline : tones.sage;
final foreground = sameplace ? theme.colorScheme.onSurfaceVariant : tones.sageDeep;
```

- [ ] **Step 5: Run targeted tests and verify GREEN**

```bash
flutter test test/features/trip_detail/trip_timeline_screen_test.dart test/features/trip_detail/widgets/travel_pill_test.dart
```

### Task 3: Use date as the day headline

**Files:**
- Modify: `lib/models/day.dart`
- Modify: `lib/features/trip_detail/widgets/day_header.dart`
- Test: `test/models/day_test.dart`
- Test: `test/features/trip_detail/widgets/day_header_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
expect(
  TripDay.fromJson({
    'id': 1,
    'dayNum': 1,
    'date': '2026-07-10',
    'title': 'legacy',
    'label': 'legacy label',
  }).displayTitle,
  '2026-07-10',
);
```

Assert `DayHeader` shows `2026-07-10（五）` once as the headline and does not show either legacy string.

- [ ] **Step 2: Run tests and verify RED**

```bash
flutter test test/models/day_test.dart test/features/trip_detail/widgets/day_header_test.dart
```

- [ ] **Step 3: Make date the display source and remove duplicate date metadata**

```dart
String get displayTitle => date ?? 'Day $dayNum';
```

In `DayHeader`, render `dateLabel` as `titleLarge`, with `Day N` fallback; keep time range and summary as metadata.

- [ ] **Step 4: Run tests and verify GREEN**

```bash
flutter test test/models/day_test.dart test/features/trip_detail/widgets/day_header_test.dart
```

### Task 4: Recompute travel after editing entry times

**Files:**
- Modify: `lib/features/trip_detail/widgets/entry_edit_sheet.dart`
- Test: `test/features/trip_detail/widgets/entry_edit_sheet_test.dart`

- [ ] **Step 1: Extend the existing edit test to expect recompute**

```dart
when(() => repo.recomputeTravel(tripId: 't1')).thenAnswer((_) async {});
verify(() => repo.recomputeTravel(tripId: 't1')).called(1);
```

- [ ] **Step 2: Run the test and verify RED**

```bash
flutter test test/features/trip_detail/widgets/entry_edit_sheet_test.dart
```

- [ ] **Step 3: Reuse the repository after `updateEntry`**

```dart
await repo.updateEntry(...);
try {
  await repo.recomputeTravel(tripId: widget.tripId);
} on Exception {
  // The entry edit succeeded; travel can self-heal on refresh.
}
```

- [ ] **Step 4: Run the test and verify GREEN**

```bash
flutter test test/features/trip_detail/widgets/entry_edit_sheet_test.dart
```

### Task 5: Full verification

**Files:**
- Verify all modified Dart files.

- [ ] **Step 1: Format**

```bash
dart format lib test
```

- [ ] **Step 2: Static analysis**

```bash
flutter analyze
```

- [ ] **Step 3: Full tests**

```bash
flutter test
```

- [ ] **Step 4: Completion audit**

Confirm every Web commit in the classification table is either implemented, proven already covered, or explicitly Web/backend-only. Confirm the original dirty root worktree files remain untouched.
