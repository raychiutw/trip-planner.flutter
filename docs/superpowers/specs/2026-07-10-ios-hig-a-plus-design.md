# iOS HIG A+ Remediation Design

## Goal

Raise Tripline's iOS UI/UX from the 2026-07-10 audit baseline of C+ HIG readiness and B default-size visual quality to A+ by resolving every audit finding, then proving the result with widget tests and an iPhone simulator regression run.

## Approved direction

The audit and the instruction to fix everything to A+ establish these product decisions:

- Keep Tripline's warm brown, sage, and pink identity.
- Keep the existing Flutter router, providers, data flow, and screen structure.
- Use native iOS interaction conventions where users notice them most: tab navigation, titles, sheets, selection state, touch targets, semantics, Dynamic Type, and reduced motion.
- Do not rewrite the application wholesale with Cupertino widgets.
- Accessibility is a release gate, not optional polish.

## Approaches considered

### 1. Targeted HIG remediation — selected

Fix shared tokens and the smallest responsible widgets, add regression tests beside existing tests, and retain the current application architecture. This resolves the audit without a platform rewrite or new dependency.

### 2. Full Cupertino rewrite — rejected

This would replace Material scaffolds, navigation, fields, cards, and sheets. It creates a large regression surface while providing little additional user value beyond the targeted approach.

### 3. Cosmetic-only polish — rejected

Changing colors, typography, and navigation styling without repairing Dynamic Type and VoiceOver would improve screenshots but leave the C+ accessibility blockers intact.

## A+ acceptance criteria

### Dynamic Type and responsive layout

- No overflow exception at `TextScaler.linear(2.0)` or the iOS accessibility-extra-extra-extra-large setting on audited screens.
- Notes section titles and count badges wrap or flex without clipping.
- Trips filtering, sorting, day selection, and form actions remain operable at maximum text size.
- iPhone landscape either renders every supported form action accessibly or is removed from supported iPhone orientations. The selected implementation is portrait-only iPhone support because the product has no landscape-specific workflow.

### VoiceOver and semantics

- Every icon-only action has a localized tooltip or semantic label.
- Custom day selectors expose button role and selected state.
- Appearance choices expose selected state.
- Interactive map favorites expose a meaningful place label, button role, selected state, and a 44×44pt hit area.
- Noninteractive trip map pins are excluded from duplicate semantics; the linked entry list remains the accessible navigation path.
- Automated semantics tests cover the audited custom controls.

### Touch and typography

- Every interactive control in the audited flows has an effective minimum hit target of 44×44pt.
- No production text style is smaller than 11pt.
- The TripCard eyebrow moves from 10pt to 11pt.

### Color and contrast

- All information-bearing normal text combinations meet at least 4.5:1 in light and dark mode.
- Light sage and pink container text use accessible semantic foreground colors rather than low-contrast decorative tones.
- Color remains supplementary; selection and category meaning also have text or semantics.

### iOS idiom and hierarchy

- The five existing top-level destinations and branch-state behavior remain unchanged.
- The bottom navigation removes the Material selection pill and uses iOS-style selected icon/label tint with a calm separator surface.
- Top-level screens use a documented title rule: content collections use large titles; workspace screens such as chat and map use compact titles.
- Chat scroll content has a top inset so the first visible message header cannot clip under the trip selector.
- Appearance override remains available because it is an existing user preference, defaults to system, and gains complete selected semantics.

### Motion and content

- Custom animations respect `MediaQuery.disableAnimations`; state changes remain immediate and understandable when motion is disabled.
- Internal request identifiers such as `(req #184)` are removed from user-facing request summaries.
- Chat content containers favor readable line length and spacing; server-generated answer wording is not rewritten in the client.
- Account statistics are presented as one compact semantic group instead of three decorative cards.

### Map release readiness

- OpenStreetMap requests identify the application through the supported `flutter_map` tile configuration.
- OSM attribution remains visible and the test suite no longer emits the anonymous public-tile usage warning.

## Implementation architecture

Changes stay in existing ownership boundaries:

- `lib/theme/`: shared contrast, navigation, typography, and motion primitives.
- `lib/features/shell/`: bottom-tab presentation only; router behavior remains unchanged.
- `lib/features/trip_detail/`: Dynamic Type layout, day-selection semantics, and map semantics.
- `lib/features/map/`: 44pt favorite-marker targets and accessible labels.
- `lib/features/trips/`: Dynamic Type filters, icon labels, minimum typography, and portrait form behavior.
- `lib/features/account/`: appearance selected semantics and compact statistics.
- `lib/features/chat/`: safe top content inset and reduced-motion behavior.
- `ios/Runner/Info.plist`: portrait-only iPhone orientation; iPad orientation support remains unchanged.

No new package, abstraction layer, design-system rewrite, or data-model migration is required.

## Error handling and compatibility

- Existing loading, empty, error, offline, and destructive-confirmation behavior remains intact.
- Semantics wrappers must not create duplicate announcements for child labels.
- Large-text adaptations must preserve default-size density and current callbacks.
- Platform-specific visual changes must not alter Android routing or business behavior.

## Verification

- Add focused failing widget tests before each behavior change.
- Run the affected test file after each fix and the complete Flutter suite after each logical batch.
- Run `flutter analyze` before simulator QA.
- Re-run the audited screens on iPhone 17 Pro Simulator in light, dark, maximum Dynamic Type, Reduce Motion, and portrait orientation.
- Inspect the accessibility tree for names, roles, selected states, and duplicate announcements.
- Recompute contrast from source tokens.
- Produce an updated audit and baseline with A+ only when all criteria have direct evidence.

## Scope boundary

The remediation does not change API contracts, trip data, authentication, routing destinations, AI response generation, or the overall brand palette. Those changes are not needed to satisfy the audit.
