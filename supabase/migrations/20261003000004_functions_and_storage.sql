-- Migration: 20261003000004_functions_and_storage.sql
-- Description: Business logic database functions (request acceptance with capacity check,
--              intro call confirmation, chat unlocking) and private storage buckets
--              with RLS policies and MIME/size limits.

-- ============================================================================
-- 1. Database Functions
-- ============================================================================

-- Function: accept_join_request
-- Accepts a pending request, verifies trip capacity, and inserts member
CREATE OR REPLACE FUNCTION public.accept_join_request(p_request_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_trip_id UUID;
    v_user_id UUID;
    v_host_id UUID;
    v_status VARCHAR;
    v_max_members INT;
    v_current_count INT;
    v_caller_id UUID := auth.uid();
    v_intro_call_id UUID;
BEGIN
    -- Fetch request details
    SELECT jr.trip_id, jr.user_id, jr.status, t.host_id, t.max_members
    INTO v_trip_id, v_user_id, v_status, v_host_id, v_max_members
    FROM public.join_requests jr
    JOIN public.trips t ON t.id = jr.trip_id
    WHERE jr.id = p_request_id;

    IF v_trip_id IS NULL THEN
        RAISE EXCEPTION 'Join request not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Verify caller is the trip host or admin
    IF v_caller_id IS NOT NULL AND v_caller_id <> v_host_id AND NOT public.is_staff(v_caller_id) THEN
        RAISE EXCEPTION 'Only the trip host can accept join requests.' USING ERRCODE = '42501';
    END IF;

    -- Ensure request is in pending state
    IF v_status <> 'pending' THEN
        RAISE EXCEPTION 'Cannot accept request with status "%".', v_status USING ERRCODE = '22000';
    END IF;

    -- Check current trip membership count (including host)
    SELECT COUNT(*) INTO v_current_count
    FROM public.trip_members
    WHERE trip_id = v_trip_id;

    IF v_current_count >= v_max_members THEN
        RAISE EXCEPTION 'Trip capacity limit of % members has been reached.', v_max_members
            USING ERRCODE = '22000';
    END IF;

    -- Update request status to accepted
    UPDATE public.join_requests
    SET status = 'accepted'
    WHERE id = p_request_id;

    -- Add user to trip_members if not already a member
    INSERT INTO public.trip_members (trip_id, user_id, role, joined_at)
    VALUES (v_trip_id, v_user_id, 'member', NOW())
    ON CONFLICT (trip_id, user_id) DO NOTHING;

    -- Automatically provision an intro call schedule record if not already present
    INSERT INTO public.intro_calls (request_id)
    VALUES (p_request_id)
    ON CONFLICT (request_id) DO NOTHING
    RETURNING id INTO v_intro_call_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', p_request_id,
        'trip_id', v_trip_id,
        'user_id', v_user_id,
        'status', 'accepted',
        'current_members', v_current_count + 1,
        'max_members', v_max_members
    );
END;
$$;

-- Function: confirm_intro_call
-- Sets confirmation for host or traveller, and checks if mutual confirmation is reached
CREATE OR REPLACE FUNCTION public.confirm_intro_call(p_intro_call_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request_id UUID;
    v_trip_id UUID;
    v_traveller_id UUID;
    v_host_id UUID;
    v_host_confirmed BOOLEAN;
    v_traveller_confirmed BOOLEAN;
    v_caller_id UUID := auth.uid();
    v_chat_unlocked BOOLEAN;
BEGIN
    SELECT ic.request_id, ic.host_confirmed, ic.traveller_confirmed,
           jr.trip_id, jr.user_id, t.host_id
    INTO v_request_id, v_host_confirmed, v_traveller_confirmed,
         v_trip_id, v_traveller_id, v_host_id
    FROM public.intro_calls ic
    JOIN public.join_requests jr ON jr.id = ic.request_id
    JOIN public.trips t ON t.id = jr.trip_id
    WHERE ic.id = p_intro_call_id;

    IF v_request_id IS NULL THEN
        RAISE EXCEPTION 'Intro call record not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Determine which participant is confirming
    IF v_caller_id = v_host_id THEN
        v_host_confirmed := true;
    ELSIF v_caller_id = v_traveller_id THEN
        v_traveller_confirmed := true;
    ELSIF public.is_staff(v_caller_id) THEN
        -- Staff override can confirm both
        v_host_confirmed := true;
        v_traveller_confirmed := true;
    ELSE
        RAISE EXCEPTION 'Permission denied: Caller is neither the host nor traveller.'
            USING ERRCODE = '42501';
    END IF;

    -- Update the intro call state
    UPDATE public.intro_calls
    SET host_confirmed = v_host_confirmed,
        traveller_confirmed = v_traveller_confirmed
    WHERE id = p_intro_call_id;

    v_chat_unlocked := (v_host_confirmed AND v_traveller_confirmed);

    RETURN jsonb_build_object(
        'intro_call_id', p_intro_call_id,
        'trip_id', v_trip_id,
        'host_confirmed', v_host_confirmed,
        'traveller_confirmed', v_traveller_confirmed,
        'chat_unlocked', v_chat_unlocked
    );
END;
$$;

-- Function: unlock_trip_chat
-- Allows checking status or explicitly confirming pre-conditions for trip chat access
CREATE OR REPLACE FUNCTION public.unlock_trip_chat(p_trip_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_can_access BOOLEAN;
BEGIN
    v_can_access := public.has_unlocked_chat(p_trip_id, p_user_id);
    RETURN v_can_access;
END;
$$;

-- ============================================================================
-- 2. Storage Buckets (Private, with File Size & MIME constraints)
-- ============================================================================

-- Create 'avatars' bucket (Private, max 5MB, images only)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    false,
    5242880, -- 5 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- Create 'verification-selfies' bucket (Private, max 10MB, images only)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'verification-selfies',
    'verification-selfies',
    false,
    10485760, -- 10 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- ============================================================================
-- 3. Storage Object RLS Policies
-- ============================================================================

-- AVATARS POLICIES
-- Select: Any authenticated user can view avatar files unless blocked by owner
CREATE POLICY "avatars_select_policy"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR NOT public.is_blocked_mutually(auth.uid(), ((storage.foldername(name))[1])::uuid)
        )
    );

-- Insert: Users upload only to their own directory: avatars/<user_id>/...
CREATE POLICY "avatars_insert_policy"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Update: Users manage only their own avatar files
CREATE POLICY "avatars_update_policy"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Delete: Users delete only their own avatar files
CREATE POLICY "avatars_delete_policy"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- VERIFICATION-SELFIES POLICIES
-- Select: Only the user themselves or staff/moderator
CREATE POLICY "verification_selfies_select_policy"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'verification-selfies'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.is_staff(auth.uid())
        )
    );

-- Insert: Users upload only into their own folder: verification-selfies/<user_id>/...
CREATE POLICY "verification_selfies_insert_policy"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'verification-selfies'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Delete: Only user before approval or staff
CREATE POLICY "verification_selfies_delete_policy"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'verification-selfies'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.is_staff(auth.uid())
        )
    );
