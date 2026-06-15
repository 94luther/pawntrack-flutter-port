# PawnTrack Flutter App

This folder contains the Flutter source for the web/mobile port.

## Run web

```powershell
flutter pub get
flutter run -d chrome
```

## Generate mobile platform folders

If `android/` and `ios/` are not present yet, run this inside `app/` after Flutter is installed:

```powershell
flutter create --platforms=android,ios,web .
```

Then keep the existing `lib/`, `pubspec.yaml`, and `web/` files.

## Backend URL

The app currently points to:

```text
http://127.0.0.1:8810
```

That is the backend in `../server/`.
