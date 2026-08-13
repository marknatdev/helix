# Firebase Auth Setup

The app is gated by Firebase email/password auth. Configuration is loaded from
a `.env` file at runtime — no `flutterfire configure` needed.

## 1. Create a Firebase project

1. Go to <https://console.firebase.google.com> and create a project (any name).
2. In **Authentication → Sign-in method**, enable **Email/Password**.
3. Under **Authorized domains**, ensure `localhost` is listed (it usually is by default).

## 2. Register a Web app and copy the config

1. In the Firebase console, go to **Project settings** (gear icon) → **General**.
2. Under **Your apps**, click the Web icon (`</>`) to add a Web app.
3. Give it a nickname (e.g. `helix-web`) and click **Register app**.
4. You'll see a `firebaseConfig` object like this:

```js
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "my-project.firebaseapp.com",
  projectId: "my-project",
  storageBucket: "my-project.firebasestorage.app",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123",
  measurementId: "G-XXXXXXX"
};
```

## 3. Fill in `.env`

Copy `.env.example` to `.env` (already done during scaffolding) and paste your
values:

```
FIREBASE_API_KEY=AIza...
FIREBASE_AUTH_DOMAIN=my-project.firebaseapp.com
FIREBASE_PROJECT_ID=my-project
FIREBASE_STORAGE_BUCKET=my-project.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_APP_ID=1:123456789:web:abc123
FIREBASE_MEASUREMENT_ID=G-XXXXXXX
FIREBASE_IOS_BUNDLE_ID=
```

The `.env` file is git-ignored. **Never commit it.**

## 4. Run the app

```powershell
cd d:\smart_helmet\flutter_app
flutter run -d chrome
```

You should see the **Operator sign in** screen. The app does **not** auto-login
— a fresh launch starts signed out unless Firebase has a persisted session.

## 5. Create the tester account

On the login screen click **Need access? Create an account** and register:

| Field    | Value               |
| -------- | ------------------- |
| Email    | `tester@helix.dev`  |
| Password | `helix-tester-2026` |

After sign-up you are automatically signed in and routed to the command center.
Use the gear icon → **Sign out** to return to the login screen.

## Troubleshooting

| Error | Fix |
| ----- | --- |
| `StateError: Missing FIREBASE_API_KEY in .env` | You skipped step 3 — fill in `.env`. |
| `operation-not-allowed` | Enable Email/Password in the Firebase console (step 1). |
| CORS / network errors on web | Add `localhost` to Authorized domains. |
