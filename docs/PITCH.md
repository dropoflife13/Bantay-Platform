# Pitch: Bantay LGU Platform

## The Hook
In almost every Philippine public market, millions in pesos circulate every morning with zero internet connection, recorded on torn cardboard scraps and paper notebooks. When local governments try to digitize wet markets, apps crash the moment the signal drops, and vendors refuse to participate for fear their private books will be exposed.

## The Solution
**Bantay** is an offline-first micro-economy operating system built for Philippine local governments:
1. **Never Drops a Sale:** Offline-first Point-of-Sale powered by local IndexedDB storage that batches and syncs cleanly the instant signal returns.
2. **PostGIS Geofencing:** Automatically certifies whether stalls are operating within their allocated perimeter.
3. **Protected Privacy:** Strict database-level encryption and Row-Level Security guarantee that a vendor's informal credit ledger (*Utang*) can never be viewed by any admin or third party.
4. **Idempotent Audit Guarantee:** Every offline record has a deterministic UUID and tamper-proof database trigger preventing duplicate charges or falsified records.

## The 3-Minute Demo Flow
1. **Offline POS Transaction:** Vendor switches to Airplane mode, records transactions and credit entries.
2. **Geofenced Ingestion:** Network reconnects; offline transactions sync automatically via `sync_offline_batch`.
3. **Market Admin Map:** Market Supervisor views real-time occupancy map with PostGIS boundaries, flagging valid vs out-of-bounds sales.
4. **Strict RLS Verification:** Inspecting the database confirms admin accounts cannot see private vendor credit ledgers.

