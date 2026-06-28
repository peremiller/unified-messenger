# Activating Firebase Cloud Messaging (closed-app push)

All the code is already wired. FCM only needs **your** Firebase project (I can't
create it — it requires your Google login and downloads secrets). These steps
take ~15 minutes and then "need help" alerts reach phones even when the app is
fully closed.

Until you do this, the app runs fine and `help_alert` still works via the
WebSocket + in-app banner + local notifications — there's just no closed-app push.

## 1. Create a Firebase project
- Go to https://console.firebase.google.com → **Add project**.
- Add an **Android app** (package `com.unifiedmessenger.app`) and, if you build
  for iOS, an **iOS app** (same bundle id).

## 2. Wire the app (one command)
```bash
dart pub global activate flutterfire_cli
cd ~/unified-messenger/app
flutterfire configure
```
This **overwrites** `lib/firebase_options.dart` with your real project values and
drops the native config files (`android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`) + Gradle wiring automatically. Nothing
else in the app needs to change — `PushService` already reads
`DefaultFirebaseOptions.currentPlatform`, registers the device token with the
backend, and shows foreground/background help notifications.

## 3. iOS only — APNs
FCM on iOS rides on Apple Push. In the Firebase console → **Project settings →
Cloud Messaging → Apple app config**, upload your **APNs auth key** (.p8 from the
Apple Developer portal). Also enable **Push Notifications** + **Background Modes
→ Remote notifications** capabilities in Xcode.

## 4. Wire the backend (service-account key)
- Firebase console → **Project settings → Service accounts → Generate new
  private key** → downloads a JSON.
- Save it outside the repo (it's a secret) and point the backend at it:
  ```bash
  # backend/.env
  FIREBASE_CREDENTIALS=/absolute/path/to/service-account.json
  ```
- Install the optional dep and restart:
  ```bash
  cd ~/unified-messenger/backend && source venv/bin/activate
  pip install firebase-admin
  ```
- Verify: `curl localhost:8000/api/fcm/status` → `{"configured": true, ...}`.

## How it flows once live
1. App starts → `PushService.init()` gets the FCM token → `POST /api/fcm/register`.
2. A contact taps **Need help** → backend `POST /api/presence` (status=help).
3. Backend broadcasts the WebSocket `help_alert` **and** calls `fcm.send_help()`
   → FCM pushes to every registered device, shown in the OS tray even if the
   app is closed.

## 5. Web push (PWA) — now wired
The app runs Firebase on web too; web push just needs a VAPID key + the service
worker filled in.

1. In Firebase console → **Project settings → Cloud Messaging → Web Push
   certificates** → **Generate key pair**. Copy the public key.
2. Paste your web SDK config into **`web/firebase-messaging-sw.js`** (replace the
   `REPLACE_ME` block — same values `flutterfire configure` wrote to the web
   block of `lib/firebase_options.dart`). The service worker stays inert until
   real values are present.
3. Build/run the web app with the VAPID key:
   ```bash
   flutter run -d chrome --dart-define=FCM_VAPID_KEY=<your-public-key>
   # or: flutter build web --dart-define=FCM_VAPID_KEY=<your-public-key>
   ```
   `PushService` passes it to `getToken()`, registers the browser token with the
   backend, and `firebase-messaging-sw.js` shows the OS notification when the
   PWA is backgrounded/closed. Foreground web is already covered by the in-app
   WebSocket banner.

Notes: web push requires HTTPS (or localhost) and the user granting the browser
notification permission. iOS Safari supports web push only for **installed**
PWAs (Add to Home Screen) on iOS 16.4+.

## Security note
Never commit `google-services.json`, `GoogleService-Info.plist`, the
service-account JSON, or a real `firebase_options.dart` with secrets if the repo
is public. They're covered by `.gitignore`; keep it that way.
