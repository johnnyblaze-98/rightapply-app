# rightapply (Local-only)

This repo is cleaned for local/offline usage. All cloud and third-party integrations have been removed.

What changed:
- Removed AWS infrastructure files and devcontainer configs
- Disabled external API calls by setting `kApiBase` to empty in `lib/services/api.dart`
- Kept core Flutter app code and assets only

Run locally:
1. Install Flutter SDK
2. Get packages
3. Run the app

Commands (Windows `cmd.exe`):

```
flutter pub get
flutter run
```

Notes:
- In local mode the app shows device info and a pending status; no network calls are made.
