-- Migration: 20261003000007_join_requests_and_intro_call.sql
-- Description: Business logic, rate-limiting, and validation for Phase 5 (Join Requests & Intro Calls).

-- ============================================================================
-- 1. Rate Limiting for Join Requests
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_join_request_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recent_count INT;
    v_daily_limit CONSTANT INT := 10;
BEGIN
    SELECT COUNT(*) INTO v_recent_count
    FROM public.join_requests
    WHERE user_id = NEW.user_id
      AND created_at >= NOW() - INTERVAL '24 hours';

    IF v_recent_count >= v_daily_limit THEN
        RAISE EXCEPTION 'Daily join request limit reached (% requests per 24 hours). Please try again tomorrow.', v_daily_limit
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_join_request_rate_limit ON public.join_requests;

CREATE TRIGGER trg_check_join_request_rate_limit
    BEFORE INSERT ON public.join_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.check_join_request_rate_limit();

-- ============================================================================
-- 2. Meeting Link Format Validation Constraint
-- ============================================================================
-- Accept only https links from Google Meet, Zoom, or WhatsApp
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_valid_meeting_link'
    ) THEN
        ALTER TABLE public.intro_calls
        ADD CONSTRAINT chk_valid_meeting_link
        CHECK (
            meeting_link IS NULL
            OR meeting_link ~* '^https://([a-zA-Z0-9-]+\.)?(meet\.google\.com|zoom\.us|call\.whatsapp\.com|chat\.whatsapp\.com)/.+'
        );
    END IF;
END $$;

-- ============================================================================
-- 3. Schedule Intro Call Function
-- ============================================================================
CREATE OR REPLACE FUNCTION public.schedule_intro_call(
    p_intro_call_id UUID,
    p_scheduled_at TIMESTAMPTZ,
    p_meeting_link TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_host_id UUID;
    v_traveller_id UUID;
    v_trip_id UUID;
    v_request_status VARCHAR;
BEGIN
    -- Verify intro call exists and fetch participants
    SELECT t.host_id, jr.user_id, jr.trip_id, jr.status
    INTO v_host_id, v_traveller_id, v_trip_id, v_request_status
    FROM public.intro_calls ic
    JOIN public.join_requests jr ON jr.id = ic.request_id
    JOIN public.trips t ON t.id = jr.trip_id
    WHERE ic.id = p_intro_call_id;

    IF v_host_id IS NULL THEN
        RAISE EXCEPTION 'Intro call record not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Only host or traveller (or staff) can schedule
    IF v_caller_id IS NOT NULL AND v_caller_id <> v_host_id AND v_caller_id <> v_traveller_id AND NOT public.is_staff(v_caller_id) THEN
        RAISE EXCEPTION 'Only the host or applicant can schedule this intro call.' USING ERRCODE = '42501';
    END IF;

    -- Join request must be accepted
    IF v_request_status <> 'accepted' THEN
        RAISE EXCEPTION 'Cannot schedule intro call for request with status "%".', v_request_status USING ERRCODE = '22000';
    END IF;

    -- Validate scheduled time is in future (or within 5 minutes grace period)
    IF p_scheduled_at < NOW() - INTERVAL '5 minutes' THEN
        RAISE EXCEPTION 'Scheduled call time must be in the future.' USING ERRCODE = '22000';
    END IF;

    -- Validate meeting link protocol and domain
    IF p_meeting_link !~* '^https://([a-zA-Z0-9-]+\.)?(meet\.google\.com|zoom\.us|call\.whatsapp\.com|chat\.whatsapp\.com)/.+' THEN
        RAISE EXCEPTION 'Invalid meeting link. Please provide a valid HTTPS link from Google Meet, Zoom, or WhatsApp.' USING ERRCODE = '22000';
    END IF;

    -- Update intro call details; reset confirmations if time/link changed
    UPDATE public.intro_calls
    SET scheduled_at = p_scheduled_at,
        meeting_link = TRIM(p_meeting_link),
        host_confirmed = false,
        traveller_confirmed = false,
        updated_at = NOW()
    WHERE id = p_intro_call_id;

    RETURN jsonb_build_object(
        'success', true,
        'intro_call_id', p_intro_call_id,
        'scheduled_at', p_scheduled_at,
        'meeting_link', TRIM(p_meeting_link),
        'trip_id', v_trip_id
    );
END;
$$;

-- ============================================================================
-- 4. Decline Join Request Function (Host Only)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.decline_join_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_host_id UUID;
    v_status VARCHAR;
BEGIN
    SELECT t.host_id, jr.status
    INTO v_host_id, v_status
    FROM public.join_requests jr
    JOIN public.trips t ON t.id = jr.trip_id
    WHERE jr.id = p_request_id;

    IF v_host_id IS NULL THEN
        RAISE EXCEPTION 'Join request not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_caller_id <> v_host_id AND NOT public.is_staff(v_caller_id) THEN
        RAISE EXCEPTION 'Only the trip host can decline join requests.' USING ERRCODE = '42501';
    END IF;

    IF v_status <> 'pending' THEN
        RAISE EXCEPTION 'Cannot decline request with status "%".', v_status USING ERRCODE = '22000';
    END IF;

    UPDATE public.join_requests
    SET status = 'declined',
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'request_id', p_request_id, 'status', 'declined');
END;
$$;

-- ============================================================================
-- 5. Cancel Join Request Function (Requester Only)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cancel_join_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_user_id UUID;
    v_status VARCHAR;
BEGIN
    SELECT jr.user_id, jr.status
    INTO v_user_id, v_status
    FROM public.join_requests jr
    WHERE jr.id = p_request_id;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Join request not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_caller_id IS NOT NULL AND v_caller_id <> v_user_id AND NOT public.is_staff(v_caller_id) THEN
        RAISE EXCEPTION 'Only the requester can cancel their request.' USING ERRCODE = '42501';
    END IF;

    IF v_status IN ('declined', 'cancelled') THEN
        RAISE EXCEPTION 'Request is already "%".', v_status USING ERRCODE = '22000';
    END IF;

    UPDATE public.join_requests
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_request_id;

    RETURN jsonb_build_object('success', true, 'request_id', p_request_id, 'status', 'cancelled');
END;
$$;
