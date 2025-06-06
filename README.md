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
  - `widgets/` - Reusable widgets 