-- ============================================================
-- Gutzo: Habit Packs Table Migration
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Create habit_packs table
CREATE TABLE IF NOT EXISTS habit_packs (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  vendor_id            UUID NOT NULL REFERENCES vendors(id),
  product_id           UUID NOT NULL REFERENCES products(id),
  product_name         TEXT NOT NULL,
  product_image        TEXT,
  health_goal          TEXT,
  days_total           INTEGER NOT NULL DEFAULT 5,
  days_done            INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active', 'completed', 'cancelled', 'paused')),
  skip_dates           DATE[] DEFAULT '{}',
  start_date           DATE NOT NULL DEFAULT CURRENT_DATE,
  end_date             DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '4 days'),
  per_day_price        NUMERIC(10,2) NOT NULL,
  total_paid           NUMERIC(10,2) NOT NULL,
  delivery_address     JSONB,
  cancellation_reason  TEXT,
  cancelled_at         TIMESTAMPTZ,
  completed_at         TIMESTAMPTZ,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Add habit columns to orders table (if not exists)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS habit_pack_id UUID REFERENCES habit_packs(id),
  ADD COLUMN IF NOT EXISTS habit_day     INTEGER;

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_habit_packs_user_id   ON habit_packs(user_id);
CREATE INDEX IF NOT EXISTS idx_habit_packs_status     ON habit_packs(status);
CREATE INDEX IF NOT EXISTS idx_orders_habit_pack_id   ON orders(habit_pack_id);

-- 4. RLS Policies
ALTER TABLE habit_packs ENABLE ROW LEVEL SECURITY;

-- Users can only see/edit their own habit packs
CREATE POLICY "Users manage own habits"
  ON habit_packs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role bypass (for backend triggers)
CREATE POLICY "Service role full access"
  ON habit_packs FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 5. Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_habit_pack_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER habit_packs_updated_at
  BEFORE UPDATE ON habit_packs
  FOR EACH ROW EXECUTE FUNCTION update_habit_pack_timestamp();
