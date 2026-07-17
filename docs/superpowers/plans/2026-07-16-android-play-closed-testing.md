# Google Play Closed Testing CI/CD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver signed Tripline Android builds to the Google Play `alpha` closed-testing track from a manually triggered GitHub Actions workflow, then prove that an invited tester can install, launch, and render Google Maps in the Play Store build.

**Architecture:** Extend the existing `.github/workflows/mobile.yml` instead of adding another workflow or release framework. A guarded `android_closed` job validates repository secrets, reconstructs the upload keystore, derives a Play-safe version code, builds one signed AAB, and publishes it with a commit-pinned upload action. Google Play App Signing holds the production signing key; the local machine and GitHub hold only the upload key.

**Tech Stack:** Flutter 3.44.6, Gradle Kotlin DSL, GitHub Actions, Google Play Console closed testing, Google Play Developer API, `r0adkll/upload-google-play@e738b9dd8f2476ea806d921b64aacd24f34515a5`, macOS Keychain, GitHub CLI.

## Global Constraints

- Keep the package name `com.raychiu.tripline` and the Play track name `alpha` unchanged.
- Keep TestFlight as the default manual release target.
- Restrict the Android Maps key to Maps SDK for Android and package `com.raychiu.tripline`; authorize both the local upload-certificate SHA-1 and the Google Play app-signing certificate SHA-1.
- Never print, commit, paste into a patch, or store in a tracked file any keystore password, Maps key, or service-account JSON.
- Grant the publishing service account access only to Tripline with `View app information (read-only)` and `Release apps to testing tracks`.
- Do not grant production, financial, order, tester-list, or user-administration permissions.
- Do not add Firebase, Fastlane, Gradle Play Publisher, a custom Play API script, or another workflow file.
- Stop at every explicit human gate. Do not claim completion until a tester installs and launches the Play Store build.

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `.github/workflows/mobile.yml` | Modify | Add the manual Android closed-testing target and its signed AAB publishing job. |
| `test/platform/google_maps_configuration_test.dart` | Modify | Lock the Android release workflow, secret names, safe version-code formula, `alpha` track, and lack of production publishing. |
| `android/upload-keystore.jks` | Create locally; ignored | Hold the Play upload key; never commit it. |
| `docs/superpowers/specs/2026-07-16-android-play-closed-testing-design.md` | Already present | Record the approved architecture and security decisions. |
| `docs/superpowers/plans/2026-07-16-android-play-closed-testing.md` | Track during execution | Record the exact implementation and verification sequence. |

---

### Task 1: Add the guarded Android closed-release workflow

**Files:**

- Modify: `test/platform/google_maps_configuration_test.dart:61`
- Modify: `.github/workflows/mobile.yml:8-17`
- Modify: `.github/workflows/mobile.yml:60-140`

**Interfaces:**

- Consumes: Existing `workflow_dispatch.inputs.runner`, `env.FLUTTER_VERSION`, Gradle signing environment variables, and repository secrets `GOOGLE_MAPS_ANDROID_API_KEY`, `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.
- Produces: Manual choice `release_target=android-closed`, job `android_closed`, signed artifact `build/app/outputs/bundle/release/app-release.aab`, and Play upload to `track: alpha`.

- [ ] **Step 1: Add a failing workflow configuration test**

Append this test inside `main()` after the current workflow test:

```dart
test('workflow 手動發布 Android closed testing 且沒有 production 權限', () {
  final workflow = read('.github/workflows/mobile.yml');

  expect(workflow, contains('release_target:'));
  expect(workflow, contains('- android-closed'));
  expect(workflow, contains('android_closed:'));
  expect(
    workflow,
    contains(r"inputs.release_target == 'android-closed'"),
  );
  expect(workflow, contains('secrets.ANDROID_KEYSTORE_BASE64'));
  expect(workflow, contains('secrets.ANDROID_KEYSTORE_PASSWORD'));
  expect(workflow, contains('secrets.ANDROID_KEY_ALIAS'));
  expect(workflow, contains('secrets.ANDROID_KEY_PASSWORD'));
  expect(workflow, contains('secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'));
  expect(workflow, contains('flutter build appbundle'));
  expect(
    workflow,
    contains('GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT'),
  );
  expect(workflow, contains('GITHUB_RUN_ATTEMPT >= 100'));
  expect(workflow, contains('2100000000'));
  expect(
    workflow,
    contains(
      'r0adkll/upload-google-play@'
      'e738b9dd8f2476ea806d921b64aacd24f34515a5',
    ),
  );
  expect(workflow, contains('track: alpha'));
  expect(workflow, contains('status: completed'));
  expect(workflow, isNot(contains('track: production')));
  expect(workflow, isNot(contains('tracks: production')));
});
```

- [ ] **Step 2: Prove the new test fails before implementation**

Run:

```bash
flutter test test/platform/google_maps_configuration_test.dart
```

Expected: the new test fails at `contains('release_target:')`; the existing tests continue to pass.

- [ ] **Step 3: Add the release-target input and guard TestFlight**

Insert this input before the existing `runner` input in `.github/workflows/mobile.yml`:

```yaml
      release_target:
        description: Mobile release destination
        required: true
        default: testflight
        type: choice
        options:
          - testflight
          - android-closed
```

Replace the `testflight` job condition with:

```yaml
    if: ${{ github.event_name == 'workflow_dispatch' && inputs.release_target == 'testflight' }}
```

This preserves the current no-argument manual behavior because `testflight` remains the default.

- [ ] **Step 4: Add the complete Android closed-testing job**

Append this job after `testflight`:

```yaml
  android_closed:
    name: Upload to Google Play closed testing
    if: ${{ github.event_name == 'workflow_dispatch' && inputs.release_target == 'android-closed' }}
    runs-on: ubuntu-24.04
    timeout-minutes: 45
    concurrency:
      group: android-closed-${{ github.repository }}
      cancel-in-progress: false
    steps:
      - name: Check out source
        uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0

      - name: Set up Flutter
        uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true

      - name: Get dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze --no-fatal-infos

      - name: Test
        run: flutter test

      - name: Validate Android release secrets and decode upload key
        env:
          GOOGLE_MAPS_ANDROID_API_KEY: ${{ secrets.GOOGLE_MAPS_ANDROID_API_KEY }}
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
          GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
        run: |
          set -euo pipefail
          : "${GOOGLE_MAPS_ANDROID_API_KEY:?Missing GOOGLE_MAPS_ANDROID_API_KEY secret}"
          : "${ANDROID_KEYSTORE_BASE64:?Missing ANDROID_KEYSTORE_BASE64 secret}"
          : "${ANDROID_KEYSTORE_PASSWORD:?Missing ANDROID_KEYSTORE_PASSWORD secret}"
          : "${ANDROID_KEY_ALIAS:?Missing ANDROID_KEY_ALIAS secret}"
          : "${ANDROID_KEY_PASSWORD:?Missing ANDROID_KEY_PASSWORD secret}"
          : "${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:?Missing GOOGLE_PLAY_SERVICE_ACCOUNT_JSON secret}"
          umask 077
          printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/upload-keystore.jks

      - name: Build signed Android App Bundle
        env:
          GOOGLE_MAPS_ANDROID_API_KEY: ${{ secrets.GOOGLE_MAPS_ANDROID_API_KEY }}
          ANDROID_KEYSTORE_PATH: upload-keystore.jks
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          set -euo pipefail
          if (( GITHUB_RUN_ATTEMPT >= 100 )); then
            echo "GITHUB_RUN_ATTEMPT must be below 100; start a new workflow run" >&2
            exit 1
          fi
          version_code=$((GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT))
          if (( version_code > 2100000000 )); then
            echo "Android version code exceeds the Google Play limit" >&2
            exit 1
          fi
          flutter build appbundle --release --build-number="$version_code"
          test -f build/app/outputs/bundle/release/app-release.aab

      - name: Upload AAB to Google Play closed testing
        uses: r0adkll/upload-google-play@e738b9dd8f2476ea806d921b64aacd24f34515a5 # v1.1.5
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.raychiu.tripline
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: alpha
          status: completed
```

- [ ] **Step 5: Run the focused test and parse the workflow YAML**

Run:

```bash
dart format test/platform/google_maps_configuration_test.dart
flutter test test/platform/google_maps_configuration_test.dart
ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0)); puts "workflow YAML: OK"' .github/workflows/mobile.yml
```

Expected: Dart reports the file unchanged or formats it; all focused tests pass; Ruby prints `workflow YAML: OK`.

- [ ] **Step 6: Run static analysis and inspect the exact diff**

Run:

```bash
flutter analyze --no-fatal-infos
git diff --check
git diff -- .github/workflows/mobile.yml test/platform/google_maps_configuration_test.dart
```

Expected: analyze exits zero, `git diff --check` prints nothing, and the diff contains only the guarded workflow and its test.

- [ ] **Step 7: Commit the code change**

Run:

```bash
git add .github/workflows/mobile.yml test/platform/google_maps_configuration_test.dart
git commit -m "ci: add Google Play closed testing delivery"
```

Expected: one commit records both the test and implementation.

---

### Task 2: Create and verify the Android upload key locally

**Files:**

- Create locally: `android/upload-keystore.jks` (already ignored by both `.gitignore` files)
- Verify only: `android/app/build.gradle.kts:20-83`
- Verify only: `pubspec.yaml:19`

**Interfaces:**

- Consumes: Android Studio JBR `keytool`/`jarsigner`, macOS Keychain, the existing Android Maps API key, and Gradle's `ANDROID_KEYSTORE_*` environment-variable contract.
- Produces: Upload-key alias `tripline-upload`, ignored keystore `android/upload-keystore.jks`, upload-certificate SHA-1, Keychain items `tripline-android-upload-keystore` and `tripline-google-maps-android`, and signed first AAB version `0.7.0 (7)`.

- [ ] **Step 1: Verify prerequisites without exposing credentials**

Run:

```zsh
test -x '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool'
test -x /usr/bin/security
test ! -e android/upload-keystore.jks
git check-ignore android/upload-keystore.jks
```

Expected: all commands exit zero and `git check-ignore` prints `android/upload-keystore.jks`. If the keystore already exists when this task is executed, stop and inspect its alias and fingerprint; never overwrite it.

- [ ] **Step 2: Generate one random password, store it in macOS Keychain, and create the upload key**

Run this as one Zsh block so the generated password is never printed:

```zsh
set -euo pipefail
account="$(id -un)"
password="$(openssl rand -base64 36 | tr -d '\n')"
/usr/bin/security add-generic-password \
  -U \
  -a "$account" \
  -s tripline-android-upload-keystore \
  -w "$password"
'/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool' \
  -genkeypair \
  -noprompt \
  -keystore android/upload-keystore.jks \
  -storetype PKCS12 \
  -storepass "$password" \
  -alias tripline-upload \
  -keypass "$password" \
  -keyalg RSA \
  -keysize 2048 \
  -sigalg SHA256withRSA \
  -validity 10000 \
  -dname 'CN=Tripline Android Upload, OU=Mobile, O=Tripline, L=Taipei, ST=Taiwan, C=TW'
unset password
```

Expected: Keychain accepts the credential and `keytool` reports that it generated a 2,048-bit RSA key pair in `android/upload-keystore.jks`.

- [ ] **Step 3: Store the existing Android Maps key in macOS Keychain**

Open Google Cloud Console for the Tripline Android Maps credential. Configure **Application restrictions → Android apps** with package `com.raychiu.tripline` and upload-certificate SHA-1 `58:EC:91:65:F1:A7:CF:8C:C6:B6:BB:B2:B4:1A:3F:6B:27:8C:EB:FA`. Configure **API restrictions → Restrict key → Maps SDK for Android** and save. Copy the key value, then run:

```zsh
read -s "maps_key?Paste GOOGLE_MAPS_ANDROID_API_KEY, then press Return: "
echo
test -n "$maps_key"
/usr/bin/security add-generic-password \
  -U \
  -a "$(id -un)" \
  -s tripline-google-maps-android \
  -w "$maps_key"
unset maps_key
```

Expected: Google Cloud shows the Android application and API restrictions; the pasted value is not echoed; Keychain stores it under `tripline-google-maps-android`. Do not create `android/maps.properties` or `android/key.properties`.

- [ ] **Step 4: Build the first signed AAB using Keychain-backed environment variables**

Run:

```zsh
set -euo pipefail
account="$(id -un)"
password="$(/usr/bin/security find-generic-password -a "$account" -s tripline-android-upload-keystore -w)"
maps_key="$(/usr/bin/security find-generic-password -a "$account" -s tripline-google-maps-android -w)"
GOOGLE_MAPS_ANDROID_API_KEY="$maps_key" \
ANDROID_KEYSTORE_PATH=upload-keystore.jks \
ANDROID_KEYSTORE_PASSWORD="$password" \
ANDROID_KEY_ALIAS=tripline-upload \
ANDROID_KEY_PASSWORD="$password" \
flutter build appbundle --release
unset password maps_key
test -f build/app/outputs/bundle/release/app-release.aab
```

Expected: Flutter creates `build/app/outputs/bundle/release/app-release.aab` with version `0.7.0` and version code `7`.

- [ ] **Step 5: Verify the upload certificate and AAB signature**

Run:

```zsh
set -euo pipefail
account="$(id -un)"
password="$(/usr/bin/security find-generic-password -a "$account" -s tripline-android-upload-keystore -w)"
'/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool' \
  -list \
  -v \
  -keystore android/upload-keystore.jks \
  -storepass "$password" \
  -alias tripline-upload | rg 'Alias name:|SHA256:'
'/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/jarsigner' \
  -verify \
  -verbose \
  -certs \
  build/app/outputs/bundle/release/app-release.aab
unset password
```

Expected: the alias is `tripline-upload`, a SHA-256 certificate fingerprint is shown, and `jarsigner` exits zero with `jar verified`.

- [ ] **Step 6: Human gate — back up the upload key before continuing**

Copy `android/upload-keystore.jks` to an encrypted password manager or encrypted offline backup and record the alias `tripline-upload` plus the Keychain credential name `tripline-android-upload-keystore`. Have the user explicitly confirm the backup is readable before Task 3.

Expected: the only repository copy remains ignored, `git status --short` does not list it, and a separate encrypted backup has been confirmed. This task has no Git commit because it creates ignored secret material only.

---

### Task 3: Bootstrap Tripline and the first closed test in Play Console

**Files:**

- Upload manually: `build/app/outputs/bundle/release/app-release.aab`
- Reference: `docs/superpowers/specs/2026-07-16-android-play-closed-testing-design.md:33-66`

**Interfaces:**

- Consumes: The signed `0.7.0 (7)` AAB from Task 2, Play Console owner access, truthful policy answers, one reviewer login, and 12 tester Google accounts.
- Produces: Play app `com.raychiu.tripline`, Play App Signing enrollment, Google-held app-signing SHA-1 authorized for Maps, closed track `alpha`, accepted upload certificate, first release, tester cohort, and opt-in URL.

- [ ] **Step 1: Register and verify the personal Play Console account**

In Play Console, register the personal developer account, pay the one-time USD 25 fee, complete identity/contact verification, and complete the Android-device verification requested for new personal accounts.

Expected: the Play Console home page no longer shows an account-verification blocker. Do not share the owner password.

- [ ] **Step 2: Create the Tripline app record**

Choose **Create app** and enter:

- App name: `Tripline`
- Default language: `Chinese – Traditional (zh-TW)`
- App or game: `App`
- Free or paid: `Free`
- Package name established by the first bundle: `com.raychiu.tripline`

Accept the required declarations and Play App Signing.

Expected: the dashboard is for Tripline and the bundle package is recognized as `com.raychiu.tripline`.

- [ ] **Step 3: Complete the declarations required to open closed testing**

Complete Play Console's real app-access, ads, content-rating, target-audience, data-safety, privacy-policy, and store-listing questions. Because Tripline requires sign-in for core behavior, create a dedicated reviewer account and put its working credentials and access instructions in **App access**.

Expected: Play Console marks every required setup item for closed testing as complete. Stop for product-owner input rather than guessing any policy answer.

- [ ] **Step 4: Create the first `alpha` release manually**

Navigate to **Test and release → Testing → Closed testing**, create a track whose API-visible name is `alpha`, create a release, upload `build/app/outputs/bundle/release/app-release.aab`, and complete the review/rollout flow.

Expected: Play Console accepts the upload certificate, shows version name `0.7.0`, version code `7`, and records the release under the `alpha` closed track. Resolve any Play review requirement before enabling API automation.

- [ ] **Step 5: Authorize the Play app-signing certificate for Google Maps**

In Play Console, open **Protected with Play → Play Store distribution → Go to Play app signing**, copy the SHA-1 fingerprint under **App signing key certificate** rather than **Upload key certificate**. In Google Cloud Console, edit the same Android Maps key and add another Android application restriction using package `com.raychiu.tripline` plus that Google-held SHA-1. Keep the existing upload-certificate restriction for local signed builds.

Expected: the Maps key has two Android application entries for `com.raychiu.tripline`: upload SHA-1 `58:EC:91:65:F1:A7:CF:8C:C6:B6:BB:B2:B4:1A:3F:6B:27:8C:EB:FA` and the distinct Play app-signing SHA-1. The key remains restricted to Maps SDK for Android.

- [ ] **Step 6: Configure the 12-person tester cohort**

Create one Play Console email list or Google Group containing the 12 available tester Google accounts, attach it to `alpha`, add a monitored feedback email, and copy the opt-in URL. Ask each tester to open the URL with the listed Google account and opt in.

Expected: Play Console shows the tester cohort on `alpha`, the opt-in page opens, and all 12 accounts remain opted in continuously for the required 14-day period. Internal testing does not replace this closed-test cohort.

---

### Task 4: Create least-privilege publishing credentials and GitHub secrets

**Files:**

- Create temporarily outside the repository: `/Users/ray/Downloads/tripline-play-publisher.json`
- Read locally: `android/upload-keystore.jks`
- Modify remotely: GitHub repository Actions secrets

**Interfaces:**

- Consumes: The Task 2 keystore and Keychain items, the Task 3 Play app/track, Google Cloud Console access, Play Console owner access, and authenticated GitHub CLI.
- Produces: Service account `tripline-play-publisher`, downloaded JSON key at the exact temporary path, two app-level Play permissions, and the six named GitHub Actions secrets.

- [ ] **Step 1: Install and authenticate GitHub CLI**

The machine currently has Homebrew but not `gh`. Run:

```bash
brew install gh
gh auth login --web --git-protocol https
gh auth status
```

Expected: `gh auth status` names the correct GitHub account and reports authentication to `github.com`.

- [ ] **Step 2: Create the Google Play publishing service account**

In Google Cloud Console:

1. Create or select a project dedicated to Tripline publishing.
2. Enable **Google Play Android Developer API** (`androidpublisher.googleapis.com`).
3. Create service account `tripline-play-publisher` without project-wide Owner or Editor roles.
4. Create one JSON key and download it exactly as `/Users/ray/Downloads/tripline-play-publisher.json`.

Expected: the JSON file exists locally, is outside the repository, and contains a `client_email` for the dedicated service account. Never print the file contents.

- [ ] **Step 3: Grant only app-level testing permissions in Play Console**

In **Play Console → Users and permissions**, invite the service account's `client_email`. Limit app access to Tripline and grant exactly:

- `View app information (read-only)`
- `Release apps to testing tracks`

Do not grant production release, financial, order, tester-list, or user-management permissions.

Expected: the service account appears as an accepted/active Play Console user with only those two Tripline permissions.

- [ ] **Step 4: Upload the keystore and publishing credentials to GitHub Actions secrets**

Run from the repository root:

```zsh
set -euo pipefail
test -s android/upload-keystore.jks
test -s /Users/ray/Downloads/tripline-play-publisher.json
base64 -i android/upload-keystore.jks | gh secret set ANDROID_KEYSTORE_BASE64
account="$(id -un)"
/usr/bin/security find-generic-password \
  -a "$account" \
  -s tripline-android-upload-keystore \
  -w | gh secret set ANDROID_KEYSTORE_PASSWORD
printf '%s' tripline-upload | gh secret set ANDROID_KEY_ALIAS
/usr/bin/security find-generic-password \
  -a "$account" \
  -s tripline-android-upload-keystore \
  -w | gh secret set ANDROID_KEY_PASSWORD
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON < /Users/ray/Downloads/tripline-play-publisher.json
/usr/bin/security find-generic-password \
  -a "$account" \
  -s tripline-google-maps-android \
  -w | gh secret set GOOGLE_MAPS_ANDROID_API_KEY
```

Expected: each `gh secret set` command confirms the secret was set without printing its value.

- [ ] **Step 5: Verify secret names, never secret values**

Run:

```bash
gh secret list --json name --jq '.[].name' | sort | rg '^(ANDROID_KEYSTORE_BASE64|ANDROID_KEYSTORE_PASSWORD|ANDROID_KEY_ALIAS|ANDROID_KEY_PASSWORD|GOOGLE_PLAY_SERVICE_ACCOUNT_JSON|GOOGLE_MAPS_ANDROID_API_KEY)$'
```

Expected: exactly the six required Android secret names appear. GitHub does not allow reading their values back.

- [ ] **Step 6: Human gate — secure or remove the downloaded JSON key**

After the GitHub secret is verified, ask the user whether `/Users/ray/Downloads/tripline-play-publisher.json` has been placed in an approved encrypted credential backup. Only after explicit confirmation, remove the unencrypted Downloads copy and confirm it no longer exists.

Expected: no plaintext service-account JSON remains in Downloads or the repository. This task has no Git commit because it changes external secret stores only.

---

### Task 5: Land the workflow and prove end-to-end Play Store installation

**Files:**

- Verify: `.github/workflows/mobile.yml`
- Verify: `test/platform/google_maps_configuration_test.dart`
- Verify: `android/upload-keystore.jks` remains ignored

**Interfaces:**

- Consumes: Task 1 tracked workflow, Task 3 initialized `alpha` track and tester cohort, Task 4 GitHub secrets, repository merge approval, and one invited tester device.
- Produces: Merged workflow on `master`, successful GitHub Actions run, automated `alpha` release, Play Store install proof, and final security audit evidence.

- [ ] **Step 1: Run the complete local verification suite**

Run:

```zsh
set -euo pipefail
dart format --output=none --set-exit-if-changed .
flutter analyze --no-fatal-infos
flutter test
ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0)); puts "workflow YAML: OK"' .github/workflows/mobile.yml
git diff --check
git check-ignore android/upload-keystore.jks
git status --short --branch
```

Expected: formatting, analysis, tests, and YAML parsing all pass; the keystore is ignored; only intended tracked commits are present.

- [ ] **Step 2: Push the implementation branch and open the pull request**

Run:

```bash
git push -u origin feat/android-play-closed-testing
gh pr create --fill --base master --head feat/android-play-closed-testing
gh pr checks --watch
```

Expected: the pull request opens against `master` and every required check passes. Review the PR diff before merge.

- [ ] **Step 3: Human gate — merge only after approval**

Show the user the pull-request URL and check results. Merge only after explicit approval, using the repository's normal merge policy.

Expected: the workflow and test are present on `origin/master`; no secret files are in the merge commit.

- [ ] **Step 4: Trigger the first automated closed-testing release**

After the merge reaches `master`, run:

```bash
gh workflow run mobile.yml --ref master -f release_target=android-closed
run_id="$(gh run list --workflow mobile.yml --event workflow_dispatch --branch master --limit 1 --json databaseId --jq '.[0].databaseId')"
test -n "$run_id"
gh run watch "$run_id" --exit-status
```

Expected: `android_closed` runs on Ubuntu, analyze and tests pass, the signed AAB builds, and the pinned upload action reports a successful upload to `alpha`. `testflight` is skipped.

If the run fails, inspect only the failed steps:

```bash
gh run view "$run_id" --log-failed
```

Correct the actual Play Console, permission, signing, or workflow cause; do not rotate secrets or rerun blindly.

- [ ] **Step 5: Verify the automated release in Play Console**

Open the `alpha` closed-testing track and confirm that its newest version code equals `GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT` for the successful run, its status is available to testers, and production contains no release from this workflow.

Expected: the new AAB is under `alpha` and the first manually uploaded version code `7` remains historical.

- [ ] **Step 6: Complete the tester-device acceptance test**

Have one of the 12 invited testers:

1. Open the `alpha` opt-in URL while signed in with the invited Google account.
2. Accept the test invitation.
3. Install or update Tripline from Google Play.
4. Launch Tripline.
5. Sign in with a test account.
6. Open the itinerary map and confirm Google Maps renders.

Expected: the tester launches the Play-delivered build and the authenticated map flow works. Record the successful workflow run URL, installed version name/code, tester device model, and verification date in the implementation handoff.

- [ ] **Step 7: Final security and scope audit**

Run:

```bash
git ls-files android/upload-keystore.jks android/key.properties android/maps.properties
git grep -nE 'tripline-play-publisher|ANDROID_KEYSTORE_PASSWORD=|GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=' -- ':!docs/superpowers/plans/2026-07-16-android-play-closed-testing.md'
```

Expected: both commands print nothing. Confirm in Play Console that the service account still lacks production permission. The work is complete only after Step 6 succeeds.
