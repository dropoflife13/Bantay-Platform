# Strict Business Rules

- **BR01 Idempotent Sync Deduplication:** Offline transactions carry a client UUID (`local_id`). The database uses `ON CONFLICT DO NOTHING` to prevent duplicates.
- **BR02 Immutable Transaction Auditing:** Transactions can NEVER be updated or deleted. Enforced by a `BEFORE UPDATE OR DELETE` trigger raising an exception.
- **BR03 PostGIS Geofence Validation:** If a sale happens outside the market boundary, flag `out_of_bounds = true`.
- **BR04 Credit Ledger Privacy Isolation:** The `ledgers` (Utang) table is strictly owner-only. No market or LGU admin can query it.
- **BR05 Offline Time Synchronization Delta:** If `device_recorded_at` is more than 24 hours off from server time, flag `temporal_anomaly = true`.