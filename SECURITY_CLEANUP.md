# Security Cleanup Guide (Git History + Runtime Hardening)

This repository now follows a **keyless-by-default** workflow:

- No static secrets are committed to source control.
- Firebase credentials are managed via CI/CD secrets.
- Cloud Functions and Firestore rules enforce role-based access.

## 1) Remove accidental keys from Git history

If secrets were previously committed, use one of these tools:

### Option A — BFG Repo-Cleaner

```bash
java -jar bfg.jar --replace-text passwords.txt
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force
```

Where `passwords.txt` contains patterns to scrub.

### Option B — git filter-repo

```bash
pip install git-filter-repo
git filter-repo --path-glob '*.json' --invert-paths
git push --force
```

## 2) Rotate compromised credentials

After rewriting history, rotate all credentials that might have leaked:

- Firebase service account keys
- Google Sheets service account keys
- GitHub tokens
- API keys for external services
- Android/iOS signing keys if they were ever committed

## 2.1) Current hardening status

- `.env` is no longer declared as a Flutter asset. Production config should be
  injected with `--dart-define` or CI environment-specific build settings.
- `assets/credentials/**` is ignored and no longer declared in `pubspec.yaml`.
- Google Sheets service-account credentials are disabled in Flutter release
  builds. Privileged Sheets submission must run through Cloud Functions or a
  backend API.
- Firebase Hosting now sends baseline security and caching headers.
- CI includes a gitleaks secret-scan gate.

If a service-account JSON was ever committed or included in a distributed app
bundle, revoke that key in Google Cloud IAM immediately and create a new key
only for server-side use.

## 3) Validate repository protection

- `.gitignore` blocks typical secret files.
- CI uses GitHub Actions secrets.
- Firestore rules enforce role-scoped access.

## 4) Ongoing operational controls

- Enforce least privilege on Firebase IAM.
- Prefer workload identity / OIDC over long-lived keys where possible.
- Add pre-commit secret scanning (for example: gitleaks, trufflehog).
- Keep service account JSON in GitHub Actions secrets or Google Cloud Secret
  Manager only.
