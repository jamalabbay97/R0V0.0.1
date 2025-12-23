**Purpose**
- **Goal:** Give AI coding agents immediate, actionable context for working in this Flutter app.

**Big Picture**
- **App type:** Flutter mobile app (Android/iOS/web) with offline-first data, local SQLite + Firestore sync. See `lib/main.dart` for initialization.
- **Core responsibilities:**
  - UI: `lib/screens/` and `lib/widgets/`
  - State: `lib/providers/` (uses `provider` package)
  - Persistence: local SQLite via `lib/services/database_helper.dart`
  - Cloud sync: `lib/services/firestore_service.dart` + `lib/services/sync_service.dart`
  - Auth: `lib/services/auth_service.dart`

**Key files to read first**
- `lib/main.dart` — Firebase init, orientation, root `ChangeNotifierProvider` for language.
- `lib/services/database_helper.dart` — local DB schema and migration (version = 2). Important: contains `reports` table and `firestore_id` handling.
- `lib/services/firestore_service.dart` — Firestore CRUD, offline persistence settings, batch upload logic.
- `lib/services/sync_service.dart` — offline-first sync strategies (upload unsynced local rows, download cloud rows, conflict handling is simplistic: cloud wins).
- `lib/models/report.dart` — canonical data model and `toMap`/`fromMap` conventions (note field names used in SQLite vs Firestore).
- `lib/providers/language_provider.dart` — shared preferences usage pattern for simple providers.
- `pubspec.yaml` / `README.md` — dependency list and quick-start commands.

**Project-specific patterns & conventions**
- Offline-first: save locally first, then try to upload. See `SyncService.saveReport()` for exact flow.
- Local-to-cloud linking: local rows keep a `firestore_id` string; sync updates the local row with the remote id. See `DatabaseHelper` and `Report.copyWith()` usage in `sync_service.dart`.
- DB schema naming: SQLite uses snake_case column names (e.g. `group_name`, `firestore_id`) while Firestore fields use camelCase/explicit keys (see `_reportToFirestore`). Keep conversions in model/service layer.
- Error handling: services throw Exceptions with user-facing messages in `AuthService` and generic wrapping in Firestore/Sync; debug logs use `kDebugMode`/`debugPrint`.
- Providers: lightweight `ChangeNotifier` implementations (e.g., `LanguageProvider`). Use `Provider`/`Consumer` in widgets as in `main.dart`.

**Developer workflows (commands & tips)**
- Get dependencies: `flutter pub get`
- Run app (debug): `flutter run` or select device in IDE.
- Build Android APK: `flutter build apk` (or use `./gradlew` in `android/` for custom gradle tasks).
- Run unit/widget tests: `flutter test`
- Integration tests: check `integration_test/` — run via `flutter drive` or `flutter test integration_test` as configured.
- If modifying Firebase config: update `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` and regenerate `firebase_options.dart` (the file is present at `lib/firebase_options.dart`).

**Integration points & external deps**
- Firebase (Auth + Firestore): initialization in `lib/main.dart` uses `lib/firebase_options.dart`.
- Local DB: `sqflite` with DB path from `getDatabasesPath()`; schema versioning is in `DatabaseHelper._initDatabase()`.
- Maps: `google_maps_flutter` and `flutter_map` are included — check `pubspec.yaml` if touching map code.
- Shared preferences: `LanguageProvider` persists locale with `SharedPreferences`.

**When editing models or DB schema**
- Always increment the DB `version` in `database_helper.dart` and add migration logic inside `_onUpgrade` to avoid data loss. The repo already has a migration from version 1 → 2 that adds `firestore_id`.
- Keep `Report.toMap()`/`fromMap()` and Firestore mapping (`_reportToFirestore`) in sync: field names differ between SQLite (snake_case) and Firestore (camelCase/local keys).

**Common tasks — concrete examples**
- Add a new report type: (1) update any UI dropdown in `lib/screens/*`, (2) ensure `Report.type` consumers handle it, (3) no DB change required if only values differ.
- Add a new column to `reports`: (1) add field in `Report`, (2) update `toMap()`/`fromMap()` and Firestore mapping, (3) increment DB version and add `ALTER TABLE` in `_onUpgrade`.
- Force a manual sync (for testing): invoke `SyncService().performFullSync()` from a debug button or from a test harness (remember `AuthService` must be authenticated for sync to run).

**Testing & debugging tips**
- Use `kDebugMode` logs in services — many services already guard prints with `kDebugMode`. Attach device logs (`flutter run` or `adb logcat`) when debugging native behaviors.
- When debugging auth/Firestore flows, confirm current user via `AuthService.currentUser` and inspect Firestore using Firebase console.

**What NOT to change lightly**
- `lib/firebase_options.dart` without regenerating from Firebase CLI — mismatched options break initialization.
- DB versioning and migration logic — incorrect migrations can corrupt local data.

If anything here is unclear or you want examples expanded (e.g., snippets for adding a DB migration or a sample unit test for `SyncService`), tell me which section to expand.
