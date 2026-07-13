# GitHub CI and Manual TestFlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add automatic Flutter CI for `master` and a GitHub Actions button/`gh` command that signs Tripline and uploads one build to TestFlight.

**Architecture:** One workflow contains a Linux `ci` job for pull requests and pushes plus a conditional macOS `testflight` job for `workflow_dispatch`. Apple credentials stay in GitHub Actions secrets; the provisioning profile is downloaded at runtime, Flutter produces the IPA, and the Apple upload action sends it to App Store Connect.

**Tech Stack:** Flutter 3.44.6, Dart 3.12.2, GitHub Actions, Xcode on `macos-15`, App Store Connect API, Apple code signing

## Global Constraints

- Default branch: `master`.
- Bundle ID: `com.raychiu.tripline`.
- Apple team: `8Z6WVFJ574`.
- Deployment is manual-only through `workflow_dispatch`; do not upload TestFlight builds on push or pull request.
- CI runs `flutter analyze --no-fatal-infos` and `flutter test` before any manual deployment; analyzer warnings remain visible while the three pre-existing `master` deprecation infos do not block delivery.
- Use GitHub-hosted runners; do not add Fastlane, Match, a custom release service, or Dart dependencies.
- Never print, commit, or paste certificate passwords, `.p8` contents, `.p12` contents, or the Maps API key.
- This is configuration-only work; the approved design requires configuration validation and a real workflow run instead of new app unit tests.
- Apple export-compliance answers remain an Account Holder decision; do not encode an answer in the workflow before the App Store Connect questionnaire is completed.

---

## Execution Setup: Isolate CI/CD from the Existing Feature Branch

The current checkout is `feature/google-maps-migration`, which contains many changes not present on `master`. Create an isolated branch from `origin/master` and carry over only the design and plan documentation.

- [ ] **Step 1: Resolve the documentation commits and create the worktree**

```bash
SOURCE_ROOT=/Users/ray/Projects/trip-planner.flutter
DESIGN_COMMIT="$(git -C "$SOURCE_ROOT" log -1 --format=%H -- docs/superpowers/specs/2026-07-13-testflight-cicd-design.md)"
PLAN_COMMIT="$(git -C "$SOURCE_ROOT" log -1 --format=%H -- docs/superpowers/plans/2026-07-13-testflight-cicd.md)"
git -C "$SOURCE_ROOT" fetch origin master
git -C "$SOURCE_ROOT" worktree add "$SOURCE_ROOT/.worktrees/testflight-cicd" -b feature/testflight-cicd origin/master
git -C "$SOURCE_ROOT/.worktrees/testflight-cicd" cherry-pick "$DESIGN_COMMIT" "$PLAN_COMMIT"
```

Expected: a clean worktree on `feature/testflight-cicd` containing only the two documentation commits beyond `origin/master`.

- [ ] **Step 2: Verify branch isolation**

```bash
git -C /Users/ray/Projects/trip-planner.flutter/.worktrees/testflight-cicd status --short
git -C /Users/ray/Projects/trip-planner.flutter/.worktrees/testflight-cicd diff --name-only origin/master...HEAD
```

Expected: the status is empty and the diff lists only:

```text
docs/superpowers/plans/2026-07-13-testflight-cicd.md
docs/superpowers/specs/2026-07-13-testflight-cicd-design.md
```

---

### Task 1: Add the CI and TestFlight Workflow

**Files:**
- Create: `.github/workflows/mobile.yml`
- Create: `ios/ExportOptions.plist`
- Test: `.github/workflows/mobile.yml` with Ruby YAML parsing
- Test: `ios/ExportOptions.plist` with `plutil`

**Interfaces:**
- Consumes: existing Flutter project, bundle ID `com.raychiu.tripline`, Apple team `8Z6WVFJ574`, and six GitHub Actions secrets defined in Task 2
- Produces: workflow `Mobile CI / TestFlight`, `ci` job, conditional `testflight` job, and an App Store Connect IPA export configuration

- [ ] **Step 1: Confirm the workflow and export plist do not already exist**

```bash
cd /Users/ray/Projects/trip-planner.flutter/.worktrees/testflight-cicd
test ! -e .github/workflows/mobile.yml
test ! -e ios/ExportOptions.plist
```

Expected: both commands exit successfully with no output.

- [ ] **Step 2: Create `ios/ExportOptions.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>8Z6WVFJ574</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 3: Create `.github/workflows/mobile.yml`**

```yaml
name: Mobile CI / TestFlight

on:
  pull_request:
    branches: [master]
  push:
    branches: [master]
  workflow_dispatch:

permissions:
  contents: read

env:
  FLUTTER_VERSION: '3.44.6'
  IOS_BUNDLE_ID: com.raychiu.tripline

jobs:
  ci:
    name: Analyze and test
    runs-on: ubuntu-24.04
    timeout-minutes: 30
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

  testflight:
    name: Upload to TestFlight
    if: ${{ github.event_name == 'workflow_dispatch' }}
    needs: ci
    runs-on: macos-15
    timeout-minutes: 75
    concurrency:
      group: testflight-${{ github.repository }}
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

      - name: Write iOS build secrets
        env:
          MAPS_API_KEY: ${{ secrets.MAPS_API_KEY }}
        run: |
          set -euo pipefail
          umask 077
          printf 'MAPS_API_KEY=%s\n' "$MAPS_API_KEY" > ios/Flutter/Secrets.xcconfig

      - name: Import Apple Distribution certificate
        uses: Apple-Actions/import-codesign-certs@5142e029c445c10ffc7149d172e540235a065466 # v7.0.0
        with:
          p12-file-base64: ${{ secrets.APPLE_DISTRIBUTION_CERTIFICATE_P12 }}
          p12-password: ${{ secrets.APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD }}

      - name: Download App Store provisioning profile
        uses: Apple-Actions/download-provisioning-profiles@c62019de00bb4395ed414e4a17c98f4e279636de # v6.0.0
        with:
          bundle-id: ${{ env.IOS_BUNDLE_ID }}
          profile-type: IOS_APP_STORE
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}

      - name: Build IPA
        run: |
          set -euo pipefail
          xcodebuild -version
          flutter build ipa \
            --release \
            --build-number="$GITHUB_RUN_ID" \
            --export-options-plist=ios/ExportOptions.plist

      - name: Resolve IPA path
        id: ipa
        run: |
          set -euo pipefail
          ipa_files=(build/ios/ipa/*.ipa)
          if [[ ! -e "${ipa_files[0]}" || "${#ipa_files[@]}" -ne 1 ]]; then
            echo "Expected exactly one IPA in build/ios/ipa" >&2
            exit 1
          fi
          printf 'path=%s\n' "${ipa_files[0]}" >> "$GITHUB_OUTPUT"

      - name: Upload IPA to TestFlight
        uses: Apple-Actions/upload-testflight-build@1ad58030672057aa084b4e96beb6f7a8c627f9e6 # v5.2.1
        with:
          app-path: ${{ steps.ipa.outputs.path }}
          app-type: ios
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_API_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_API_PRIVATE_KEY }}
          wait-for-processing: 'true'
```

- [ ] **Step 4: Validate both configuration files**

```bash
cd /Users/ray/Projects/trip-planner.flutter/.worktrees/testflight-cicd
ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0)); puts "workflow YAML: OK"' .github/workflows/mobile.yml
plutil -lint ios/ExportOptions.plist
git diff --check
```

Expected:

```text
workflow YAML: OK
ios/ExportOptions.plist: OK
```

`git diff --check` produces no output.

- [ ] **Step 5: Commit the workflow**

```bash
git add .github/workflows/mobile.yml ios/ExportOptions.plist
git commit -m "ci: add manual TestFlight delivery"
```

Expected: one commit containing only the workflow and export plist.

---

### Task 2: Create Apple Signing Assets and GitHub Secrets

**Files:**
- Local only: `~/Downloads/Tripline-Apple-Distribution.p12`
- Local only: `~/Downloads/Tripline-AppStoreConnect.p8`
- GitHub repository secrets: six names listed below

**Interfaces:**
- Consumes: Apple Developer Account Holder access, the existing `com.raychiu.tripline` identifier, the existing ignored `ios/Flutter/Secrets.xcconfig`, and authenticated `gh`
- Produces: Apple Distribution certificate/private key, `Tripline App Store` provisioning profile, App Store Connect team API key, and the secrets consumed by Task 1

- [ ] **Step 1: Create the Apple Distribution certificate in Xcode**

In Xcode, open **Xcode → Settings → Accounts**, select the Apple ID and team `8Z6WVFJ574`, choose **Manage Certificates**, click **+**, and select **Apple Distribution**.

Verify the new identity without exposing its private key:

```bash
security find-identity -v -p codesigning | rg 'Apple Distribution:'
```

Expected: exactly one valid `Apple Distribution` identity for the selected team.

- [ ] **Step 2: Export the certificate and private key as a `.p12`**

In Keychain Access, open the login keychain, select **My Certificates**, expand the new Apple Distribution certificate, select the certificate and its private key together, and export them to:

```text
~/Downloads/Tripline-Apple-Distribution.p12
```

Choose a new strong export password. Do not send the password in chat.

Verify only that the file exists:

```bash
test -s "$HOME/Downloads/Tripline-Apple-Distribution.p12"
```

Expected: exit status 0 with no output.

- [ ] **Step 3: Create the App Store provisioning profile**

In Apple Developer **Certificates, Identifiers & Profiles → Profiles**, click **+**, select **App Store Connect**, select App ID `com.raychiu.tripline`, select the Apple Distribution certificate from Step 1, name the profile `Tripline App Store`, and generate it.

The file does not need to be committed or stored in GitHub; the workflow downloads this profile through the API each run.

- [ ] **Step 4: Create the team App Store Connect API key**

In App Store Connect, open **Users and Access → Integrations → App Store Connect API → Team Keys**. Create a key named `GitHub TestFlight` with role **App Manager**, download the `.p8` once, and keep the displayed Key ID and Issuer ID available on screen. Rename the downloaded key in Finder to the fixed local filename below.

Expected local filename:

```text
~/Downloads/Tripline-AppStoreConnect.p8
```

Use a team key, not an individual key, because the workflow downloads provisioning profiles.

- [ ] **Step 5: Store all six GitHub Actions secrets without printing their values**

Run in zsh from the main checkout so the existing ignored Maps configuration is available:

```zsh
cd /Users/ray/Projects/trip-planner.flutter
read "APPSTORE_API_KEY_ID?App Store Connect Key ID: "
read "APPSTORE_ISSUER_ID?App Store Connect Issuer ID: "
read -s "APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD?P12 export password: "
echo

gh secret set APPSTORE_API_PRIVATE_KEY < "$HOME/Downloads/Tripline-AppStoreConnect.p8"
printf '%s' "$APPSTORE_API_KEY_ID" | gh secret set APPSTORE_API_KEY_ID
printf '%s' "$APPSTORE_ISSUER_ID" | gh secret set APPSTORE_ISSUER_ID
base64 < "$HOME/Downloads/Tripline-Apple-Distribution.p12" | gh secret set APPLE_DISTRIBUTION_CERTIFICATE_P12
printf '%s' "$APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD" | gh secret set APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD
sed -n 's/^MAPS_API_KEY=//p' ios/Flutter/Secrets.xcconfig | gh secret set MAPS_API_KEY

unset APPSTORE_API_KEY_ID APPSTORE_ISSUER_ID APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD
```

Expected: each `gh secret set` reports success and no secret value appears in terminal output.

- [ ] **Step 6: Verify secret names only**

```bash
gh secret list | rg '^(APPSTORE_API_PRIVATE_KEY|APPSTORE_API_KEY_ID|APPSTORE_ISSUER_ID|APPLE_DISTRIBUTION_CERTIFICATE_P12|APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD|MAPS_API_KEY)[[:space:]]'
```

Expected: all six names appear exactly once. Preserve the `.p8` and `.p12` in secure private storage because the `.p8` cannot be downloaded again.

---

### Task 3: Land and Verify the Workflow End to End

**Files:**
- Verify: `.github/workflows/mobile.yml`
- Verify: `ios/ExportOptions.plist`
- External: GitHub pull request and workflow run
- External: Tripline TestFlight build in App Store Connect

**Interfaces:**
- Consumes: the isolated `feature/testflight-cicd` branch from Execution Setup, Task 1 workflow, and Task 2 secrets/signing assets
- Produces: merged CI/CD configuration on `master`, the same workflow on the current `feature/google-maps-migration` release candidate, and one App Store Connect-accepted TestFlight build of version `0.5.1`

- [ ] **Step 1: Run local project and configuration verification**

```bash
cd /Users/ray/Projects/trip-planner.flutter/.worktrees/testflight-cicd
flutter pub get
flutter analyze --no-fatal-infos
flutter test
ruby -e 'require "yaml"; YAML.parse_file(ARGV.fetch(0)); puts "workflow YAML: OK"' .github/workflows/mobile.yml
plutil -lint ios/ExportOptions.plist
git diff --check
git status --short
```

Expected: analyze has no issues, all tests pass, both configuration files parse, `git diff --check` is silent, and the worktree is clean.

- [ ] **Step 2: Push the isolated branch and create the pull request**

```bash
git push -u origin feature/testflight-cicd
gh pr create \
  --base master \
  --head feature/testflight-cicd \
  --title "ci: add manual TestFlight delivery" \
  --body $'## Summary\n- run Flutter analyze and tests on pull requests and master\n- add a manual signed TestFlight upload\n- keep Apple and Maps credentials in GitHub Actions secrets\n\n## Verification\n- flutter analyze --no-fatal-infos\n- flutter test\n- workflow YAML parse\n- ExportOptions.plist lint'
```

Expected: GitHub returns the new pull request URL.

- [ ] **Step 3: Wait for CI and merge only after it passes**

```bash
gh pr checks --watch
gh pr merge --squash --delete-branch
```

Expected: the `Analyze and test` check passes and the pull request is squash-merged into `master`.

- [ ] **Step 4: Add the merged workflow configuration to the current release candidate**

The isolated worktree deliberately excluded the existing Google Maps/UI feature work. Copy only the tested workflow commit back to the current release-candidate branch, then push it.

```bash
SOURCE_ROOT=/Users/ray/Projects/trip-planner.flutter
WORKTREE_ROOT="$SOURCE_ROOT/.worktrees/testflight-cicd"
WORKFLOW_COMMIT="$(git -C "$WORKTREE_ROOT" log -1 --format=%H -- .github/workflows/mobile.yml ios/ExportOptions.plist)"
git -C "$SOURCE_ROOT" cherry-pick "$WORKFLOW_COMMIT"
git -C "$SOURCE_ROOT" push origin feature/google-maps-migration
```

Expected: `feature/google-maps-migration` contains the same workflow and export plist as `master`, while its existing app changes remain isolated from the CI/CD pull request.

- [ ] **Step 5: Trigger the first manual TestFlight upload with `gh`**

```bash
cd /Users/ray/Projects/trip-planner.flutter
gh workflow run mobile.yml --ref feature/google-maps-migration
sleep 3
RUN_ID="$(gh run list --workflow mobile.yml --event workflow_dispatch --branch feature/google-maps-migration --limit 1 --json databaseId --jq '.[0].databaseId')"
test -n "$RUN_ID"
gh run watch "$RUN_ID" --exit-status
```

Expected: `Analyze and test` passes first, then `Upload to TestFlight` completes successfully.

- [ ] **Step 6: Inspect failures if the workflow does not pass**

Run only when Step 5 exits nonzero:

```bash
gh run view "$RUN_ID" --log-failed
```

Correct the reported root cause, commit and merge the smallest fix, then start a new workflow run so it receives a new build number.

- [ ] **Step 7: Confirm the build in App Store Connect**

Open Tripline in App Store Connect and select **TestFlight**. Confirm a build for app version `0.5.1` appears with the numeric GitHub run ID as its build number.

If App Store Connect shows **Missing Compliance**, the Account Holder must complete Apple's export-compliance questionnaire for the build. Do not guess or automate the legal answer. After Apple marks the build ready, add it to an internal tester group if internal distribution is desired.

- [ ] **Step 8: Record final evidence**

```bash
gh run view "$RUN_ID" --json url,conclusion,headSha,displayTitle,jobs
gh workflow view mobile.yml
```

Expected: the run conclusion is `success`, the workflow is active on `master`, and the App Store Connect UI shows the processed Tripline build.

---

## Completion Boundary

Stop when automatic CI is active on `master`, a manual `gh workflow run mobile.yml --ref feature/google-maps-migration` succeeds, and its `0.5.1` build appears in Tripline TestFlight. External tester review, tester automation, App Store metadata, and production App Store submission remain outside this plan.
