# RightApply Desktop (Windows) + AWS Backend

This repository contains a Windows-first Flutter desktop app and a cost‑optimized AWS backend (API Gateway HTTP API v2 + Lambda + DynamoDB) for device‑gated authentication.

Highlights:
- Device first: access is gated by device approval (MAC allowlisting/approval).
- Simple login: any user can log in when the device is approved (your chosen policy).
- Clear UX: login page shows status chips for “Device approved” and “Linked to this user”.

## Quick Start (Windows, cmd.exe)

1) Deploy backend (first time):
```
cd infra
sam build
sam deploy --guided
```
- Choose a stack name (e.g., `rightapply-backend`).
- After deploy, copy the `ApiUrl` output (looks like `https://xxxx.execute-api.us-east-1.amazonaws.com/Prod`).

2) Run the desktop app pointing to your API:
```
set API_BASE=https://<your-api-id>.execute-api.<region>.amazonaws.com/Prod
scripts\run-aws.cmd
```

The script cleans, fetches pub packages, builds a Windows release, and launches `build\windows\x64\runner\Release\rightapply.exe`.

## Authentication & Device Mapping

Tables:
- `USERS_TABLE` (PK: `username`): `name`, `passwordHash` (bcrypt), `role`, `createdAt`.
- `DEVICES_TABLE` (PK: `id`, GSIs: `mac-index`, `status-index`): `mac`, `status`, `approved`, `username` (when bound), timestamps, `ttl`.
- `ALLOWLIST_TABLE` (PK: `mac`): pre-approved devices.

Flow:
- Login (`POST /auth/login`): checks credentials and, if `mac` provided, requires device to be approved (allowlist or an approved device record). Issues JWT (8h). Binds the most recent device record for this `mac` to the user (`username` + `lastLoginAt`).
- Prefill (`GET /auth/linked?mac=`): returns the most recently bound user for this MAC for convenience on the login screen.
- User lookup (`GET /auth/user/:username?mac=`): returns `{ user, allowed, bound }` where `bound` is true when the most recent bound device for this MAC has the same `username`.

Admin endpoints (JWT required):
- `GET /device/pending` — list pending device requests.
- `POST /device/decide` — approve/deny a request.

Device registration:
- `POST /device/register` — creates a device record; auto‑approves if `mac` is allowlisted, else `pending`.
- `GET /device/status/:idOrMac` — returns status; also treats the param as `mac` when not a device `id`.

## Local Development (optional)
You can still point the app to a local API by setting `API_BASE=http://localhost:5174` before running. The AWS code in `infra/` is the reference implementation.

## Cost Checks
- HTTP API v2 (cheaper) + Lambda + DynamoDB (no VPC, no NAT).
- DynamoDB TTL enabled for device records; short CloudWatch log retention (see template params).
- GSIs used for efficient queries (`mac-index`, `status-index`).

## Scripts
- `scripts\run-aws.cmd` — builds and launches the Windows app with `API_BASE` provided via env.

## Troubleshooting
- If Windows build fails with a file lock (LNK1104), the script kills any running `rightapply.exe` and retries deletion of the old exe.
- If the login chips show “Not linked” but you expect “Linked,” log in once with the intended user on this device; that binds the MAC to the user. The backend finds the most recent bound record for the MAC.

## License
MIT (or your choice)
