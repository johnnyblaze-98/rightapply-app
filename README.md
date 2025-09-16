# rightapply (Desktop-only)

This project is now desktop-only for local development (Windows first-class). A lightweight local API is included for device registration and allowlist checks.

Included services:
- Local API (Express + lowdb) on `http://localhost:5174`
- Flutter desktop app pointing to the local API

Run locally (Windows, Command Prompt):
1) Start the local API
```
cd api
npm install
node server.js
```
2) Run the desktop app in a new terminal
```
cd ..
flutter pub get
flutter run -d windows
```

Endpoints (local API):
- POST `/device/register` { mac, requesterEmail, platform, model?, osVersion?, reason? }
- GET `/device/status/:deviceId`
- GET `/device/pending`
- POST `/device/decide` { requestId, approve:boolean, decidedBy? }
- POST `/allowlist/add` { mac }

Notes:
- Devices with MACs in the allowlist auto-approve.
- Data persisted to `api/data/db.json` (ignored by git).
