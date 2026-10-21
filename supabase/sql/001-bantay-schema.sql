-- Bantay LGU Platform: Initial Database Migration & Security Setup
-- Implements specifications from context/DATABASE_SCHEMA.md & context/BUSINESS_RULES.md

-- 1. Enable Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 2. Define Custom Enums & Types
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('lgu_admin', 'market_admin', 'vendor');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 3. Core Tables

-- Markets Table: Represents geographic market territories with boundary polygons
CREATE TABLE IF NOT EXISTS markets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  code        TEXT UNIQUE NOT NULL,
  boundary    GEOMETRY(Polygon, 4326) NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Profiles Table: Extends auth.users with role and market tenancy
CREATE TABLE IF NOT EXISTS profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  market_id     UUID REFERENCES markets(id) ON DELETE SET NULL,
  role          user_role NOT NULL DEFAULT 'vendor',
  full_name     TEXT NOT NULL,
  qr_token      TEXT UNIQUE,
  status        TEXT NOT NULL DEFAULT 'active',
  assigned_slot TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Transactions Table: Point-of-Sale records with offline sync deduplication & PostGIS geofencing
CREATE TABLE IF NOT EXISTS transactions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  local_id            UUID NOT NULL, -- Client-generated UUID for offline idempotency (BR01)
  vendor_id           UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
  market_id           UUID NOT NULL REFERENCES markets(id) ON DELETE RESTRICT,
  total_amount        NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
  payment_method      TEXT NOT NULL DEFAULT 'cash',
  location            GEOMETRY(Point, 4326),
  out_of_bounds       BOOLEAN NOT NULL DEFAULT false, -- BR03
  device_recorded_at  TIMESTAMPTZ NOT NULL,
  server_synced_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  temporal_anomaly    BOOLEAN NOT NULL DEFAULT false, -- BR05 (>24h delta)
  CONSTRAINT uq_vendor_local_id UNIQUE (vendor_id, local_id)
);

-- Ledgers Table: Confidential vendor customer credit ("Utang") ledger (BR04)
CREATE TABLE IF NOT EXISTS ledgers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  customer_name TEXT NOT NULL,
  amount        NUMERIC(12, 2) NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending', -- pending, settled, cancelled
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. Triggers for Immutability (BR02)
-- Enforces that transactions can NEVER be updated or deleted once inserted
CREATE OR REPLACE FUNCTION enforce_transactions_immutability()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'BR02 Violation: Transactions are immutable and cannot be updated or deleted.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_transactions_immutable ON transactions;
CREATE TRIGGER trg_transactions_immutable
  BEFORE UPDATE OR DELETE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION enforce_transactions_immutability();

-- 5. Row-Level Security (RLS) Configuration

ALTER TABLE markets ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledgers ENABLE ROW LEVEL SECURITY;

-- Helper functions for RLS checks
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION current_user_market_id()
RETURNS UUID AS $$
  SELECT market_id FROM profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Policies: Markets
DROP POLICY IF EXISTS "markets_view_policy" ON markets;
CREATE POLICY "markets_view_policy" ON markets
  FOR SELECT TO authenticated
  USING (
    current_user_role() = 'lgu_admin'
    OR id = current_user_market_id()
  );

-- Policies: Profiles
DROP POLICY IF EXISTS "profiles_select_policy" ON profiles;
CREATE POLICY "profiles_select_policy" ON profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR current_user_role() = 'lgu_admin'
    OR (current_user_role() = 'market_admin' AND market_id = current_user_market_id())
  );

DROP POLICY IF EXISTS "profiles_update_self" ON profiles;
CREATE POLICY "profiles_update_self" ON profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Policies: Transactions
DROP POLICY IF EXISTS "transactions_select_policy" ON transactions;
CREATE POLICY "transactions_select_policy" ON transactions
  FOR SELECT TO authenticated
  USING (
    vendor_id = auth.uid()
    OR current_user_role() = 'lgu_admin'
    OR (current_user_role() = 'market_admin' AND market_id = current_user_market_id())
  );

DROP POLICY IF EXISTS "transactions_insert_policy" ON transactions;
CREATE POLICY "transactions_insert_policy" ON transactions
  FOR INSERT TO authenticated
  WITH CHECK (vendor_id = auth.uid());

-- Policies: Ledgers (BR04 - Strictly Owner-Only Privacy Isolation)
DROP POLICY IF EXISTS "ledgers_owner_all" ON ledgers;
CREATE POLICY "ledgers_owner_all" ON ledgers
  FOR ALL TO authenticated
  USING (vendor_id = auth.uid())
  WITH CHECK (vendor_id = auth.uid());

-- 6. RPC Function: sync_offline_batch
-- Ingests offline transactions idempotently with geospatial & temporal checks
CREATE OR REPLACE FUNCTION sync_offline_batch(payload JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item                JSONB;
  v_local_id            UUID;
  v_vendor_id           UUID;
  v_market_id           UUID;
  v_amount              NUMERIC;
  v_payment_method      TEXT;
  v_lat                 NUMERIC;
  v_lon                 NUMERIC;
  v_point               GEOMETRY(Point, 4326);
  v_boundary            GEOMETRY(Polygon, 4326);
  v_device_recorded_at  TIMESTAMPTZ;
  v_out_of_bounds       BOOLEAN;
  v_temporal_anomaly    BOOLEAN;
  v_inserted_count      INT := 0;
  v_duplicate_count     INT := 0;
  v_failed_count        INT := 0;
  v_errors              JSONB := '[]'::JSONB;
BEGIN
  IF jsonb_typeof(payload) <> 'array' THEN
    RAISE EXCEPTION 'Payload must be a JSON array of transaction objects.';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(payload)
  LOOP
    BEGIN
      v_local_id := (v_item->>'local_id')::UUID;
      v_vendor_id := auth.uid(); -- Enforce caller identity
      v_market_id := (v_item->>'market_id')::UUID;
      v_amount := (v_item->>'total_amount')::NUMERIC;
      v_payment_method := COALESCE(v_item->>'payment_method', 'cash');
      v_device_recorded_at := (v_item->>'device_recorded_at')::TIMESTAMPTZ;
      
      -- Location parsing
      IF (v_item ? 'latitude') AND (v_item ? 'longitude') AND 
         (v_item->>'latitude' IS NOT NULL) AND (v_item->>'longitude' IS NOT NULL) THEN
        v_lat := (v_item->>'latitude')::NUMERIC;
        v_lon := (v_item->>'longitude')::NUMERIC;
        v_point := ST_SetSRID(ST_MakePoint(v_lon, v_lat), 4326);
      ELSE
        v_point := NULL;
      END IF;

      -- Check PostGIS boundary (BR03)
      v_out_of_bounds := false;
      IF v_point IS NOT NULL THEN
        SELECT boundary INTO v_boundary FROM markets WHERE id = v_market_id;
        IF v_boundary IS NOT NULL THEN
          v_out_of_bounds := NOT ST_Contains(v_boundary, v_point);
        END IF;
      END IF;

      -- Check Temporal Anomaly (BR05: delta > 24 hours = 86400 seconds)
      v_temporal_anomaly := ABS(EXTRACT(EPOCH FROM (NOW() - v_device_recorded_at))) > 86400;

      -- Idempotent insert with ON CONFLICT DO NOTHING (BR01)
      INSERT INTO transactions (
        local_id,
        vendor_id,
        market_id,
        total_amount,
        payment_method,
        location,
        out_of_bounds,
        device_recorded_at,
        server_synced_at,
        temporal_anomaly
      ) VALUES (
        v_local_id,
        v_vendor_id,
        v_market_id,
        v_amount,
        v_payment_method,
        v_point,
        v_out_of_bounds,
        v_device_recorded_at,
        now(),
        v_temporal_anomaly
      )
      ON CONFLICT (vendor_id, local_id) DO NOTHING;

      IF FOUND THEN
        v_inserted_count := v_inserted_count + 1;
      ELSE
        v_duplicate_count := v_duplicate_count + 1;
      END IF;

    EXCEPTION WHEN OTHERS THEN
      v_failed_count := v_failed_count + 1;
      v_errors := v_errors || jsonb_build_object(
        'local_id', v_item->>'local_id',
        'error', SQLERRM
      );
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'success',
    'inserted', v_inserted_count,
    'duplicates', v_duplicate_count,
    'failed', v_failed_count,
    'errors', v_errors
  );
END;
$$;

