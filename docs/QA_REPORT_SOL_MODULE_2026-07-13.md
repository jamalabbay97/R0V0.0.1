# R0 QA Report — Sol Module

**Date:** 2026-07-13  
**Source reviewed:** `a2fdb4e13afc5aaa3e2c34fa94882946cb66bf75`  
**Requested scope:** Chrome Emulator, test-account sign-in, every screen, and all report creation/management workflows.  
**Result:** **Blocked before runtime testing.** No real records, accounts, or service accounts were used.

## Test execution and safety controls

| Check | Result |
|---|---|
| Chrome emulator session | Blocked: the local Chrome-control runtime could not start because the environment denied access to its user-profile path. |
| Current-source application build/run | Blocked: the available Flutter command did not return within 30 seconds. The workspace's prior Flutter run log also records a `pthread_create failed` crash. |
| Test account | Not provided. No account was created, and no production account was used. |
| Backend safety | `lib/main.dart` unconditionally selects `AppFlavor.prod`; no Auth/Firestore emulator routing was found. A live sign-in could therefore affect production data. |
| Service account | Deliberately not used. The Google Sheets workflow was not opened. |
| Existing APK | Not used: `build/app/outputs/flutter-apk/app-release.apk` is dated 2026-05-26, earlier than the reviewed source commit. |

## Screenshots

No R0 screenshots were captured. Capturing application screens would require a working current build, Chrome-emulator connection, and a disposable non-production authenticated session. Using the stale APK or signing into production would make the evidence unreliable and violate the requested constraints.

## Screen and workflow coverage

All runtime statuses below are **Not tested — blocked**; no report was created, edited, deleted, synced, exported, or otherwise modified.

| Area | Screen / workflow | Screenshot |
|---|---|---|
| Authentication | Login and sign-in | Not captured |
| Dashboard | Home / report-card navigation | Not captured |
| Report creation | R0 report | Not captured |
| Report creation | Activity report | Not captured |
| Report creation | Daily report | Not captured |
| Report creation | Truck tracking | Not captured |
| Report creation | Machines/equipment stopped | Not captured |
| Report management | Archive/list, view, edit, delete, and carry-over | Not captured |
| Report management | Generic report editor | Not captured |
| Dashboard | Shift timeline | Not captured |
| Settings | Settings and profile settings | Not captured |
| Administration | Admin users (role-gated) | Not captured |
| External reporting | Google Sheets reports | Not captured; intentionally not opened because it can use a service account |

## Findings

### Critical — Client application contains a service-account authentication path

**Evidence**

- `pubspec.yaml:64` bundles `assets/credentials/`.
- `.env:2` configures `GOOGLE_SHEETS_CREDENTIALS_ASSET_PATH=assets/credentials/service-account.json`.
- `lib/data/services/google_sheets_service.dart:2089` invokes `clientViaServiceAccount(...)`.
- `lib/presentation/screens/google_sheets_reports_screen.dart` exposes that service through an application screen.

**Impact**

A service-account credential shipped to a client can be extracted and reused. The Sheets operation cannot be safely exercised under the requirement that no service account be used in the application.

**Non-destructive reproduction**

1. Inspect the Flutter asset list in `pubspec.yaml`.
2. Inspect `_getSheetsApi` and the credential-loading code in `google_sheets_service.dart`.
3. Confirm that the loaded asset is passed to `clientViaServiceAccount`.

**Recommended fix**

Immediately revoke and rotate any credential ever packaged with the app. Remove the credential asset and client-side service-account flow. Put Sheets operations behind an authenticated server-side endpoint (for example, Cloud Functions) that checks the caller's identity and role. Add CI secret scanning and a build rule that rejects service-account JSON/assets.

### Medium — No safe, repeatable QA environment for report workflows

**Evidence**

- `lib/main.dart:28` initializes `AppFlavor.prod` unconditionally.
- No calls to `useAuthEmulator` or `useFirestoreEmulator` were found in `lib/`.
- `.env.example` defines production-oriented configuration but provides no QA test-user credentials or emulator endpoints.

**Impact**

The requested create, edit, delete, and synchronization tests cannot be run without a meaningful risk of changing production data. This also prevents repeatable visual regression evidence.

**Non-destructive reproduction**

1. Inspect `main.dart` and confirm production flavor selection before Firebase initialization.
2. Search `lib/` for Firebase emulator configuration.
3. Review `.env.example` for a disposable QA identity and emulator/project configuration.

**Recommended fix**

Add a `qa` flavor selected through `--dart-define`/flavor configuration. Route it to Firebase Auth and Firestore emulators or a separate QA project, seed short-lived role-specific accounts and synthetic reports, and document a clean Chrome-emulator launch command. Make the test suite reset only that isolated data set.

## Required inputs to complete runtime QA

1. A functioning current-source build for the Chrome emulator (or a current APK matched to this commit).
2. A working Chrome-emulator connection in the test environment.
3. A disposable QA account and isolated Firebase project/emulator configuration with seeded non-production data.
4. The roles to test, including whether administrator workflows are required.

With those inputs, the full workflow matrix can be executed and this report updated with screenshots and runtime reproduction evidence.
