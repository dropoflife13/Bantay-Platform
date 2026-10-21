# Database Schema & SQL Context

## Extensions Required
- `uuid-ossp`
- `postgis`

## Core Tables
- `markets`: (id, name, code, boundary GEOMETRY(Polygon, 4326))
- `profiles`: (id, market_id, role user_role, full_name, qr_token, status, assigned_slot)
- `transactions`: (id, local_id, vendor_id, market_id, total_amount, payment_method, location GEOMETRY(Point, 4326), out_of_bounds, device_recorded_at, server_synced_at, temporal_anomaly). Unique constraint on `(vendor_id, local_id)`.
- `ledgers`: (id, vendor_id, customer_name, amount, status) - Utang records.

## RPC Function: `sync_offline_batch(payload JSONB)`
- Must be `SECURITY DEFINER`.
- Loops through JSON array.
- Checks PostGIS bounds: `ST_Contains(v_boundary, v_point)`.
- Checks time anomaly: `ABS(EXTRACT(EPOCH FROM (NOW() - device_recorded_at))) > 86400`.
- Uses `ON CONFLICT (vendor_id, local_id) DO NOTHING` for idempotency.
- Handles exceptions per record so one bad record doesn't fail the batch.