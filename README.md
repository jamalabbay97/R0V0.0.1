# R0 App

A Flutter application for recording and reporting workflow reports, truck, heavy vehicle, and factory reports.

## Features

- Multilingual support (English and French)
- Report management (Create, Read, Update, Delete)
- Different report types (R0, Activity, Daily)
- Truck tracking
- Settings management

## Getting Started

1. Make sure you have Flutter installed on your machine
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

## Toolchain & Compatibility

- Flutter `3.32.0` (stable). The project includes a `.fvmrc` file to keep Flutter
  versions consistent across contributors.
- Dart SDK `>=3.0.0 <4.0.0` (as defined in `pubspec.yaml`).

Keeping the toolchain aligned prevents build failures and ensures consistent
behavior across environments.

## Data Flow & Persistence

- **provider** for state management.
- **sqflite** for local, offline-first persistence.
- **shared_preferences** for lightweight settings storage (e.g., locale).

This combination keeps state predictable, stores reports reliably, and avoids
data loss when offline.

## Scalable Backend (Firebase)

- Firestore security rules are defined in `firestore.rules`.
- Composite indexes are defined in `firestore.indexes.json` to support
  user-scoped report queries ordered by date.

These files are referenced from `firebase.json` and are required for safe,
scalable querying at large data volumes.

## Performance Optimization

- SQLite indexes are created for report lookup fields (type, date, group, and
  firestore ID).
- Report queries are ordered by date and can be fetched in pages.

This improves query efficiency and keeps the UI responsive for large datasets.

## Testing & CI

- A GitHub Actions workflow runs `flutter test` on every pull request and push.
- The local test suite includes model, service, provider, and widget coverage.

Automated checks prevent regressions and improve long-term stability.

## Publishing

- `web`: build with `flutter build web --release` and deploy with Firebase Hosting.
- `android`: build a release bundle with `flutter build appbundle --release`.
- `ios`: build an IPA with `flutter build ipa --release` (signing required for store upload).
- A manual GitHub Actions workflow at `.github/workflows/publish.yml` now automates web deployment plus Android and iOS release artifacts.
- Detailed release instructions and required secrets are documented in `docs/PUBLISHING.md`.

## Dependencies

- Flutter SDK
- provider: ^6.1.1
- sqflite: ^2.3.0
- intl: ^0.18.1
- google_maps_flutter: ^2.5.0
- shared_preferences: ^2.2.2
- flutter_map: ^6.1.0
- latlong2: ^0.9.0

## Project Structure

- `lib/`
  - `l10n/` - Localization files
  - `models/` - Data models
  - `providers/` - State management
  - `screens/` - App screens
  - `services/` - Business logic and services
  - `widgets/` - Reusable widgets # R0V.01
# R0V0.0.1
# R0V0.0.1