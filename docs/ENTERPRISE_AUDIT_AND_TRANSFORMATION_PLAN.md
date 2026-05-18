# R0 Enterprise Audit and Transformation Plan

Date: 2026-05-18

Scope: Flutter app for Android, iOS, and Web using Firebase Auth, Firestore, local SQLite/shared preferences, Google Sheets API, Provider state management, and Firebase Hosting/Functions.

Implementation note: The first remediation pass has removed `.env` and
`assets/credentials/**` from Flutter assets, disabled client-side Google
service-account credentials in release builds, added baseline Hosting security
headers, added CI secret scanning, hardened self-profile Firestore rules, and
added audit logging to the existing callable role/report functions. The Google
service-account key still must be revoked/rotated in Google Cloud if it was ever
committed or shipped.

## Executive Summary

The project has useful foundations: Flutter multi-platform scaffolding, Firebase Auth/Firestore, partial `core/data/domain/presentation` layering, Firestore rules, indexes, GitHub Actions, tests, localization, theming, and offline local storage. It is not yet production-ready for an enterprise employee platform.

The largest risks are security and scalability:

- A Google service account credential is present under `assets/credentials/` and is referenced as a Flutter app asset in `pubspec.yaml`. This must be treated as a credential leak because Flutter assets ship to clients.
- `.env` is also bundled as an app asset. This exposes runtime configuration and makes environment separation brittle.
- Google Sheets writes run from the Flutter client using service-account credentials. This sensitive workflow must move to Cloud Functions or a backend API.
- Client code writes directly to Firestore for role/access-related entities and report data. Rules reduce risk, but enterprise authorization must be enforced server-side with custom claims, App Check, audit logs, and immutable server validation.
- `reports_screen.dart` is about 619 KB and `google_sheets_service.dart` is about 122 KB. These are serious maintainability and performance anti-patterns.
- Sync is "best effort" but not a durable offline-first system. There is no explicit sync queue, retry policy, idempotency key, conflict model, or observable sync status.
- CI/CD exists but lacks full release signing, security scanning, coverage gates, environment promotion, integration tests, Firebase emulator tests, crash/monitoring setup, and guarded deploys.

Recommended target: Feature-first Clean Architecture with Riverpod, immutable models, repository/use-case boundaries, backend-mediated privileged operations, Firebase App Check, robust offline sync, enterprise design system, and hardened CI/CD.

## Current Project Snapshot

Observed structure:

```text
lib/
  core/
    config/
    utils/
  data/
    constants/
    repositories/
    services/
  domain/
    models/
    repositories/
    services/
  presentation/
    access_control/
    providers/
    routing/
    screens/
    widgets/
```

Key files:

- `lib/main.dart`: loads `.env`, initializes Firebase, injects Provider graph.
- `lib/data/services/google_sheets_service.dart`: very large client-side Google Sheets integration.
- `lib/data/services/firestore_service.dart`: report authorization mapping, Firestore reads/writes, pagination, stream queries.
- `lib/data/services/sync_service.dart`: local/cloud sync logic.
- `lib/data/services/database_helper.dart`: SQLite plus web `SharedPreferences` fallback.
- `firestore.rules`: role/report access checks.
- `firebase_functions_index.ts`: initial callable functions, not fully wired into Flutter.
- `.github/workflows/`: basic CI/build/deploy.
- `web/index.html` and `web/manifest.json`: baseline web/PWA metadata.

## Priority Matrix

| Priority | Item | Risk | Recommended action |
| --- | --- | --- | --- |
| P0 | Service account JSON shipped in assets | Critical credential compromise | Remove from assets, revoke/rotate key, purge git history if committed, move Sheets calls to backend |
| P0 | `.env` shipped in assets | Config/secret exposure and environment drift | Remove `.env` from assets, use `--dart-define-from-file` or CI injected config |
| P0 | Client-side privileged Google Sheets API | Unauthorized data writes and leaked credentials | Cloud Functions callable/HTTPS endpoint with App Check and role validation |
| P0 | Release Android signed with debug config | Production integrity failure | Add release keystore handling, Play App Signing, CI secrets |
| P1 | Direct Firestore client writes for sensitive data | Authorization bypass risk if rules drift | Backend-mediated writes for roles, user admin, Sheets status, audit events |
| P1 | Huge screen/service files | Team velocity and defect risk | Feature-first split into controllers, widgets, use cases, data sources |
| P1 | Firestore list queries fetching whole archive | Cost/performance risk at scale | Cursor pagination, composite indexes, denormalized access fields |
| P1 | Offline sync without queue/conflicts | Data loss/duplication risk | Durable sync queue, idempotency, retry/backoff, conflict policies |
| P2 | Provider/global `ChangeNotifier` graph | Rebuild storms and poor isolation | Migrate feature-by-feature to Riverpod Notifier/AsyncNotifier |
| P2 | Limited observability | Slow incident response | Crashlytics, Sentry, Analytics, structured remote logs |
| P2 | Basic CI only | Release quality risk | Analyze/test/build/security/emulator/release pipelines |
| P3 | Design system partial only | UI inconsistency | Tokenized components, accessibility, skeletons, responsive web layouts |

## Security Vulnerability Report

### Critical Findings

1. Service account credential is included in app assets.
   - `pubspec.yaml` includes `assets/credentials/r0v01-5b577-67d9e9bae92b.json`.
   - The file exists and contains `type: service_account`, `private_key_id`, and `client_email`.
   - `GoogleSheetsService` loads this asset through `rootBundle.loadString`.
   - Impact: anyone with the app/web bundle can extract the private key and write to Google Sheets or any IAM-permitted Google resource.
   - Required fix: immediately revoke and rotate the service account key, remove the file from repository and release artifacts, and migrate Sheets operations to Cloud Functions.

2. `.env` is bundled into the Flutter application.
   - `pubspec.yaml` includes `.env`.
   - `main.dart` loads `.env` at runtime with `flutter_dotenv`.
   - Impact: web users and mobile reverse engineers can inspect values. Firebase API keys are not secret by themselves, but bundling operational config trains the project toward leaking real secrets.
   - Required fix: remove `.env` from assets, use flavor-specific generated config or `--dart-define-from-file`, and never include secrets in client bundles.

3. Client-side Google Sheets write path.
   - `GoogleSheetsService` uses `googleapis_auth` service account client in Flutter.
   - Impact: privileged data export/write logic cannot be trusted on employee devices or browsers.
   - Required fix: implement `submitReportToSheets` Cloud Function. Client sends report ID/action, server validates role/access, reads canonical report, writes to Sheets, marks `sheetsSynced`, and writes an audit event.

### High Findings

4. Firestore authorization depends heavily on mutable user documents.
   - Rules call `get(/users/{uid})` for role and `allowedReports`.
   - Client `RoleProvider` writes/merges its own user document metadata on sign-in.
   - Recommendation: store stable authorization in Firebase custom claims and mirror read-friendly profile fields in Firestore. Only backend/admin functions may mutate role/access fields.

5. Admin/user management appears partially client-driven.
   - `admin_users_screen.dart` streams `users` and `report_definitions` directly.
   - Recommendation: admin UI should call backend functions for create/update/deactivate/reset flows. Every action must emit audit logs with actor UID, target UID, previous values, new values, IP/user agent where available, and request ID.

6. Missing App Check enforcement.
   - Add Firebase App Check for Android Play Integrity, iOS DeviceCheck/App Attest, and Web reCAPTCHA Enterprise.
   - Enforce App Check on Firestore, Functions, and Hosting/API endpoints after rollout.

7. No certificate pinning or network boundary.
   - Firebase SDK traffic does not support normal app-level pinning in a simple way.
   - For custom enterprise APIs, use `dio` + pinned cert/SPKI via `http_certificate_pinning` or platform network security config. Use short rotation windows and backup pins.

8. No explicit MFA policy.
   - Require MFA for admins/managers, at least SMS/TOTP depending on identity provider. Prefer enterprise SSO/SAML/OIDC with conditional access when available.

9. No root/jailbreak/tamper controls.
   - Add root/jailbreak detection as a risk signal, not sole authorization.
   - Use Play Integrity/App Attest/App Check, obfuscation, split debug/prod Firebase projects, and server-side enforcement.

### Medium Findings

10. Android package namespace is `com.example.R0`.
    - Replace with enterprise-owned reverse domain, e.g. `com.company.r0`.

11. Android release uses debug signing.
    - `android/app/build.gradle.kts` release `signingConfig` uses debug.
    - Add secure keystore loading from CI secrets and Play App Signing.

12. Broad Android permissions.
    - Camera, location, and media permissions exist. Validate each platform feature genuinely needs them. Request runtime permission only at point of use.

13. Debug logging and `print`.
    - Remove `print` from `reports_screen.dart`; route logs through a redacting logger.

## Architecture Audit

### Current State

Strengths:

- A basic layered folder layout exists.
- `ReportRepository` abstraction exists.
- Some domain services are pure enough to unit test.
- Localization and theme files exist.

Anti-patterns:

- Feature code is centralized by technical layer instead of feature ownership.
- `data/services` classes own too much: persistence, backend, mapping, auth checks, and sync side effects.
- Presentation screens contain business rules, form data shaping, persistence triggers, and large UI trees.
- `reports_screen.dart` is far beyond maintainable size and likely includes multiple report workflows in one file.
- `google_sheets_service.dart` is a backend integration masquerading as client code.
- The domain model `Report` knows persistence details (`toMap`, SQLite column names, JSON encoding). Domain should be storage-agnostic.
- Dependency injection is ad hoc in `main.dart`; many services instantiate Firebase singletons internally.

### Target Architecture

Adopt Feature-First Clean Architecture:

```text
lib/
  app/
    bootstrap/
    config/
    routing/
    observers/
  core/
    auth/
    errors/
    logging/
    networking/
    security/
    storage/
    sync/
    theme/
    widgets/
  features/
    auth/
      data/
        datasources/
        dto/
        repositories/
      domain/
        entities/
        repositories/
        usecases/
      presentation/
        controllers/
        screens/
        widgets/
    reports/
      data/
      domain/
      presentation/
    report_forms/
      activity/
      daily/
      r0/
      truck_tracking/
      machines_stopped/
    admin/
    sheets_archive/
    settings/
    dashboard/
  l10n/
```

Rules:

- Domain has entities, value objects, repository contracts, and use cases. No Firebase, SQLite, Flutter widgets, or JSON column names.
- Data has DTOs, Firebase data sources, local data sources, mappers, and repository implementations.
- Presentation has screens, small widgets, controllers/notifiers, view models, and UI-only state.
- `core` contains cross-cutting utilities only, not feature business logic.

Example use-case boundary:

```dart
class SubmitReportUseCase {
  SubmitReportUseCase(this._repository, this._auditLogger);

  final ReportRepository _repository;
  final AuditLogger _auditLogger;

  Future<Result<ReportId>> call(SubmitReportCommand command) async {
    final report = command.toDraft().validateOrThrow();
    final id = await _repository.saveDraft(report);
    await _auditLogger.record('report.saved', subjectId: id.value);
    return Result.ok(id);
  }
}
```

## State Management Plan

Current state management uses Provider/ChangeNotifier. It is acceptable for small apps but weak for an enterprise app with many independent flows and offline state.

Recommended migration: Riverpod 3 with generated providers.

Why Riverpod:

- Provider dependency graph is explicit and testable.
- `AsyncNotifier` models loading/error/data cleanly.
- `select` reduces rebuilds.
- Provider overrides make Firebase/local repository tests easier.
- Feature-level provider files pair well with Clean Architecture.

Migration strategy:

1. Add Riverpod alongside Provider.
2. Convert infrastructure providers first: auth repository, report repository, app config, logger.
3. Convert one feature screen at a time from `ChangeNotifier`/`setState` to `Notifier` or `AsyncNotifier`.
4. Use `ConsumerWidget`/`ConsumerStatefulWidget`; keep local ephemeral input state local.
5. Use immutable state classes with Freezed.
6. Use `ref.watch(provider.select(...))` for leaf widgets.
7. Delete old Provider graph when converted.

Example:

```dart
@riverpod
class ReportListController extends _$ReportListController {
  @override
  Future<ReportListState> build() async {
    final repo = ref.watch(reportRepositoryProvider);
    final page = await repo.fetchReportsPage(limit: 50);
    return ReportListState.initial(page);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    final repo = ref.read(reportRepositoryProvider);
    final next = await repo.fetchReportsPage(cursor: current.nextCursor);
    state = AsyncData(current.append(next));
  }
}
```

Rebuild prevention:

- Split screens into small widgets.
- Use const constructors.
- Use Slivers/ListView.builder for long lists.
- Avoid passing entire provider objects to large widget subtrees.
- Use `select` for `themeMode`, `locale`, role flags, and counters.
- Move derived filtering/sorting into memoized providers.

## Firebase and Backend Redesign

### Current Risks

- FirestoreService fetches entire reports collection for archive scenarios.
- Client filters some documents after query instead of using queryable access fields.
- Sensitive actions are not consistently backend-mediated.
- Functions exist, but Flutter still directly uses Firestore and Sheets for major workflows.

### Target Backend

Use Firebase Functions or Cloud Run as the trusted boundary:

```text
Flutter app
  -> Firebase Auth + App Check
  -> Callable/HTTPS Functions
       -> Firestore Admin SDK
       -> Google Sheets API
       -> Audit logs
       -> Cloud Tasks for long-running sync/export
```

Backend functions to implement:

- `createReport`
- `updateReport`
- `deleteReport`
- `submitReportToSheets`
- `listReportsPage`
- `listArchiveReportsPage`
- `setUserRole`
- `setUserReportAccess`
- `deactivateUser`
- `createUserInvitation`
- `recordAuditEvent`

Firestore structure:

```text
users/{uid}
  profile fields only: email, displayName, status, createdAt, updatedAt

user_private/{uid}
  preferences, device metadata, lastSeenAt

roles/{uid}
  role, allowedReports, updatedBy, updatedAt
  write: backend only

reports/{reportId}
  ownerUid
  reportTypeKey
  reportDate
  shiftGroup
  status
  accessKeys[]
  sheetsSynced
  createdAt
  updatedAt
  schemaVersion

reports/{reportId}/versions/{versionId}
  immutable report snapshot

sync_queue/{operationId}
  uid, entityType, entityId, operation, payloadHash, status, attempts

audit_logs/{eventId}
  actorUid, action, entityType, entityId, before, after, result, createdAt
```

Query/index strategy:

- Personal reports: `ownerUid == uid`, `reportDate desc`, `createdAt desc`.
- Archive reports: `accessKeys array-contains key`, `reportDate desc`.
- Sheets-synced reports: `sheetsSynced == true`, `reportDate desc`.
- Admin reports: `reportTypeKey == key`, `reportDate desc`, optional status.
- Dashboard: pre-aggregate monthly counters in `report_metrics/{yyyyMM}` via Functions.

Avoid:

- Unbounded `.get()` on `reports`.
- Client-side filtering for access control.
- Large nested `additionalData` blobs when fields must be queried.

Pagination:

- Use cursor-based pagination with `startAfterDocument` or opaque backend cursors.
- Default page size 25-50.
- For archive searches, use Algolia/Typesense/Firestore vector/search proxy if full-text search becomes needed.

## Offline-First System

Current state:

- SQLite on mobile/desktop.
- Web uses SharedPreferences/local storage fallback and memory fallback.
- Sync attempts are immediate and best-effort.
- Conflict handling is implicit: cloud often replaces local.

Target:

```text
Local database
  reports
  report_drafts
  sync_operations
  entity_versions
  tombstones

Sync engine
  watches connectivity/auth
  drains queue
  retries with exponential backoff
  uses idempotency keys
  records per-operation status
  reports conflicts to UI
```

Use Drift instead of raw sqflite for typed queries, migrations, web support through WASM/IndexedDB, and tests.

Sync operation example:

```dart
class SyncOperation {
  final String idempotencyKey;
  final String entityId;
  final SyncOperationType type;
  final Map<String, Object?> payload;
  final int attempts;
  final DateTime nextAttemptAt;
}
```

Conflict strategy:

- Server owns canonical `updatedAt`, `updatedBy`, `version`.
- Client sends `baseVersion`.
- If base version is stale, backend returns conflict with server/current values.
- Simple report drafts: last-write-wins only for non-critical fields.
- Operational reports submitted to Sheets: immutable after submission except by admin correction workflow.
- Admin corrections require reason and audit log.

Retry:

- Exponential backoff with jitter.
- Do not retry validation/permission failures.
- Retry network, 429, 5xx.
- Use Cloud Tasks for backend-to-Sheets retries.

## Performance Report

Findings:

- Very large screens cause slow analysis, slow rebuilds, merge conflicts, and high memory pressure.
- `reports_screen.dart` contains many `setState` calls and nested scrollables.
- Firestore archive reads can fetch too much data.
- Google Sheets service performs many serial API calls from client.
- Web persistence uses SharedPreferences, which is not ideal for larger offline datasets.
- `flutter analyze` and `flutter test` timed out at 120 seconds during this audit run, which is itself a productivity signal.

Optimization plan:

- Split large screens by feature and step.
- Use `ListView.builder`, `SliverList`, and pagination everywhere reports are listed.
- Use Riverpod selectors and immutable state.
- Move heavy formatting/export work to isolates or backend.
- Cache report definitions and role/access data.
- Add lazy route loading and deferred imports for heavy report form modules on web.
- Use `flutter build web --wasm` only after dependency validation; otherwise tune CanvasKit vs HTML renderer based on app visuals and enterprise browser support.
- Add performance traces around startup, login, report list load, report save, sync, and Sheets submit.

Startup:

- Initialize Firebase and app config only.
- Defer sync until after first frame.
- Lazy-load report definitions and archive data.
- Avoid full sync on every `getReports()`; trigger sync by explicit policy.

## Web Enterprise Readiness

Current:

- Basic manifest and index metadata exist.
- Firebase Hosting rewrites are configured.
- No visible security headers in `firebase.json`.
- No custom service worker strategy beyond Flutter defaults.

Required:

- Add Firebase Hosting headers:
  - `Strict-Transport-Security`
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy`
  - `Permissions-Policy`
  - `Content-Security-Policy` tailored for Firebase, Google APIs, Maps, and Sentry.
- Enable App Check for web with reCAPTCHA Enterprise.
- Configure long-lived caching for hashed Flutter assets and no-cache for `index.html`.
- Use CDN via Firebase Hosting or Cloudflare in front, with WAF rules and bot protection where appropriate.
- Add PWA install QA, offline fallback, and update prompt.
- SEO: Flutter web is not SEO-friendly for private enterprise apps. For public marketing/docs, create a separate static site. For app shell, use metadata and auth-gated routes only.

Example Firebase Hosting headers:

```json
{
  "source": "**/*.@(js|css|png|jpg|webp|wasm)",
  "headers": [{ "key": "Cache-Control", "value": "public,max-age=31536000,immutable" }]
}
```

## DevOps and CI/CD

Current:

- CI runs `flutter test`.
- Another workflow runs analyze/test and builds Android APK/Web.
- Publish workflow builds web, Android AAB, and iOS no-codesign.

Target GitHub Actions pipeline:

1. Pull request:
   - `flutter pub get`
   - `dart format --set-exit-if-changed`
   - `flutter analyze --fatal-infos`
   - `flutter test --coverage`
   - Firebase emulator rules tests
   - secret scan with gitleaks
   - dependency audit
   - build web smoke artifact

2. Main branch:
   - all PR checks
   - Android debug/staging build
   - Web staging deploy to preview channel
   - integration test against emulator/staging

3. Release tag:
   - Android AAB signed
   - iOS archive signed via Fastlane match/App Store Connect API key
   - Web production deploy
   - Crashlytics symbol upload
   - Sentry source map/dSYM/proguard upload
   - GitHub release notes

Recommended stack:

- GitHub Actions for PR checks and release gates.
- Fastlane for Android/iOS signing, TestFlight, Play internal/closed tracks.
- Codemagic optional for managed Apple signing and Flutter release convenience.
- Firebase App Distribution for internal Android/iOS QA.
- Firebase Hosting preview channels for web PRs.
- GitHub environments: dev, staging, prod with required reviewers.
- Secrets: GitHub environment secrets or GCP Secret Manager; never client assets.

Android release:

- Replace debug signing with release signing config.
- Enable R8/proguard and resource shrinking.
- Add `--obfuscate --split-debug-info=build/symbols`.
- Play Integrity API through App Check.

iOS release:

- Bundle ID under company domain.
- TestFlight groups: internal QA, pilot employees, production.
- App Attest/DeviceCheck through App Check.
- dSYM upload to Crashlytics/Sentry.

## Error Handling and Monitoring

Add:

- Firebase Crashlytics for mobile crashes.
- Sentry for Flutter errors across mobile/web plus performance traces.
- Firebase Analytics or enterprise analytics policy-approved alternative.
- Structured logging with redaction.
- Remote audit logs for sensitive actions.
- Session tracking: UID, role, app version, device info, platform, environment, but never passwords or report secrets.

Error architecture:

```dart
sealed class AppFailure {
  const AppFailure();
}

class NetworkFailure extends AppFailure {}
class PermissionFailure extends AppFailure {}
class ValidationFailure extends AppFailure {
  const ValidationFailure(this.message);
  final String message;
}
```

Use repositories to map Firebase/HTTP exceptions into domain failures. UI displays localized messages and logs structured diagnostics.

## UI/UX System

Current:

- Theme exists with colors and typography.
- Some reusable widgets exist.
- Large forms are screen-local and repetitive.

Target:

- Design tokens: colors, typography, spacing, radius, elevation, motion.
- Component library:
  - `AppButton`, `AppTextField`, `AppDropdown`, `AppDateTimeField`
  - `ReportCard`, `StatusChip`, `EmptyState`, `ErrorState`
  - `SkeletonList`, `AppDataTable`, `AuditTimeline`
- Accessibility:
  - semantic labels
  - min tap target 48dp
  - contrast AA
  - keyboard traversal for web
  - screen reader labels for forms
- Enterprise web:
  - responsive navigation rail/sidebar
  - dense report tables with filtering
  - saved filters
  - export actions
  - role-aware admin console
- Dark mode:
  - keep but validate contrast.
  - avoid hard-coded colors inside feature widgets.

## Team Scalability

Add:

- Stronger `analysis_options.yaml`, preferably `very_good_analysis` or strict custom lint set.
- Architecture decision records in `docs/adr/`.
- Pull request template and issue templates.
- CODEOWNERS by feature.
- Feature README files for complex domains.
- Conventional commits or release note automation.
- Branch/environment strategy.
- Dependency update policy.
- Secret scanning pre-commit and CI.

Architecture rules:

- Presentation cannot import data sources directly.
- Domain cannot import Flutter/Firebase.
- Features cannot import sibling feature internals; use public contracts.
- Backend-only operations cannot be implemented in Flutter.

## Testing Strategy

Current tests exist for models/services/providers/widgets, but enterprise coverage is incomplete.

Add:

- Unit tests for domain use cases and validators.
- Repository tests with fake local/remote data sources.
- Firebase emulator tests for Firestore rules and Functions.
- Widget tests for forms, access-controlled menus, error states, loading/skeleton states.
- Golden tests for design system components.
- Integration tests for login, create report, offline save, sync, submit to Sheets, admin role changes.
- Contract tests for backend callable functions.

Coverage gates:

- Initial gate: 50% line coverage on changed code.
- Target: 70% overall, 85% domain/use-case packages.
- Mandatory tests for every Firestore rule change.

## Suggested Packages

Architecture/state:

- `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`
- `freezed`, `freezed_annotation`, `json_serializable`
- `go_router`
- `equatable` only if not using Freezed for state

Data/offline:

- `drift`, `drift_flutter`, `sqlite3_flutter_libs`
- `connectivity_plus`
- `dio`, `retrofit` if custom APIs are added

Security:

- `firebase_app_check`
- `flutter_secure_storage`
- `local_auth`
- `safe_device` or equivalent root/jailbreak signal package
- `jwt_decoder` only for non-sensitive display/expiry checks; never trust client-decoded claims for authorization

Monitoring:

- `firebase_crashlytics`
- `firebase_analytics`
- `sentry_flutter`
- `logging`

Testing:

- `mocktail`
- `fake_cloud_firestore`
- `firebase_auth_mocks`
- `patrol` or `integration_test`
- `golden_toolkit`

Quality:

- `very_good_analysis`
- `custom_lint`, `riverpod_lint`

## Migration Plan

### Phase 0: Incident Response and Stabilization (0-3 days)

- Revoke and rotate Google service account key.
- Remove `assets/credentials/**` from app assets and repo.
- Remove `.env` from app assets.
- Add gitleaks and block future secret commits.
- Disable client-side Google Sheets submission in production until backend endpoint exists.
- Fix Android release signing; stop using debug signing for release.

### Phase 1: Backend Security Boundary (1-2 weeks)

- Implement Functions for Sheets submission and report mutation.
- Enforce App Check in monitor mode, then strict mode.
- Move role/access writes to Functions.
- Add audit logs.
- Update Firestore rules to backend-first minimal access.
- Add Firebase emulator tests for rules/functions.

### Phase 2: Architecture Foundation (2-4 weeks)

- Introduce feature-first folder layout.
- Add Riverpod and DI providers.
- Extract report domain entities, DTOs, and mappers.
- Split `reports_screen.dart` into feature modules.
- Split `google_sheets_service.dart`; backend logic moves out, client keeps only API wrapper.
- Add `go_router` with guarded routes.

### Phase 3: Offline Sync (3-6 weeks)

- Replace raw sqflite/shared preferences with Drift.
- Add durable sync queue and status UI.
- Add conflict model and idempotency.
- Add background/foreground sync policy.
- Add integration tests for offline create/update/delete.

### Phase 4: Enterprise UX and Web (2-5 weeks)

- Build design system package/folder.
- Add responsive web shell.
- Add skeleton loaders and consistent error states.
- Add accessibility audit and fixes.
- Add Firebase Hosting headers and caching policy.
- Add PWA update flow.

### Phase 5: Production CI/CD and Observability (2-4 weeks)

- Add full PR quality gates.
- Add Fastlane for Android/iOS.
- Add TestFlight and Play internal deployment.
- Add Crashlytics, Sentry, Analytics, and structured logs.
- Add symbol/source map upload.
- Add release checklist and rollback strategy.

## Production Roadmap

Minimum production readiness:

- No bundled secrets or service account credentials.
- Backend-mediated privileged operations.
- App Check enforced.
- Firestore rules covered by tests.
- Release signing configured.
- Crash/analytics/logging enabled.
- CI gates pass under 10-15 minutes.
- At least smoke integration tests for core workflows.
- Environment separation: dev/staging/prod Firebase projects.
- Documented rollback and incident response.

Enterprise maturity:

- SSO/MFA.
- Device posture/risk signals.
- Audit logs and admin reporting.
- Data retention and deletion policy.
- Role/access review workflow.
- Load and cost tests for Firestore/Functions.
- Accessibility certification pass.
- Disaster recovery plan and backups.

## Technical Debt Analysis

Highest debt:

- Monolithic report screen and Google Sheets service.
- Domain model coupled to SQLite.
- Client-side privileged integrations.
- Mutable authorization metadata in Firestore.
- Encoding/mojibake in strings and rules (`Arr锚t茅s`, `3猫me`, etc.), indicating character-set corruption that can break matching and localization.
- Tests and analysis are too slow or blocked in current local audit run.

Refactoring order:

1. Security boundary.
2. Feature extraction for report workflows.
3. Domain/data separation.
4. State migration.
5. Offline sync rewrite.
6. UI system polish.

## Acceptance Criteria

The app can be considered enterprise-ready when:

- A clean build artifact contains no service-account JSON, `.env`, private keys, or privileged credentials.
- Firestore and Functions reject unauthorized role/report mutations in emulator tests.
- All sensitive actions are audited.
- Reports paginate consistently at 100k+ documents.
- Offline creates/updates/deletes survive app restarts and sync without duplicates.
- Flutter analyze/test/build pipelines pass on PR.
- Android/iOS/Web releases are signed, monitored, and deployable through controlled environments.
- New features can be added inside `features/{feature}` without touching global screens or shared services except explicit contracts.
