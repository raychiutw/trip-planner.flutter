# Handoff — 2026-07-20 UI follow-up

## Completed

- Account screen and account sheet show the real app version/build number.
- Unauthenticated users land on the approved Variant B Welcome page; login preserves safe internal deep links.
- Timeline/map Day navigation, map action, free POI-card scrolling, chat keyboard dismissal, and content-under-glass behavior are aligned.
- Shared deletion now uses swipe-to-reveal plus an explicit red delete action; alternate POI deletion has no Undo.
- Signup has a required privacy-consent checkbox. Unchecked submission shows an inline error and does not call `AuthRepository.signup`; failed signup keeps the checked state.

Detailed decisions and acceptance criteria are in `docs/superpowers/plans/2026-07-20-account-welcome-trip-map-chat-follow-up.md`.

## Waiting for specifications

1. Final privacy statement and personal-data collection notice copy.
2. Signup consent API fields, immutable policy-version format, backend storage/transaction, and error codes.
3. Policy-update/re-consent behavior.
4. Public `/privacy` route and links from Welcome, Signup, and Account.
5. Account-deletion copy and flow.

Do not treat the consent flow as complete for release until items 1–4 are implemented. Do not invent temporary legal copy or payload fields.

## Next implementation order

1. Add `/privacy` with the approved content.
2. Add the backend signup consent record and tests.
3. Update Flutter `AuthRepository.signup` to send the agreed consent contract and handle stale-policy responses.
4. Wire all three privacy entry points, then run 200% Dynamic Type, VoiceOver, and iOS real-device checks.

## Verification

Passed in this workspace:

```powershell
C:\flutter-3.44.6\bin\flutter.bat analyze
C:\flutter-3.44.6\bin\flutter.bat test --no-pub test/features/auth/account_flow_screens_test.dart
C:\flutter-3.44.6\bin\flutter.bat test --no-pub test/features/auth/welcome_screen_test.dart test/app/router_test.dart
C:\flutter-3.44.6\bin\flutter.bat test --no-pub test/flows/app_owned_release_flow_test.dart
C:\flutter-3.44.6\bin\flutter.bat test --no-pub test/flows/app_owned_release_flow_artifacts_test.dart
```

The signup test file has 9 passing tests. A previous full run passed 1308 tests; 12 workflow tests failed only because their POSIX `chmod`/bash commands are unavailable on the Windows host.
