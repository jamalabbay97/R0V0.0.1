# R0 Android QA Report — Sol module

**Date:** 2026-07-12  
**Target:** Current workspace source at commit `a2fdb4e13afc5aaa3e2c34fa94882946cb66bf75`  
**Requested coverage:** Android Emulator; sign-in with a test account; report creation and management; screenshot of every screen; no service account; no real-data changes.

## Result

**Blocked before application runtime validation.** No claim is made that report creation, editing, deletion, viewing, sync, or screen navigation was tested.

Two independent prerequisites made a compliant run impossible:

1. The current source APK could not be built. `flutter build apk --debug` was allowed five minutes and produced no output before timing out. No Gradle, Java, or Dart process remained afterward. The only APK in the workspace (`build/app/outputs/flutter-apk/app-release.apk`) is dated 2026-05-26, while the source commit is dated 2026-07-09, so it was not used as a substitute.
2. No disposable test-account credentials or QA/Firebase-Emulator configuration is present. Creating an account or using a production account would modify real Firebase data, contrary to the test constraint.

An isolated Android 14 emulator (`emulator-5554`) was successfully booted from a disposable AVD data directory. It was not used to install or run an out-of-date APK.

## Screenshots

No R0 screen screenshots were captured. Capturing a screenshot of every application screen requires a successful current-source build and a safe authenticated test session. Substituting screenshots from the stale May APK, or logging into production, would make the report misleading and violate the stated constraints.

## Planned screen and workflow coverage

The following screens were identified from the current source but **not runtime-tested**:

| Area | Screen / workflow | Runtime status | Screenshot |
|---|---|---:|---:|
| Authentication | Login | Blocked | Not captured |
| Dashboard | Home | Blocked | Not captured |
| Report management | Reports list; open/edit; delete; carry-over updates | Blocked | Not captured |
| Report creation | Activity TNB | Blocked | Not captured |
| Report creation | Daily TSUD | Blocked | Not captured |
| Report creation | R0 | Blocked | Not captured |
| Report creation | Truck tracking | Blocked | Not captured |
| Report creation | Machines/equipment stopped | Blocked | Not captured |
| Report management | Generic report editor | Blocked | Not captured |
| Dashboard | Shift timeline dashboard | Blocked | Not captured |
| External reporting | Google Sheets reports | Deliberately not opened: it can initiate service-account use | Not captured |
| Settings | Settings and profile settings | Blocked | Not captured |
| Administration | Admin users | Blocked; role-gated | Not captured |

## Verified issues

### Critical — Service-account credentials are packaged and usable by the client

**Evidence**

- `pubspec.yaml:64` packages `assets/credentials/` as Flutter assets.
- `lib/data/services/google_sheets_service.dart:6` imports `googleapis_auth/auth_io.dart`.
- `lib/data/services/google_sheets_service.dart:2089` calls `clientViaServiceAccount(...)`.
- `lib/data/services/google_sheets_service.dart:2117-2119` reads a configured credential asset and parses it as `ServiceAccountCredentials`.
- `lib/presentation/screens/google_sheets_reports_screen.dart:20` instantiates `GoogleSheetsService` from an application screen.

**Impact**

Any credential asset included in an app build can be extracted by a client. The app can then authenticate to Google Sheets with that service account, bypassing the requirement that no service account be used within the application. This exposes the Sheets integration and makes client-side authorization hard to control or audit.

**Steps to reproduce (non-destructive source verification)**

1. Inspect `pubspec.yaml` and confirm `assets/credentials/` is listed under Flutter assets.
2. Inspect `GoogleSheetsService._loadCredentials` and `_getSheetsApi`.
3. Observe that an asset path is loaded through `rootBundle.loadString`, parsed into `ServiceAccountCredentials`, and passed to `clientViaServiceAccount`.

**Recommended fix**

Immediately revoke and rotate any credential that has ever been shipped. Remove credential assets, `googleapis_auth` service-account flow, and client credential configuration from the mobile app. Move all Sheets reads/writes behind authenticated Cloud Functions or another server-side API that enforces the caller's Firebase identity and role. Add a CI rule that fails any build containing service-account JSON or `assets/credentials/`.

### Medium — No safe, runnable QA environment for report workflows

**Evidence**

- `lib/main.dart:22` initializes the app with `AppFlavor.prod` unconditionally.
- The `.env` file has production Firebase/Sheets configuration names but no test-account variables and no Firebase Emulator Suite routing.
- Current-source `flutter build apk --debug` timed out after five minutes without output in this environment.

**Impact**

QA cannot safely sign in, create/edit/delete reports, or validate synchronization without risking production data. It also prevents repeatable screenshot-based regression coverage.

**Steps to reproduce**

1. Start the app from the current source; `main.dart` selects production flavor before Firebase initialization.
2. Review the supplied configuration variable names; no disposable test user or emulator endpoint is provided.
3. Run `flutter build apk --debug`; in this workspace it does not complete within five minutes and emits no build output.

**Recommended fix**

Add a `qa` flavor selected by `--dart-define`/flavor configuration, route it to Firebase Auth and Firestore emulators (or a segregated QA project), and seed short-lived role-specific test accounts and test reports. Add a documented clean build command and CI artifact so emulator QA never depends on a stale APK.

## Required next inputs to complete this report

1. A current debug/release APK built from commit `a2fdb4e...`, or a functioning local Flutter build path.
2. A disposable test account (and role), or a QA Firebase project/Emulator Suite configuration with seeded non-production reports.
3. Confirmation of the intended test role(s), especially whether admin-only screens must be covered.

With those inputs, the remaining work is to run the full workflow matrix, capture every reachable screen, and append tested results, reproduction steps, and screenshots to this file.
