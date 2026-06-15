# PawnTrack Flutter Port Setup

## What this folder contains

- `app/` is the Flutter web/mobile app.
- `server/` is the Firestore-primary backend with Google Sheets sync.
- `database/` documents the Firestore collections used by the app.

No existing PawnTrack files are changed by this port.

## Backend

1. Copy `server/googleSheets.config.example.json` to `server/googleSheets.config.json`.
2. Fill in the `googleSheetId`.
3. Keep the service account JSON outside the repo, for example:
   `C:/Users/94lut/Downloads/zippy-purpose-426703-q9-3048e05f6a58.json`
4. Make sure the Firebase service account has Firestore read/write, Cloud Storage object read/write, and Google Sheets access.
5. Optional config values can be set in `server/googleSheets.config.json`:
   `firebaseProjectId`, `firebaseServiceAccountFile`, `firebaseStorageBucket`, and `firestoreDatabaseId`.
   New Firebase Storage buckets normally use `PROJECT_ID.firebasestorage.app`; older projects may use `PROJECT_ID.appspot.com`.
6. From `server/`, install dependencies and start:

```powershell
npm install
npm start
```

The backend defaults to:

```text
http://127.0.0.1:8804
```

## Flutter app

From `app/`:

```powershell
flutter pub get
flutter run -d chrome
```

The app reads and writes through the backend. Google Sheets credentials are never stored in Flutter.

## Firestore Import

After the backend starts, seed Firestore from the current `NEW ONE` sheet:

```powershell
Invoke-WebRequest -UseBasicParsing -Method POST http://127.0.0.1:8804/api/import/sheets-to-firestore
```

After import, Firestore is the app database. Google Sheets is updated by sync jobs after Firestore writes.
