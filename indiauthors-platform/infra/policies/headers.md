# HTTP Security Header Baseline

Apply on all web responses unless endpoint-specific exceptions apply:

- Strict-Transport-Security
- X-Content-Type-Options
- Referrer-Policy
- Permissions-Policy
- X-Frame-Options
- Content-Security-Policy (nonce/hash-based where scripts are needed)

## Cookie Baseline
- Secure=true
- HttpOnly=true
- SameSite=Lax (or Strict where feasible)
- Explicit max-age and rotation policy
