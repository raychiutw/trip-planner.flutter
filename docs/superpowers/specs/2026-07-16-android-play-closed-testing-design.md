# Google Play Closed Testing CI/CD Design

## Goal

Let the Tripline development team install signed Android test builds through Google Play, while making the same closed-testing period count toward the production-access requirement for a new personal Play Console account.

## Current State

- The app ID is `com.raychiu.tripline`.
- `.github/workflows/mobile.yml` runs analyze, tests, and an Android debug build on pull requests and pushes to `master`.
- Manual `workflow_dispatch` currently means TestFlight only.
- `android/app/build.gradle.kts` already reads release-signing values from environment variables or ignored `android/key.properties`.
- `android/upload-keystore.jks` and `android/key.properties` are ignored by Git.
- There is no Firebase dependency or Android distribution service to preserve.

## Chosen Approach

Use a personal Google Play Console account and a closed test named `alpha` from the first release. Do not add Firebase App Distribution or a second Android-only workflow.

Extend the existing mobile workflow with a `release_target` choice:

- `testflight` remains the default so the existing manual command keeps its current behavior.
- `android-closed` runs the new Google Play closed-testing job.

Android closed testing is triggered with:

```bash
gh workflow run mobile.yml --ref master -f release_target=android-closed
```

This keeps normal CI, TestFlight, and Android beta delivery in one workflow without sharing signing credentials between platforms.

## One-Time Play Console Bootstrap

### 1. Create and verify the account

Create a personal Play Console account, pay the one-time USD 25 registration fee, verify the account owner's identity and contact details, and complete the required Android-device verification.

Do not share the owner account password with the team. Team members and automation receive separate, limited access.

### 2. Create Tripline in Play Console

Create the Android app with package name `com.raychiu.tripline`, default language Traditional Chinese, app name Tripline, and free pricing. Accept Play App Signing.

Complete the Play Console app setup required to open a closed test, including the app-access declaration and a dedicated reviewer account because core Tripline functionality requires sign-in. Store listing, data-safety, content-rating, target-audience, ads, and policy declarations must match the real app behavior; CI does not fabricate these answers.

### 3. Create the upload key and first release

Generate one password-protected Android upload keystore. Keep an encrypted backup outside the repository, store the local password in macOS Keychain, and pass it through the release-signing environment variables that Gradle already supports. Do not create a plaintext local password file.

Build the first signed AAB locally with the current `pubspec.yaml` build number and upload it manually in Play Console. The first manual upload establishes the package and upload certificate before the publishing API is used. Every later closed-test release is automated.

Use a dedicated Android Maps API key restricted to Maps SDK for Android and package `com.raychiu.tripline`. Allow the upload-certificate SHA-1 for local signed builds. After Play App Signing is enabled, also allow the Google-held app-signing certificate SHA-1 because Play signs the APK delivered to testers with that key.

### 4. Create the closed test

Create a closed-testing track with the API-visible name `alpha`. Add the 12 tester Google accounts through one Play Console email list or Google Group, provide a feedback email, and share the tester opt-in link.

All 12 testers must remain opted in continuously for at least 14 days before the personal account can apply for production access. The CI/CD work stops at the closed track; production access and production rollout remain separate decisions.

### 5. Create API automation credentials

Create a Google Cloud project, enable the Google Play Developer API, and create a dedicated service account. Invite its email from Play Console **Users and permissions** with access only to Tripline and these app permissions:

- View app information (read-only).
- Release apps to testing tracks.

Do not grant production release, financial, order, user-management, or tester-list permissions. The tester list remains manually controlled in Play Console.

## GitHub Actions Flow

The existing `ci` job remains unchanged for pull requests and pushes.

The existing `testflight` job runs only when `release_target == 'testflight'`.

A new `android_closed` job runs on `ubuntu-24.04` only when `release_target == 'android-closed'`. It will:

1. Check out the selected commit.
2. Install the repository's pinned Flutter version with dependency caching.
3. Run `flutter pub get`.
4. Run `flutter analyze --no-fatal-infos`.
5. Run `flutter test`.
6. Validate all Android release secrets before creating files.
7. Decode the upload keystore into ignored `android/upload-keystore.jks` with restrictive file permissions.
8. Require `GITHUB_RUN_ATTEMPT < 100`, calculate a Play-safe version code as `GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT`, and reject values above Play's `2100000000` limit. After 99 attempts, start a new workflow run instead of re-running the old one.
9. Run `flutter build appbundle --release` with that version code and the existing release-signing environment variables.
10. Verify the single expected AAB exists at `build/app/outputs/bundle/release/app-release.aab`.
11. Upload it to the `alpha` track with status `completed` through `r0adkll/upload-google-play` pinned to commit `e738b9dd8f2476ea806d921b64aacd24f34515a5` (`v1.1.5`).

The Android job uses a concurrency group with `cancel-in-progress: false`, so two manual releases cannot publish overlapping Play edits.

## Versioning and Signing

- `versionName` continues to come from `pubspec.yaml`.
- Android `versionCode` uses the workflow run number and attempt, not `GITHUB_RUN_ID`. Current GitHub run IDs exceed Google Play's maximum version-code value.
- A rerun gets a distinct version code because `GITHUB_RUN_ATTEMPT` increases; the explicit `< 100` guard prevents overlap with the next workflow run.
- Play App Signing owns the production app-signing key. GitHub only receives the upload key used to authenticate bundles sent to Play.
- The upload keystore and passwords never appear in source control or workflow logs.

## GitHub Secrets

Add these repository secrets:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded contents of `android/upload-keystore.jks`.
- `ANDROID_KEYSTORE_PASSWORD`: upload-keystore password.
- `ANDROID_KEY_ALIAS`: upload-key alias.
- `ANDROID_KEY_PASSWORD`: upload-key password.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: complete JSON key for the limited Play publishing service account.
- `GOOGLE_MAPS_ANDROID_API_KEY`: the existing Android Maps key.

The Android Maps key is platform-specific and API-restricted; it is not reused for iOS, browser, or server calls.

At runtime the job sets `ANDROID_KEYSTORE_PATH=upload-keystore.jks`, which matches the existing Gradle lookup relative to the Android project root.

## Data Flow

```text
GitHub manual dispatch
  -> analyze and tests
  -> GitHub Secrets create a temporary upload keystore
  -> Flutter/Gradle builds a signed AAB
  -> pinned upload action calls Google Play Developer API
  -> alpha closed-testing track
  -> tester opt-in page and Play Store install/update
```

## Failure Handling

- Missing Maps, keystore, password, alias, or service-account secrets fail before the build.
- Invalid signing values fail the release build; no bundle is uploaded.
- An invalid or reused version code fails before or during Play upload. A new workflow run produces a new code.
- Missing first manual upload, incomplete Play Console declarations, insufficient service-account permissions, or a policy review requirement surface as a failed upload and must be completed in Play Console before retrying.
- Analyze or test failures block the release.
- The service account cannot publish to production even if the workflow is edited incorrectly.

## Verification and Success Criteria

Extend `test/platform/google_maps_configuration_test.dart` with one configuration test covering:

- the `release_target` dispatch choice and guarded Android job;
- the six Android secrets;
- release AAB build, version-code guard, closed `alpha` track, and pinned upload action;
- the absence of any production track in the workflow.

Then verify:

1. `dart format --output=none --set-exit-if-changed .` passes.
2. `flutter analyze --no-fatal-infos` exits zero.
3. `flutter test` passes.
4. A locally signed `flutter build appbundle --release` succeeds before secrets are uploaded.
5. The first AAB is accepted manually by Play Console.
6. The subsequent manual GitHub workflow succeeds.
7. Play Console shows the new bundle under the `alpha` closed test.
8. At least one invited tester opts in, installs Tripline from Play Store, and launches it successfully.

The work is complete only after the installed Play Store build is confirmed on a tester device. Starting the workflow or uploading an AAB alone is not completion.

## Out of Scope

- Firebase App Distribution.
- Automatic release on pushes, pull requests, tags, or merges.
- Production-track permissions or production rollout.
- Automatic tester-list management.
- Fastlane, Gradle Play Publisher, custom Play API scripts, or a second workflow file.
- Store screenshots, marketing copy, pricing, monetization, and policy answers that require product-owner decisions.

Add production delivery only after the 12 testers have remained opted in for 14 days and Play Console grants production access.

## References

- [Create and set up a Play Console app](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Personal-account closed-testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Google Play Developer API service-account setup](https://developers.google.com/android-publisher/getting_started)
- [Play Console testing-track permissions](https://support.google.com/googleplay/android-developer/answer/9844686)
- [`r0adkll/upload-google-play` inputs and first-upload requirement](https://github.com/r0adkll/upload-google-play)
