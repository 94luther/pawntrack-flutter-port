# PawnTrack PostgreSQL Mirror

This schema mirrors the live Google Sheet so the Flutter app can behave like a real app instead of relying only on browser-local state.

## Local setup

1. Create a PostgreSQL database named `pawntrack`.
2. Run `schema.sql`.
3. Put your connection string in `server/googleSheets.config.json` as `databaseUrl`.

The backend still updates Google Sheets. PostgreSQL stores snapshots, inventory sales, and sync jobs so failed writes can be seen and retried later.
