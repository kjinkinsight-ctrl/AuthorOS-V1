# Security Baseline

## Non-Negotiables
- No secrets in frontend bundles.
- Payment success is trusted only from backend provider webhook verification.
- License issuance and status transitions are backend-only.
- Role checks enforced server-side for all admin APIs.

## Baseline Controls
- HttpOnly, Secure, SameSite cookies for web sessions.
- CSRF protection for cookie-authenticated state-changing endpoints.
- Strict input validation at API boundaries.
- Output encoding and sanitization for user-generated content.
- Rate limits for auth, checkout, password recovery, and support intake.
- Audit logs for admin actions and license/order state changes.
- Secret management via deployment environment or secret manager.

## Data Protection
- Password hashing with modern KDF via identity provider or managed auth.
- PII minimization and retention policy per domain.
- Signed download URLs with expiry for entitled artifacts.
