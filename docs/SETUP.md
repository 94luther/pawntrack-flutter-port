# PawnTrack Flutter Port Setup

## What this folder contains

- `app/` is the Flutter web/mobile app.
- `server/` is the Google Sheets bridge with PostgreSQL mirror support.
- `database/` contains the PostgreSQL schema.

No existing PawnTrack files are changed by this port.

## Backend

1. Copy `server/googleSheets.config.example.json` to `server/googleSheets.config.json`.
2. Fill in the `googleSheetId`.
3. Keep the service account JSON outside the repo, for example:
   `C:/Users/94lut/Downloads/zippy-purpose-426703-q9-3048e05f6a58.json`
4. Create the PostgreSQL database and run `database/schema.sql`.
5. From `server/`, install dependencies and start:

```powershell
npm install
npm start
```

The backend defaults to:

```text
http://127.0.0.1:8810
```

## Flutter app

From `app/`:

```powershell
flutter pub get
flutter run -d chrome
```

The app reads and writes through the backend. Google Sheets credentials are never stored in Flutter.
