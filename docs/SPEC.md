# Specification: Bantay LGU Platform

## 1. Overview & Core Mission
The **Bantay LGU Platform** is an enterprise B2G multi-tenant system for formalizing and managing local micro-economies (wet markets, street vendor spots, and municipal merchant districts). It is architected specifically for intermittent connectivity, mobile vendors, and strict audit compliance.

## 2. Personas & Access Control (RBAC)
- **`lgu_admin`**: Global municipality administrator. Has cross-market visibility, revenue reporting, audit trail inspection, and regulatory compliance views.
- **`market_admin`**: Tenant administrator assigned to a specific market. Manages vendor registrations, stall allocations, daily attendance, and localized reports.
- **`vendor`**: Point-of-Sale user (stallholder / mobile seller). Records sales offline, tracks private customer debt (Utang), and synchronizes with the cloud when online.

## 3. Strict Business Rules
- **BR01 Idempotent Sync Deduplication:** Offline transactions carry a client UUID (`local_id`). Ingestion uses `ON CONFLICT (vendor_id, local_id) DO NOTHING` to prevent double-charging or duplicate entries.
- **BR02 Immutable Transaction Auditing:** Transactions can NEVER be updated or deleted once recorded. Enforced by PostgreSQL `BEFORE UPDATE OR DELETE` trigger raising an exception.
- **BR03 PostGIS Geofence Validation:** Every transaction location is tested against the market's boundary polygon (`ST_Contains(boundary, point)`). Any sale recorded outside the boundary triggers `out_of_bounds = true`.
- **BR04 Credit Ledger Privacy Isolation:** The `ledgers` table ("Utang") is strictly owner-only. No market or LGU admin has access to read or inspect private debtor ledgers.
- **BR05 Temporal Anomaly Delta:** If `device_recorded_at` is more than 24 hours off from server time (`NOW()`), flag `temporal_anomaly = true`.

## 4. Technical Architecture
- **Frontend:** Next.js 16 (App Router), React 19, Tailwind CSS v4, Lucide React, shadcn/ui.
- **Offline Database:** Dexie.js (IndexedDB) for local transaction queue and offline ledgers.
- **Cloud Backend:** Supabase (PostgreSQL 15+ with PostGIS, Auth with `@supabase/ssr`, Realtime).
- **Geospatial Engine:** Mapbox GL with PostGIS geometries (`Polygon`, `Point` SRID 4326).
- **Hosting:** Vercel with edge-compatible middleware session refresh.

## 5. Offline Batch Sync Protocol
Offline transactions are queued in IndexedDB and dispatched in batches to the PostgreSQL RPC function:
`POST /rpc/sync_offline_batch`
The function executes inside a `SECURITY DEFINER` transaction, handles per-record exceptions, checks PostGIS boundaries, verifies clock deltas, and returns an ingestion report (`inserted`, `duplicates`, `failed`, `errors`).

