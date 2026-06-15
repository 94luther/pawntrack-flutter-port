# PawnTrack Firestore Collections

Firestore is the primary database for the Flutter app. Google Sheets is kept as a synced secondary business record.

## Collections

- `customers`
- `loans`
- `items`
- `repayments`
- `inventory`
- `sales`
- `riskScores`
- `staffUsers`
- `auditLog`
- `whatsappMessages`
- `voiceCommands`
- `syncJobs`
- `sheetSnapshots`
- `storageUploads`

Seed Firestore by calling `POST /api/import/sheets-to-firestore` once after backend startup.
