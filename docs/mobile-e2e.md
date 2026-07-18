# Mobile E2E automation

Tripline uses two complementary test layers:

- `flutter_test` and `integration_test` for deterministic app-owned state and navigation;
- Patrol 4.6.1 plus Firebase Test Lab for native Google Maps, platform views, system theme, and real-device behavior.

The external device workflow is `.github/workflows/mobile-e2e.yml`. A weekday schedule runs one Android matrix. iOS is manual because Firebase iOS devices are physical and require Apple Development signing.

The Patrol test has two levels. A local run checks the native map lifecycle, zoom 12, overlays, and theme switching even when the developer machine has no production Maps key. The Test Lab workflow builds with `E2E_EXPECT_GOOGLE_POI=true`, so CI additionally fails unless a real Google native POI produces the platform callback. This keeps local setup useful without weakening the external gate.

## One-time Google Cloud setup

1. Enable Firebase Test Lab and Cloud Tool Results in the Firebase/Google Cloud project.
2. Create a dedicated service account and grant both:
   - `roles/cloudtestservice.testAdmin`
   - `roles/firebase.analyticsViewer`
3. Configure GitHub Actions Workload Identity Federation for this repository. Do not create a long-lived JSON service-account key.
4. Add these GitHub repository variables:
   - `FIREBASE_TEST_LAB_PROJECT_ID`
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - `GCP_TEST_LAB_SERVICE_ACCOUNT`
   - `FIREBASE_ANDROID_MODEL` (optional; default `MediumPhone.arm`)
   - `FIREBASE_ANDROID_VERSION` (optional; default `34`)
   - `FIREBASE_IOS_MODEL` (required for iOS)
   - `FIREBASE_IOS_VERSION` (required for iOS and supported by the selected model)
5. Keep `GOOGLE_MAPS_ANDROID_API_KEY` and `GOOGLE_MAPS_IOS_API_KEY` as repository secrets.

The Android job reuses the existing upload-keystore secrets to sign Patrol's debug APK. This is required because the Maps key is restricted to the Tripline package and signing SHA-1; an ephemeral GitHub debug key would render an unauthorized blank map.

Refresh device variables before changing the matrix:

```bash
gcloud firebase test android models list --project PROJECT_ID
gcloud firebase test ios models list --project PROJECT_ID
gcloud firebase test ios models describe MODEL_ID --project PROJECT_ID
```

## One-time Apple setup for Firebase iOS devices

1. Register the explicit App ID `com.raychiu.tripline.RunnerUITests` in Apple Developer.
2. Create iOS App Development provisioning profiles for both:
   - `com.raychiu.tripline`
   - `com.raychiu.tripline.RunnerUITests`
3. Export an Apple Development certificate as a password-protected P12.
4. Add repository secrets:
   - `APPLE_DEVELOPMENT_CERTIFICATE_P12`
   - `APPLE_DEVELOPMENT_CERTIFICATE_PASSWORD`
   - existing `APPSTORE_ISSUER_ID`
   - existing `APPSTORE_API_KEY_ID`
   - existing `APPSTORE_API_PRIVATE_KEY`

The workflow downloads both development profiles, builds a release XCTest bundle, verifies the signatures of `Runner.app` and `RunnerUITests-Runner.app`, and only then uploads it to Test Lab. Firebase re-signs valid inputs for its own physical devices.

## Run and interpret

In GitHub Actions, select **Mobile E2E / Firebase Test Lab** and choose `android`, `ios`, or `all`. Test Lab keeps device video, screenshots, logs, and JUnit results in the matrix result. GitHub also retains the submitted APK/XCTest bundle and the matrix command log for seven days.

Test Lab exit codes are not swallowed:

- `0`: all tests passed;
- `10`: a test failed;
- `15`, `18`, `20`: inconclusive, unsupported matrix, or infrastructure failure; these remain failed CI jobs.

Use one device per default matrix to protect quota. Before increasing the matrix, add a Google Cloud budget alert and check the current [Firebase Test Lab quotas and pricing](https://firebase.google.com/docs/test-lab/usage-quotas-pricing).

## Local build checks

```bash
dart pub global activate patrol_cli 4.4.0
patrol build android --target patrol_test/native_map_smoke_test.dart
patrol build ios --target patrol_test/native_map_smoke_test.dart --debug --simulator
```

To run the same strict native-POI assertion locally, supply a valid platform Maps key and add:

```bash
patrol test \
  --target patrol_test/native_map_smoke_test.dart \
  --dart-define E2E_EXPECT_GOOGLE_POI=true \
  --device DEVICE_ID
```

Official references:

- [Patrol Firebase Test Lab integration](https://patrol.leancode.co/documentation/integrations/firebase-test-lab)
- [Firebase Android command line testing](https://firebase.google.com/docs/test-lab/android/command-line)
- [Firebase iOS XCTest packaging and signing](https://firebase.google.com/docs/test-lab/ios/run-xctest)
