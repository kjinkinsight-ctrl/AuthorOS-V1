# Secrets Policy

## Rules
- Secrets never committed to source control.
- Local development uses untracked environment files.
- Production uses a managed secret store.
- Secret rotation is required for payment, session, and signing keys.

## Secret Classes
- payment provider keys and webhook secrets
- auth/session signing secrets
- database credentials
- email provider keys
- download artifact signing keys

## Controls
- CI blocks commits containing probable secrets.
- Runtime startup fails fast if required secrets are missing.
