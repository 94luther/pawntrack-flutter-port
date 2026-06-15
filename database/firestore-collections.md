# Firestore Data Model

PawnTrack stores operational data in Firestore and mirrors important changes to Google Sheets.

## Primary Collections

- `customers`: borrower identity, Omang, contact details, address, and photo URLs.
- `loans`: pawn/loan terms, balances, due dates, extension counts, risk score, and source sheet row metadata.
- `items`: pawned item details, serial/IMEI, proof metadata, testing checklist, storage location, and photo URLs.
- `repayments`: repayment events linked to source loan rows.
- `inventory`: available or sold inventory records.
- `sales`: sale events and actual profit.
- `riskScores`: score snapshots and reasons.
- `staffUsers`: staff records for future auth/audit assignment.
- `auditLog`: transaction edits, corrections, forfeitures, and sync-affecting actions.
- `whatsappMessages`: generated reminders and delivery status.
- `voiceCommands`: command transcripts and parsed actions.
- `syncJobs`: Firestore-to-Google-Sheets sync attempts.
- `sheetSnapshots`: canonical sheet-shaped payload used for Flutter compatibility.
- `storageUploads`: Cloud Storage file metadata and download URLs.
