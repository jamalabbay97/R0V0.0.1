# GitHub Secrets Setup Guide (8 Required Secrets)

Set these in **GitHub → Settings → Secrets and variables → Actions**.

1. `FIREBASE_PROJECT_ID` — Firebase project id.
2. `FIREBASE_CLIENT_EMAIL` — service account email.
3. `FIREBASE_PRIVATE_KEY` — service account private key (escaped newlines).
4. `FIREBASE_STORAGE_BUCKET` — Firebase storage bucket.
5. `ANDROID_KEYSTORE_BASE64` — base64-encoded signing keystore.
6. `ANDROID_KEY_ALIAS` — keystore alias.
7. `ANDROID_KEY_PASSWORD` — alias/key password.
8. `ANDROID_STORE_PASSWORD` — keystore password.

## Notes

- Never commit these values to Git.
- Rotate secrets after team member off-boarding.
- Prefer environment-scoped secrets for dev/staging/prod.