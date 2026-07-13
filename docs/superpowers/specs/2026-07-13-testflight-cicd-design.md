# GitHub CI and Manual TestFlight Design

## Goal

Add GitHub Actions CI for Tripline and a manually triggered TestFlight upload for the existing App Store Connect app with bundle ID `com.raychiu.tripline`.

## Current State

- The default branch is `master`.
- The repository has no GitHub Actions workflows.
- Flutter is `3.44.6` and Dart is `3.12.2`.
- The app version is sourced from `pubspec.yaml`; the current value is `0.5.1+6`.
- Apple team `8Z6WVFJ574` and automatic signing are configured in the Xcode project.
- App Store Connect and Apple Developer already contain the Tripline app and explicit bundle ID.
- The local keychain has Apple Development identities but no Apple Distribution identity.
- `ios/Flutter/Secrets.xcconfig` supplies the iOS Google Maps key locally and is excluded from version control.

## Chosen Approach

Use one workflow file with two jobs:

1. `ci` runs on pull requests to `master`, pushes to `master`, and manual workflow runs. It uses Ubuntu to run `flutter analyze` and `flutter test`.
2. `testflight` runs only for `workflow_dispatch`, waits for `ci`, then uses a GitHub-hosted macOS runner to sign, build, and upload the IPA.

The same manual workflow can be started from the GitHub Actions **Run workflow** button or with `gh workflow run`.

This keeps normal CI on the cheaper Linux runner and uses macOS only when a TestFlight build is explicitly requested.

## Files

- Create `.github/workflows/mobile.yml` for CI and manual TestFlight delivery.
- Create `ios/ExportOptions.plist` for App Store Connect export settings.

No Fastlane configuration, deployment scripts, or additional Dart packages are needed.

## CI Flow

The `ci` job will:

1. Check out the requested commit.
2. Install Flutter `3.44.6` with dependency caching.
3. Run `flutter pub get`.
4. Run `flutter analyze`.
5. Run `flutter test`.

Any failure stops the workflow. The TestFlight job cannot start unless this job passes.

## TestFlight Flow

The `testflight` job will:

1. Run only when the workflow event is `workflow_dispatch`.
2. Check out the exact commit selected in the Run workflow form or `gh` command.
3. Install Flutter `3.44.6`.
4. Recreate `ios/Flutter/Secrets.xcconfig` from the `MAPS_API_KEY` GitHub secret.
5. Import the Apple Distribution `.p12` into a temporary keychain.
6. Download the current `IOS_APP_STORE` provisioning profile for `com.raychiu.tripline` through the App Store Connect API.
7. Run `flutter build ipa --release` with `ios/ExportOptions.plist` and use the numeric GitHub run ID as the unique iOS build number.
8. Locate the single generated IPA and upload it to TestFlight through the App Store Connect API.
9. Finish after Apple accepts the upload; verify processing separately with a fresh App Store Connect API token.

A TestFlight concurrency group will prevent two manual uploads from running at the same time.

## Signing and Secrets

The setup requires these GitHub Actions secrets:

- `APPSTORE_API_PRIVATE_KEY`: contents of the team App Store Connect API `.p8` key.
- `APPSTORE_API_KEY_ID`: App Store Connect API Key ID.
- `APPSTORE_ISSUER_ID`: App Store Connect API Issuer ID.
- `APPLE_DISTRIBUTION_CERTIFICATE_P12`: base64-encoded Apple Distribution certificate and private key.
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`: password chosen when exporting the `.p12`.
- `MAPS_API_KEY`: existing value from the ignored local `ios/Flutter/Secrets.xcconfig`.

Use a **team** App Store Connect API key with the App Manager role because provisioning-profile download is part of the workflow. Create the Apple Distribution certificate through the Apple account already configured in Xcode, then export the certificate and private key together as a password-protected `.p12`.

Secrets will be written with `gh secret set` from local files or standard input. Their values must not be printed, committed, or pasted into chat. The provisioning profile is downloaded at runtime and is not stored as a repository secret.

## Export Configuration

`ios/ExportOptions.plist` will select App Store Connect distribution, manual signing, `Tripline App Store CI`, and Apple team `8Z6WVFJ574`. The Release build configuration uses the matching Apple Distribution identity and provisioning profile.

## Failure Handling

- Missing or invalid secrets fail before upload and remain visible only as masked workflow errors.
- Analyze or test failures block deployment.
- Certificate/profile mismatch fails the archive or export step; no IPA is uploaded.
- Duplicate or invalid build numbers fail at Apple upload; each new workflow run receives a new numeric GitHub run ID.
- Apple processing is checked after upload through App Store Connect or a fresh API token; upload-step JWTs are not kept alive during long processing waits.
- A failed run is retried by starting a new manual workflow run after correcting the cause.

## Verification and Success Criteria

This is configuration-only work, so it does not add application unit tests. Verification is:

1. Parse the workflow YAML and property-list file locally.
2. Confirm the workflow is visible on the repository Actions page after it reaches `master`.
3. Trigger it with `gh workflow run mobile.yml`.
4. Watch the run through completion with `gh run watch`.
5. Confirm the new build appears under Tripline's TestFlight tab after Apple processing.

The work is complete when automatic CI passes on `master` and one manually triggered build is accepted by App Store Connect.

## Out of Scope

- Automatic TestFlight uploads on every push or tag.
- Automatic external-tester group assignment or TestFlight beta review.
- App Store metadata, screenshots, pricing, review submission, or production release.
- Android deployment.
- Fastlane, Match, a self-hosted runner, or a custom release service.

Add those only when the manual TestFlight path is working and there is a concrete need.
