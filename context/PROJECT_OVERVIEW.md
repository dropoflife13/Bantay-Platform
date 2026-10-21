# Bantay Platform Context

## Executive Summary
The Bantay Platform is an enterprise B2G multi-tenant platform for formalizing and managing local micro-economies, built for intermittent-connectivity environments.

## Technology Stack
- **Frontend:** Next.js 15 (App Router), React 19, Tailwind CSS, shadcn/ui
- **Backend/Database:** Supabase (PostgreSQL 15+ with PostGIS)
- **Offline Storage:** Dexie.js (IndexedDB)
- **Realtime:** Supabase Realtime (WebSockets)
- **Auth:** Supabase Auth (JWT via @supabase/ssr)
- **Hosting:** Vercel

## Core Architecture Rules
1. **Database-Level Multi-Tenancy (RLS):** Tenant isolation is enforced inside the PostgreSQL query engine using Row-Level Security (RLS) tied to JWT claims.
2. **Idempotent Batch Offline Ingestion:** Offline queues in IndexedDB are ingested via a single PostgreSQL RPC function (`sync_offline_batch`).
3. **Geospatial Compliance:** PostGIS `ST_MakePoint` and `ST_Contains` are used to geofence vendors against market boundaries.
4. **Edge-Compatible Authentication:** JWT verification in Next.js Edge Middleware.

## User Roles (RBAC)
- `lgu_admin`: Global admin, sees all markets and transactions.
- `market_admin`: Tenant admin, sees only their assigned market.
- `vendor`: Mobile seller, sees only their own records/transactions.