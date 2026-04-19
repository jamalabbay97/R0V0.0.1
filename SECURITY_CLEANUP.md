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
- GitHub tokens
- API keys for external services

## 3) Validate repository protection

- `.gitignore` blocks typical secret files.
- CI uses GitHub Actions secrets.
- Firestore rules enforce role-scoped access.

## 4) Ongoing operational controls

- Enforce least privilege on Firebase IAM.
- Prefer workload identity / OIDC over long-lived keys where possible.
- Add pre-commit secret scanning (for example: gitleaks, trufflehog).