# Publishing R0 on Web, Android, and iOS

This project already includes Flutter targets for web, Android, and iOS. The steps below make releases repeatable both locally and in GitHub Actions.

## Prerequisites

- Flutter 3.32.0
- Firebase CLI for web deployment
- A Firebase project with Hosting enabled
- Google Play Console access for Android release uploads
- Apple Developer account plus signing certificates/profiles for iOS release uploads

## Required secrets for GitHub Actions

Add these repository secrets before running the publish workflow:

- `FIREBASE_SERVICE_ACCOUNT` — JSON service account key with access to Firebase Hosting
- Firebase client config values used as Flutter `--dart-define` inputs:
  `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`,
  `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_MEASUREMENT_ID`,
  `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`,
  `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`,
  `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`,
  `FIREBASE_IOS_BUNDLE_ID`, and `FIREBASE_MACOS_BUNDLE_ID`.
- Android signing secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`,
  `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`.

Do not publish `.env` or Google service-account JSON files as Flutter assets.
Google Sheets service-account credentials belong only in Cloud Functions or a
backend secret manager.

## Web publishing

### Local

```bash
flutter pub get
flutter build web --release \
  --dart-define=FIREBASE_WEB_API_KEY="$FIREBASE_WEB_API_KEY" \
  --dart-define=FIREBASE_WEB_APP_ID="$FIREBASE_WEB_APP_ID" \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_AUTH_DOMAIN" \
  --dart-define=FIREBASE_STORAGE_BUCKET="$FIREBASE_STORAGE_BUCKET" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define=FIREBASE_MEASUREMENT_ID="$FIREBASE_MEASUREMENT_ID"
firebase deploy --only hosting --project r0v01-5b577
```

The Firebase Hosting configuration serves `build/web` and rewrites all routes to `index.html` so Flutter navigation keeps working.

### GitHub Actions

Run the `Publish Flutter App` workflow with `deploy_web=true`. The workflow builds the web app and deploys it to Firebase Hosting.

## Android publishing

### Local

1. Create an upload keystore.
2. Add signing properties in `android/key.properties`.
3. Build the release bundle:

```bash
flutter pub get
flutter build appbundle --release
```

Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

### GitHub Actions

Run the `Publish Flutter App` workflow. It builds an Android App Bundle (`.aab`) and uploads it as a workflow artifact. You can attach Play Console publishing later once signing credentials and track preferences are available.

## iOS publishing

### Local

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Set your Apple Team, signing certificate, and provisioning profile.
3. Archive the app, then upload it through Xcode Organizer or Transporter.

For a CLI build:

```bash
flutter pub get
flutter build ipa --release
```

### GitHub Actions

The workflow runs on macOS and builds an unsigned iOS release artifact (`Runner.app`). You can sign and archive it in Xcode for App Store Connect submission.

## Important follow-up before store submission

The project still uses example bundle/package identifiers in the native project files and Firebase app configuration. Before shipping to the App Store or Play Store, replace those identifiers with your production values and regenerate Firebase configuration files so they match.
