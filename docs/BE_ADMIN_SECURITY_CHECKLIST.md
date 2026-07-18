# Backend checklist for multiple administrators

This checklist should be agreed with the backend team before FamilyCare expands
from one administrator account to multiple administrator accounts. Frontend
route guards are user experience controls, not a security boundary.

## Identity and provisioning

- Do not allow public registration to request `SYSTEM_ADMIN`.
- Provision the first super administrator through a controlled seed or
  deployment process.
- Allow only an authorized super administrator to invite, create, suspend, or
  change another administrator.
- Require unique named administrator accounts; do not share one credential.
- Prevent removal or demotion of the last active super administrator.

## Authorization

- Separate at least `SUPER_ADMIN` and `ADMIN`, or define equivalent granular
  permissions.
- Enforce authorization in every backend admin endpoint.
- Default to deny when a permission is absent.
- Do not trust a role or permission supplied by the frontend.
- Require re-authentication or MFA for destructive actions such as restore,
  role changes, account suspension, and subscription overrides.

## Sessions and credentials

- Use short-lived access tokens and rotating refresh tokens.
- Store refresh tokens in a Secure, HttpOnly, SameSite cookie for the web admin
  when the architecture permits it.
- Support viewing and revoking active sessions.
- Revoke all sessions after password reset, role change, or account suspension.
- Rate-limit login, OTP, password reset, and refresh endpoints.
- Add MFA for administrator accounts.

## Audit and monitoring

- Record actor ID, action, target, timestamp, result, request/correlation ID,
  and relevant before/after values.
- Record security events such as failed logins, role changes, session revokes,
  backups, restores, and sensitive exports.
- Protect audit logs from modification by ordinary administrators.
- Alert on repeated failures or unusual administrator activity.
- Never log passwords, OTPs, access tokens, refresh tokens, or private keys.

## Verification cases for FE/QA

- A normal user calling every `/admin` endpoint receives `403`.
- An unauthenticated request receives `401`.
- A suspended administrator cannot log in or refresh a session.
- Demoting or suspending an administrator invalidates existing sessions.
- An administrator cannot promote themselves without the required permission.
- Concurrent administrators produce separate audit actors.
- The last super administrator cannot be disabled or demoted.
