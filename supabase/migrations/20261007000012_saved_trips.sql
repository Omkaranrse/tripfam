-- Migration: 20261007000012_saved_trips.sql
-- Description: Saved Trips table, strict RLS policies, 200-trip user cap trigger,
--              anonymous aggregator function for host trip-saved count, and security test script.

-- ============================================================================
-- 1. Table Definition
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.saved_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_saved_trips_user_trip UNIQUE (user_id, trip_id)
);

-- Indexes for fast lookup by user and by trip
CREATE INDEX IF NOT EXISTS idx_saved_trips_user_id ON public.saved_trips(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_trips_trip_id ON public.saved_trips(trip_id);

-- ============================================================================
-- 2. Cap Saved Trips at 200 Per User (Trigger)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.check_saved_trips_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.saved_trips
    WHERE user_id = NEW.user_id;

    IF v_count >= 200 THEN
        RAISE EXCEPTION 'User cannot save more than 200 trips (quota reached).';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_saved_trips_limit ON public.saved_trips;
CREATE TRIGGER trg_check_saved_trips_limit
BEFORE INSERT ON public.saved_trips
FOR EACH ROW
EXECUTE FUNCTION public.check_saved_trips_limit();

-- ============================================================================
-- 3. Row Level Security (RLS)
-- ============================================================================

ALTER TABLE public.saved_trips ENABLE ROW LEVEL SECURITY;

-- 3.1 SELECT: Users can only read their own saved trips
DROP POLICY IF EXISTS "saved_trips_select_own" ON public.saved_trips;
CREATE POLICY "saved_trips_select_own"
ON public.saved_trips
FOR SELECT
TO authenticated
USING (
    auth.uid() = user_id
);

-- 3.2 INSERT: Users can only insert their own row, only if the trip is visible
-- (not their own trip, and no mutual block exists between user and host)
DROP POLICY IF EXISTS "saved_trips_insert_own" ON public.saved_trips;
CREATE POLICY "saved_trips_insert_own"
ON public.saved_trips
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = trip_id
          AND t.host_id <> auth.uid()
          AND NOT public.is_blocked_mutually(auth.uid(), t.host_id)
    )
);

-- 3.3 DELETE: Users can only remove their own saved trips
DROP POLICY IF EXISTS "saved_trips_delete_own" ON public.saved_trips;
CREATE POLICY "saved_trips_delete_own"
ON public.saved_trips
FOR DELETE
TO authenticated
USING (
    auth.uid() = user_id
);

-- Note: No UPDATE policy is provided. Saved trips are immutable.

-- ============================================================================
-- 4. Privacy: Hosts & Others Never See Who Saved A Trip
-- Total Count Only via Security-Definer Function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_trip_saved_count(p_trip_id UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*)::INT
    FROM public.saved_trips
    WHERE trip_id = p_trip_id;
$$;

-- Permissions
GRANT SELECT, INSERT, DELETE ON public.saved_trips TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_trip_saved_count(UUID) TO authenticated, anon;

-- ============================================================================
-- 5. Two-Account Security Verification Test Script
-- Run this in psql or Supabase SQL Editor to verify complete isolation:
-- ============================================================================
/*
DO $$
DECLARE
    v_user_a UUID := '11111111-1111-1111-1111-111111111111';
    v_user_b UUID := '22222222-2222-2222-2222-222222222222';
    v_trip_id UUID;
    v_count INT;
BEGIN
    -- 1. Setup: Assume a published trip exists hosted by a third user
    SELECT id INTO v_trip_id FROM public.trips LIMIT 1;
    IF v_trip_id IS NULL THEN
        RAISE NOTICE 'Skipping test: no trips exist.';
        RETURN;
    END IF;

    -- 2. Simulate User A saving the trip
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_a::text)::text, true);

    INSERT INTO public.saved_trips (user_id, trip_id)
    VALUES (v_user_a, v_trip_id);

    -- User A can read own row
    SELECT COUNT(*) INTO v_count FROM public.saved_trips WHERE user_id = v_user_a;
    ASSERT v_count = 1, 'Test Failed: User A should see their saved trip';

    -- 3. Simulate User B trying to read User A's saved trips
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_b::text)::text, true);

    SELECT COUNT(*) INTO v_count FROM public.saved_trips WHERE user_id = v_user_a;
    ASSERT v_count = 0, 'Test Failed: User B was able to read User A saved trips!';

    -- 4. User B trying to delete User A's saved row
    DELETE FROM public.saved_trips WHERE user_id = v_user_a;
    -- Verify row is still intact
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_a::text)::text, true);
    SELECT COUNT(*) INTO v_count FROM public.saved_trips WHERE user_id = v_user_a;
    ASSERT v_count = 1, 'Test Failed: User B deleted User A saved trip!';

    -- 5. Cleanup
    DELETE FROM public.saved_trips WHERE user_id = v_user_a;
    RAISE NOTICE 'Two-Account Security Test PASSED successfully.';
END;
$$;
*/
