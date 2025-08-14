# Candidate Management App — Copilot Guide

> Purpose: steer Copilot to finish a device-gated Flutter app with a GCP (Cloud Run + Firestore) backend.

## Project structure (Flutter)
- `lib/main.dart`
- `lib/device_authentication.dart`
- `lib/admin_page.dart`
- `lib/services/api.dart` (new)
- `lib/utils/mac.dart` (new)

## One-shot Copilot Chat prompt (use with @workspace)
You are working in a Flutter project with these existing files:
- lib/main.dart
- lib/device_authentication.dart
- lib/admin_page.dart

Goal: finish a device-gated candidate management app.

Implement the following with clean, production-ready Dart code and minimal dependencies:

1) Device auth (on app start)
   - On launch, automatically fetch a device identifier:
     - Desktop (Windows/macOS/Linux): prefer NIC MAC via native commands
       - Windows: `getmac` (CSV, pick first physical/active MAC; normalize aa:bb:cc:dd:ee:ff)
       - macOS: `networksetup -listallhardwareports` (Wi-Fi/Ethernet MAC), fallback `ifconfig en0`
       - Linux: `cat /sys/class/net/*/address | head -n 1`
     - Android: use ANDROID_ID (device_info_plus)
     - iOS: use identifierForVendor (device_info_plus)
   - Call backend: GET {API_BASE}/device/status/{id}
     - If approved → navigate to AdminPage automatically.
     - If not approved → POST {API_BASE}/device/register with {mac/id, platform, model, osVersion, requesterEmail}, then show “Pending approval” with a Refresh button.
   - Show a card with Platform, Model, OS Version, Device ID (masked), and Status. Polished UI (Material 3, deep purple accents).

2) API client
   - Create `lib/services/api.dart` with:
     - `getStatus(String deviceId) -> {approved: bool, status: string}`
     - `registerDevice({mac, requesterEmail, platform, model, osVersion, reason?})`
     - `listPending() -> List<Map>`
     - `decide({requestId, approve, decidedBy}) -> bool`
   - Single config const: `const String kApiBase = 'https://<YOUR-CLOUD-RUN-URL>';`
   - Graceful behavior if kApiBase is empty:
     - `getStatus` returns `{approved:false, status:'pending'}`.
     - `registerDevice` no-ops and returns `{status:'pending'}`.
     - `listPending` returns `[]`.
     - `decide` returns `false`.

3) Admin pending devices list
   - In `AdminPage`, add a list that loads `GET /device/pending` and renders each request with Approve and Deny buttons.
   - Approve/Deny calls `POST /device/decide`.
   - Snackbar success/failure, Refresh button in AppBar, empty state. No crashes on network error.

4) Project wiring
   - Update `main.dart` to route `'/'` → DeviceAuthenticationPage and `'/admin'` → AdminPage.
   - Ensure dependencies in `pubspec.yaml`: `http`, `device_info_plus`.
   - Keep code self-contained; no external state mgmt libs; handle errors gracefully; spinner while loading.

Constraints & style:
- No business logic in widgets other than simple orchestration; HTTP lives in `services/api.dart`.
- Simple helpers allowed (e.g., `_normMac`, `_masked`).
- Ensure the app compiles and runs even without a backend.

After changes:
- Show the diff and explain where you created/modified files.
- Make sure it builds (`flutter pub get` → `flutter run`) without runtime errors.

---

## File-scoped TODOs (paste at top of each file)

### lib/device_authentication.dart
// COPILOT TODO (device_authentication):
// - Ensure this screen automatically on initState():
//   1) Gathers device info (platform, model, osVersion) and a deviceId:
//      * Windows: `getmac` CSV -> choose first valid MAC (normalize aa:bb:...)
//      * macOS: `networksetup -listallhardwareports` -> Wi-Fi/Ethernet MAC; fallback `ifconfig en0`
//      * Linux: read `/sys/class/net/*/address | head -n 1`
//      * Android: ANDROID_ID via device_info_plus
//      * iOS: identifierForVendor via device_info_plus
//   2) Calls ApiService.getStatus(deviceId)
//      * If approved: Navigator.pushReplacementNamed('/admin')
//      * Else: call ApiService.registerDevice(...) once, then show "Pending approval"
//   3) Provides a “Refresh Status” button that re-calls getStatus() and updates UI
// - UI: modern card with labels (Platform, Model, OS, Device ID masked except last 4), primary status text (green/orange/red), deepPurple AppBar.
// - If API_BASE is empty, skip network and show "Pending approval (no backend configured)" without errors.
// - Keep logic readable with helpers: _normMac, _masked, _bootstrap().
// - No crashes on errors; show spinner while loading.

### lib/admin_page.dart
// COPILOT TODO (admin_page):
// - Replace placeholder UI with a "Pending Device Requests" list:
//   * Uses ApiService.listPending() to load (on init and on Refresh button in AppBar).
//   * Each item shows mac, requesterEmail, platform, model, osVersion, createdAt.
//   * Two buttons: Approve (green) and Deny (red) -> ApiService.decide(requestId, approve, decidedBy:'admin@example.com').
//   * Show SnackBar on success/failure; reload list after decision.
//   * Empty state: "No pending requests".
// - Keep deepPurple AppBar, cards, nice spacing, StadiumBorder buttons.
// - No crashes on network error: show an error message and allow retry.

### lib/services/api.dart
// COPILOT TODO (services/api.dart):
// - Implement ApiService with static methods and a single const API base:
//     const String kApiBase = 'https://<YOUR-CLOUD-RUN-URL>';
//   Methods:
//     Future<Map<String,dynamic>> getStatus(String deviceId)
//     Future<Map<String,dynamic>> registerDevice({ required String mac, required String requesterEmail, required String platform, String model='', String osVersion='', String reason='New device registration' })
//     Future<List<Map<String,dynamic>>> listPending()
//     Future<bool> decide({ required String requestId, required bool approve, required String decidedBy })
// - Use package:http, JSON encode/decode, and basic error handling.
// - If kApiBase is empty, return safe defaults (approved=false, status='pending') and no-ops for decide/register.

### lib/utils/mac.dart
// COPILOT TODO (utils/mac.dart):
// - Implement helpers to fetch and normalize a primary MAC/ID:
//   * Desktop: run system commands (Windows `getmac`; macOS `networksetup`/`ifconfig`; Linux `/sys/class/net/*/address`).
//   * Mobile: return a stable fallback (ANDROID_ID / identifierForVendor).
// - Provide: Future<String> getPrimaryMacOrId(), String normMac(String s), String maskId(String s)
// - Handle errors gracefully; return "unknown" if not found.

---

## Pubspec prompt (if needed)
Update pubspec.yaml dependencies:
- http: ^1.2.2
- device_info_plus: ^10.1.0
Then run `flutter pub get`.

---

## Verification prompt
Verify:
1) App builds and runs with API_BASE empty: DeviceAuthentication shows "Pending approval (no backend configured)" and no crashes.
2) When API_BASE is set and status returns approved=true, app auto-navigates to AdminPage.
3) AdminPage loads pending list and Approve/Deny work (shows SnackBar and refreshes).
If anything fails, show the exact error and provide direct code fixes.
