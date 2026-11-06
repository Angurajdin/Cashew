# Cashew – Setup, Deployment & Cloud Sync Verification Guide

This guide walks you through:
1. Setting up your own Firebase project and configuring the app.
2. Running the app locally on Web, Android, or iOS.
3. Deploying Firestore security rules and Web hosting to Firebase.
4. Manually testing and verifying the **Cloud Database Sync** feature.

---

## 1. Prerequisites

Make sure you have the following installed on your machine:

- **Flutter SDK** (v3.19+ recommended, Dart SDK `>= 3.0.0`)
  ```bash
  flutter --version
  flutter doctor
  ```
- **Node.js** (v18+) & **Firebase CLI**
  ```bash
  npm install -g firebase-tools
  firebase login
  ```
- **FlutterFire CLI**
  ```bash
  dart pub global activate flutterfire_cli
  ```
  *(Ensure `~/.pub-cache/bin` or `$HOME/.pub-cache/bin` is in your `PATH`)*

---

## 2. Firebase Configuration Setup

Cashew uses **Firebase Authentication** (Google Sign-In) and **Cloud Firestore** for Cloud Database Sync. Follow these steps to point the app to your own Firebase project.

### Step 2.1: Create a Firebase Project
1. Go to the [Firebase Console](https://console.firebase.google.com/) and click **Add project**.
2. Give your project a name (e.g., `my-cashew-app`).
3. Google Analytics can be enabled or disabled according to your preference.

### Step 2.2: Enable Authentication
1. In Firebase Console, go to **Build** → **Authentication**.
2. Click **Get Started**, then select the **Sign-in method** tab.
3. Enable **Google**:
   - Set the project support email.
   - Click **Save**.
4. In **Settings** → **Authorized domains**, make sure `localhost` and your Firebase Hosting domain (e.g., `my-cashew-app.web.app`) are listed.

### Step 2.3: Enable Cloud Firestore
1. In Firebase Console, go to **Build** → **Firestore Database**.
2. Click **Create database**.
3. Choose a location closest to your users (e.g., `nam5 (us-central)` or `eur3 (europe-west)`).
4. Start in **Production mode** (we will deploy our own security rules shortly).

### Step 2.4: Configure the Flutter App with FlutterFire CLI

Navigate into the `budget` directory:

```bash
cd budget
```

Run the FlutterFire configuration wizard:

```bash
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

- Select the platforms you want to support (e.g., **Web**, **Android**, **iOS**).
- This will automatically generate or update [`budget/lib/firebase_options.dart`](budget/lib/firebase_options.dart), [`budget/android/app/google-services.json`](budget/android/app/google-services.json), and [`budget/ios/Runner/GoogleService-Info.plist`](budget/ios/Runner/GoogleService-Info.plist).

### Step 2.5: Configure Web Google Sign-In Client ID (for Web)
1. In the [Google Cloud Console Credentials Page](https://console.cloud.google.com/apis/credentials) for your Firebase project:
   - Find the **OAuth 2.0 Client ID** created for the **Web client**.
   - Copy the Client ID string (e.g. `123456789-abcdef.apps.googleusercontent.com`).
   - Add `http://localhost:5000` and `http://localhost` to **Authorized JavaScript origins**.
2. Open [`budget/web/index.html`](budget/web/index.html) and update line 21 with your Client ID:
   ```html
   <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
   ```

### Step 2.6: Update Firebase Project Aliases
Open [`budget/.firebaserc`](budget/.firebaserc) and set your default project:
```json
{
  "projects": {
    "default": "YOUR_FIREBASE_PROJECT_ID"
  }
}
```

And in [`budget/firebase.json`](budget/firebase.json), verify the hosting site name or change `"site": "YOUR_HOSTING_SITE"` to match your project.

---

## 3. Deploying Security Rules & Web Hosting

### Deploy Firestore Rules & Indexes

From the `budget/` directory, deploy the security rules and indexes:

```bash
cd budget
firebase deploy --only firestore:rules,firestore:indexes
```

The [`firestore.rules`](budget/firestore.rules) ensure that:
- Every user can only read and write their own data under `users/{uid}/**`.
- Shared budget rules remain secured for collaborators.

### Build and Deploy to Firebase Hosting (Web)

To build and deploy the web app:

```bash
cd budget
flutter build web --release --web-renderer canvaskit --no-tree-shake-icons
firebase deploy --only hosting
```

Your app is now live at `https://YOUR_PROJECT_ID.web.app`!

---

## 4. Running the App Locally

### Running on Chrome / Web

To test locally with Google Sign-In working properly on port 5000:

```bash
cd budget
flutter pub get
flutter run -d chrome --web-port=5000 --web-renderer canvaskit
```

> **Tip:** You can open `http://localhost:5000` in multiple browser windows or profiles to test multi-device synchronization.

### Running on Android / iOS

Connect your device or start an emulator/simulator, then run:

```bash
cd budget
flutter run
```

---

## 5. How to Manually Test & Verify Cloud Data Sync

Follow this end-to-end testing procedure to verify that Cloud Sync is fully functional.

### Test 1: Sign In & Enable Cloud Database Sync
1. Open the app (`http://localhost:5000` or on your device).
2. Go to **More** (or Sidebar) $\rightarrow$ **Accounts** / **Settings & Backups**.
3. Under **Account**, tap **Sign in with Google** and complete the sign-in flow.
4. Once signed in, locate the **Cloud Database Sync** section.
5. Turn on the **Sync with Cloud Firestore** switch.
6. A status badge will show **Syncing...** then transition to **Synced Just now** (or display a checkmark).

---

### Test 2: Verify Initial Sync in Firestore Console
1. Open the [Firebase Console](https://console.firebase.google.com/) $\rightarrow$ **Firestore Database**.
2. Under the **Data** tab, verify the following collection structure:
   ```
   users/
     └── [YOUR_USER_UID]/
           ├── meta/
           │     └── sync           (contains schemaVersion, lastWriterClientId, lastPushedAt)
           ├── wallets/             (your local wallets/accounts)
           ├── categories/          (your categories)
           ├── transactions/        (your transactions)
           ├── budgets/             (your budgets)
           └── deleteLogs/          (deletion tombstones)
   ```
3. Check one of your transaction documents in `transactions/{transactionPk}`:
   - All fields (amount, name, dateCreated, etc.) are populated.
   - System fields `_serverUpdatedAt`, `_clientId`, and `_schemaVersion` are present.
   - No illegal raw types or malformed strings exist.

---

### Test 3: Real-Time Multi-Client Sync (Two Devices / Tabs)
1. **Device A (Tab 1):** Keep `http://localhost:5000` open with Cloud Sync enabled.
2. **Device B (Tab 2 / Incognito or Phone):**
   - Open the app and sign in with the **same Google Account**.
   - Enable **Cloud Database Sync**.
   - Notice that all wallets, categories, and transactions from Device A are immediately pulled and rendered in Drift/SQLite!
3. On **Device A**:
   - Add a new transaction: `Coffee - $4.50` in the "Food" category.
4. On **Device B**:
   - Within seconds (or on pull-to-refresh / app focus), `Coffee - $4.50` will appear automatically in the transaction list!

---

### Test 4: Conflict Resolution (Last-Write-Wins / LWW)
1. On **Device A**: Edit `Coffee` transaction note to `"Bought at Cafe Alpha"`.
2. On **Device B**: Simultaneously edit the same transaction note to `"Bought at Cafe Beta"`.
3. The change with the more recent `dateTimeModified` timestamp wins across both devices without corrupting local data or crashing.

---

### Test 5: Deletions & Tombstone Propagation
1. On **Device A**: Delete the `Coffee` transaction.
2. Check the Firebase Console:
   - The document in `users/{uid}/transactions/{coffee-pk}` is deleted.
   - A tombstone document appears in `users/{uid}/deleteLogs/{deleteLogPk}`.
3. On **Device B**:
   - Pull/Sync runs.
   - The `Coffee` transaction is cleanly removed from Device B's local database.

---

### Test 6: Offline-First Capability
1. On **Device A**: Turn off Wi-Fi or disconnect network in DevTools (Network $\rightarrow$ Offline).
2. Create 3 new transactions and 1 new category while offline.
3. Notice the app remains fast and responsive because Drift/SQLite handles all local reads and writes.
4. Re-enable Wi-Fi / set Network back to Online.
5. Tap **Sync Now** (or wait for auto-sync).
6. Check Firestore and Device B: all offline changes are batched and synced up to the cloud!

---

### Test 7: Wipe Cloud Data (Privacy & Reset)
1. In the app, go to **Accounts** $\rightarrow$ **Cloud Database Sync**.
2. Tap **Delete Cloud Data**.
3. Confirm the action in the dialog.
4. Verify in Firebase Console: all subcollections under `users/{uid}/` are removed.
5. Local data remains safe on the current device.

---

## 6. Running Automated Tests

To run the automated Cloud Sync unit and integration test suite:

```bash
cd budget
flutter test test/cloud_serializer_test.dart test/cloud_sync_test.dart
```

This tests:
- **Round-trip serialization** for all 9 Drift entities.
- **Push $\rightarrow$ Pull** multi-client replication.
- **Last-Write-Wins (LWW)** timestamp rules.
- **Tombstone deletions** and cloud clean-up.
- **Echo suppression** (skipping own changes).

---

## 7. Troubleshooting

| Issue | Cause | Solution |
| --- | --- | --- |
| **`popup_closed_by_user` during Google Sign-In on Web** | Popups blocked or OAuth origin mismatch | Ensure `http://localhost:5000` is added to **Authorized JavaScript origins** in Google Cloud Console. |
| **`permission-denied` in Firestore** | Security rules not deployed or user not authenticated | Run `firebase deploy --only firestore:rules` and make sure you are signed in. |
| **`LateInitializationError` / Missing settings** | App launched without initializing defaults | Ensure `defaultPreferences.dart` contains defaults and call `initializeSettings()`. |
| **Google Drive sync disabled message** | Intentional safety measure | Cloud Firestore sync supersedes legacy Drive file sync to avoid conflicting writes. |
