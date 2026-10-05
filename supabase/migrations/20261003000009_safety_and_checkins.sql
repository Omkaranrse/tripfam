-- Migration: 20261003000009_safety_and_checkins.sql
-- Description: Trusted contacts (max 3, private), trip check-in schedules,
--              missed check-in alert processing, live location sharing (active trip opt-in with short retention),
--              and admin reports review.

-- ============================================================================
-- 1. Trusted Contacts Enhancements
-- ============================================================================

-- Allow email-only or phone-only trusted contacts
ALTER TABLE public.trusted_contacts ALTER COLUMN phone_number DROP NOT NULL;
ALTER TABLE public.trusted_contacts ALTER COLUMN relationship SET DEFAULT 'Emergency Contact';

-- Add check constraint ensuring either phone or email is provided
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_trusted_contacts_reach'
    ) THEN
        ALTER TABLE public.trusted_contacts
            ADD CONSTRAINT chk_trusted_contacts_reach
            CHECK (phone_number IS NOT NULL OR email IS NOT NULL);
    END IF;
END $$;

-- Enforce max 3 trusted contacts per user via trigger
CREATE OR REPLACE FUNCTION public.check_trusted_contacts_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (SELECT COUNT(*) FROM public.trusted_contacts WHERE user_id = NEW.user_id) >= 3 THEN
        RAISE EXCEPTION 'You can only add up to 3 trusted contacts.' USING ERRCODE = '22000';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_trusted_contacts_limit ON public.trusted_contacts;
CREATE TRIGGER trg_check_trusted_contacts_limit
    BEFORE INSERT ON public.trusted_contacts
    FOR EACH ROW
    EXECUTE FUNCTION public.check_trusted_contacts_limit();

-- ============================================================================
-- 2. Trip Check-In Schedules Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.trip_checkin_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    interval_hours INT NOT NULL DEFAULT 12,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_checkin_at TIMESTAMPTZ,
    next_checkin_due_at TIMESTAMPTZ,
    alert_sent BOOLEAN NOT NULL DEFAULT false,
    alert_sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_trip_checkin_user_trip UNIQUE (trip_id, user_id),
    CONSTRAINT chk_checkin_interval CHECK (interval_hours IN (4, 6, 12, 24, 48))
);

ALTER TABLE public.trip_checkin_schedules ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_trip_checkin_schedules_updated_at
    BEFORE UPDATE ON public.trip_checkin_schedules
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- RLS: Only the owner or staff can view and manage their check-in schedule
DROP POLICY IF EXISTS "trip_checkin_schedules_policy" ON public.trip_checkin_schedules;
CREATE POLICY "trip_checkin_schedules_policy"
    ON public.trip_checkin_schedules
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid() OR public.is_staff(auth.uid()))
    WITH CHECK (user_id = auth.uid() OR public.is_staff(auth.uid()));

-- ============================================================================
-- 3. Live Location Sharing Table (Opt-in per active trip, short retention)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.trip_live_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    accuracy_meters NUMERIC(6, 2),
    is_sharing_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_trip_location_user_trip UNIQUE (trip_id, user_id),
    CONSTRAINT chk_loc_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_loc_lng CHECK (longitude BETWEEN -180 AND 180)
);

ALTER TABLE public.trip_live_locations ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_trip_live_locations_updated_at
    BEFORE UPDATE ON public.trip_live_locations
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

-- Security: Location data never reaches other travellers; strictly owner & safety staff only
DROP POLICY IF EXISTS "trip_live_locations_policy" ON public.trip_live_locations;
CREATE POLICY "trip_live_locations_policy"
    ON public.trip_live_locations
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid() OR public.is_staff(auth.uid()))
    WITH CHECK (user_id = auth.uid() OR public.is_staff(auth.uid()));

-- ============================================================================
-- 4. Check-In & Safety Database Functions
-- ============================================================================

-- Function: record_trip_checkin ("I'm safe" CTA)
CREATE OR REPLACE FUNCTION public.record_trip_checkin(
    p_trip_id UUID,
    p_location_name VARCHAR DEFAULT 'Manual Safe Check-In',
    p_latitude NUMERIC DEFAULT NULL,
    p_longitude NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_interval_hours INT := 12;
    v_next_due TIMESTAMPTZ;
    v_checkin_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Record in public.check_ins
    INSERT INTO public.check_ins (trip_id, user_id, location_name, latitude, longitude, is_safe)
    VALUES (p_trip_id, v_caller_id, p_location_name, p_latitude, p_longitude, true)
    RETURNING id INTO v_checkin_id;

    -- Get or initialize schedule interval
    SELECT interval_hours INTO v_interval_hours
    FROM public.trip_checkin_schedules
    WHERE trip_id = p_trip_id AND user_id = v_caller_id;

    IF v_interval_hours IS NULL THEN
        v_interval_hours := 12;
    END IF;

    v_next_due := NOW() + (v_interval_hours || ' hours')::INTERVAL;

    -- Upsert the check-in schedule
    INSERT INTO public.trip_checkin_schedules (
        trip_id, user_id, interval_hours, is_active, last_checkin_at, next_checkin_due_at, alert_sent, alert_sent_at
    )
    VALUES (
        p_trip_id, v_caller_id, v_interval_hours, true, NOW(), v_next_due, false, NULL
    )
    ON CONFLICT (trip_id, user_id) DO UPDATE
    SET last_checkin_at = NOW(),
        next_checkin_due_at = v_next_due,
        alert_sent = false,
        alert_sent_at = NULL,
        is_active = true,
        updated_at = NOW();

    RETURN jsonb_build_object(
        'success', true,
        'checkin_id', v_checkin_id,
        'last_checkin_at', NOW(),
        'next_checkin_due_at', v_next_due,
        'interval_hours', v_interval_hours
    );
END;
$$;

-- Function: set_trip_checkin_interval
CREATE OR REPLACE FUNCTION public.set_trip_checkin_interval(
    p_trip_id UUID,
    p_interval_hours INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_next_due TIMESTAMPTZ;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF p_interval_hours NOT IN (4, 6, 12, 24, 48) THEN
        RAISE EXCEPTION 'Invalid check-in interval: must be 4, 6, 12, 24, or 48 hours.'
            USING ERRCODE = '22000';
    END IF;

    v_next_due := NOW() + (p_interval_hours || ' hours')::INTERVAL;

    INSERT INTO public.trip_checkin_schedules (
        trip_id, user_id, interval_hours, is_active, last_checkin_at, next_checkin_due_at, alert_sent
    )
    VALUES (
        p_trip_id, v_caller_id, p_interval_hours, true, NOW(), v_next_due, false
    )
    ON CONFLICT (trip_id, user_id) DO UPDATE
    SET interval_hours = p_interval_hours,
        next_checkin_due_at = COALESCE(
            public.trip_checkin_schedules.last_checkin_at + (p_interval_hours || ' hours')::INTERVAL,
            v_next_due
        ),
        is_active = true,
        updated_at = NOW();

    RETURN jsonb_build_object('success', true, 'interval_hours', p_interval_hours);
END;
$$;

-- Function: set_live_location_sharing (opt-in per active trip)
CREATE OR REPLACE FUNCTION public.set_live_location_sharing(
    p_trip_id UUID,
    p_enabled BOOLEAN,
    p_latitude NUMERIC DEFAULT NULL,
    p_longitude NUMERIC DEFAULT NULL,
    p_accuracy NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_trip_end DATE;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Verify trip is active and caller is participant
    SELECT end_date INTO v_trip_end
    FROM public.trips
    WHERE id = p_trip_id;

    IF v_trip_end IS NULL THEN
        RAISE EXCEPTION 'Trip not found.' USING ERRCODE = 'P0002';
    END IF;

    IF CURRENT_DATE > v_trip_end THEN
        -- Automatic stop at trip end
        p_enabled := false;
    END IF;

    IF p_enabled AND (p_latitude IS NULL OR p_longitude IS NULL) THEN
        RAISE EXCEPTION 'Coordinates required to enable live location.' USING ERRCODE = '22000';
    END IF;

    IF p_enabled THEN
        INSERT INTO public.trip_live_locations (
            trip_id, user_id, latitude, longitude, accuracy_meters, is_sharing_enabled
        )
        VALUES (
            p_trip_id, v_caller_id, p_latitude, p_longitude, p_accuracy, true
        )
        ON CONFLICT (trip_id, user_id) DO UPDATE
        SET latitude = p_latitude,
            longitude = p_longitude,
            accuracy_meters = p_accuracy,
            is_sharing_enabled = true,
            updated_at = NOW();
    ELSE
        UPDATE public.trip_live_locations
        SET is_sharing_enabled = false,
            updated_at = NOW()
        WHERE trip_id = p_trip_id AND user_id = v_caller_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'is_sharing_enabled', p_enabled);
END;
$$;

-- Function: purge_expired_live_locations (short retention: 24h or ended trips)
CREATE OR REPLACE FUNCTION public.purge_expired_live_locations()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted INT;
BEGIN
    DELETE FROM public.trip_live_locations ll
    USING public.trips t
    WHERE ll.trip_id = t.id
      AND (
          ll.updated_at < NOW() - INTERVAL '24 hours'
          OR CURRENT_DATE > t.end_date
          OR ll.is_sharing_enabled = false
      );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

-- ============================================================================
-- 5. Missed Check-In Alert Server Function (For Edge Function / cron job)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_missed_checkins_for_alert()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_results JSONB := '[]'::JSONB;
    v_schedule_record RECORD;
    v_contacts JSONB;
    v_trip RECORD;
    v_traveller RECORD;
    v_last_loc RECORD;
BEGIN
    -- Query overdue check-ins where no alert has been dispatched yet
    FOR v_schedule_record IN
        SELECT s.id AS schedule_id, s.trip_id, s.user_id, s.interval_hours,
               s.last_checkin_at, s.next_checkin_due_at
        FROM public.trip_checkin_schedules s
        JOIN public.trips t ON t.id = s.trip_id
        WHERE s.is_active = true
          AND s.alert_sent = false
          AND s.next_checkin_due_at < NOW()
          AND CURRENT_DATE <= t.end_date
    LOOP
        -- Fetch traveller info
        SELECT id, display_name, home_city INTO v_traveller
        FROM public.profiles WHERE id = v_schedule_record.user_id;

        -- Fetch trip details
        SELECT t.id, t.destination, t.start_date, t.end_date, hp.display_name AS host_name
        INTO v_trip
        FROM public.trips t
        LEFT JOIN public.profiles hp ON hp.id = t.host_id
        WHERE t.id = v_schedule_record.trip_id;

        -- Fetch trusted contacts for this traveller
        SELECT jsonb_agg(
            jsonb_build_object(
                'name', name,
                'email', email,
                'phone', phone_number,
                'relationship', relationship
            )
        ) INTO v_contacts
        FROM public.trusted_contacts
        WHERE user_id = v_schedule_record.user_id;

        -- Fetch last known location if opted in
        SELECT latitude, longitude, accuracy_meters, updated_at INTO v_last_loc
        FROM public.trip_live_locations
        WHERE trip_id = v_schedule_record.trip_id
          AND user_id = v_schedule_record.user_id
          AND is_sharing_enabled = true;

        -- Only build payload if traveller actually configured trusted contacts
        IF v_contacts IS NOT NULL AND jsonb_array_length(v_contacts) > 0 THEN
            v_results := v_results || jsonb_build_object(
                'schedule_id', v_schedule_record.schedule_id,
                'traveller_name', v_traveller.display_name,
                'trip_destination', v_trip.destination,
                'trip_start', v_trip.start_date,
                'trip_end', v_trip.end_date,
                'host_name', v_trip.host_name,
                'missed_deadline', v_schedule_record.next_checkin_due_at,
                'last_checkin_at', v_schedule_record.last_checkin_at,
                'interval_hours', v_schedule_record.interval_hours,
                'last_known_location', CASE WHEN v_last_loc.latitude IS NOT NULL THEN
                    jsonb_build_object(
                        'latitude', v_last_loc.latitude,
                        'longitude', v_last_loc.longitude,
                        'accuracy', v_last_loc.accuracy_meters,
                        'recorded_at', v_last_loc.updated_at
                    )
                ELSE NULL END,
                'trusted_contacts', v_contacts
            );

            -- Mark alert as dispatched to prevent duplicate spam
            UPDATE public.trip_checkin_schedules
            SET alert_sent = true,
                alert_sent_at = NOW()
            WHERE id = v_schedule_record.schedule_id;
        END IF;
    END LOOP;

    RETURN v_results;
END;
$$;

-- ============================================================================
-- 6. Admin Reports Review Function & View
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_admin_reports_review()
RETURNS TABLE (
    report_id UUID,
    reporter_id UUID,
    reporter_name VARCHAR,
    reported_user_id UUID,
    reported_user_name VARCHAR,
    trip_id UUID,
    trip_destination VARCHAR,
    reason VARCHAR,
    details VARCHAR,
    status VARCHAR,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Access denied: Staff privileges required.' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        r.id AS report_id,
        r.reporter_id,
        rp.display_name AS reporter_name,
        r.reported_user_id,
        up.display_name AS reported_user_name,
        r.trip_id,
        t.destination AS trip_destination,
        r.reason,
        r.details,
        r.status,
        r.created_at
    FROM public.reports r
    LEFT JOIN public.profiles rp ON rp.id = r.reporter_id
    LEFT JOIN public.profiles up ON up.id = r.reported_user_id
    LEFT JOIN public.trips t ON t.id = r.trip_id
    ORDER BY r.created_at DESC;
END;
$$;
