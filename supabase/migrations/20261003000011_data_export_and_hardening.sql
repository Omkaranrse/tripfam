-- Migration: 20261003000011_data_export_and_hardening.sql
-- Description: Privacy data export RPC, schema hardening, and security definitions.

-- ============================================================================
-- 1. Privacy Data Export Function (GDPR / CCPA Right to Portability)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.export_user_data()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile JSONB;
    v_trips JSONB;
    v_requests JSONB;
    v_messages JSONB;
    v_contacts JSONB;
    v_checkins JSONB;
    v_verifications JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to export data.' USING ERRCODE = '42501';
    END IF;

    -- 1. User Profile
    SELECT to_jsonb(p) INTO v_profile
    FROM public.profiles p
    WHERE p.id = v_user_id;

    -- 2. Trips hosted by user
    SELECT COALESCE(jsonb_agg(to_jsonb(t)), '[]'::jsonb) INTO v_trips
    FROM public.trips t
    WHERE t.host_id = v_user_id;

    -- 3. Join requests submitted by user
    SELECT COALESCE(jsonb_agg(to_jsonb(jr)), '[]'::jsonb) INTO v_requests
    FROM public.join_requests jr
    WHERE jr.user_id = v_user_id;

    -- 4. Messages authored by user (sanitized, excluding others' private data)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', m.id,
        'trip_id', m.trip_id,
        'content', m.content,
        'created_at', m.created_at
    )), '[]'::jsonb) INTO v_messages
    FROM public.messages m
    WHERE m.user_id = v_user_id;

    -- 5. Trusted Contacts
    SELECT COALESCE(jsonb_agg(to_jsonb(tc)), '[]'::jsonb) INTO v_contacts
    FROM public.trusted_contacts tc
    WHERE tc.user_id = v_user_id;

    -- 6. Check-ins
    SELECT COALESCE(jsonb_agg(to_jsonb(c)), '[]'::jsonb) INTO v_checkins
    FROM public.checkins c
    WHERE c.user_id = v_user_id;

    -- 7. Verification request history (excluding internal reviewer secrets)
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', vr.id,
        'status', vr.status,
        'created_at', vr.created_at,
        'reviewer_notes', vr.reviewer_notes
    )), '[]'::jsonb) INTO v_verifications
    FROM public.verification_requests vr
    WHERE vr.user_id = v_user_id;

    -- Log export event in audit logs for compliance tracking
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, details)
    VALUES (
        v_user_id,
        'data_export',
        'profile',
        v_user_id,
        jsonb_build_object('exported_at', NOW())
    );

    RETURN jsonb_build_object(
        'exported_at', NOW(),
        'app_version', '1.0.0',
        'profile', v_profile,
        'trips_hosted', v_trips,
        'join_requests', v_requests,
        'sent_messages', v_messages,
        'trusted_contacts', v_contacts,
        'checkins', v_checkins,
        'verification_records', v_verifications
    );
END;
$$;

-- Revoke execute from public/anon, grant only to authenticated users
REVOKE EXECUTE ON FUNCTION public.export_user_data() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.export_user_data() FROM anon;
GRANT EXECUTE ON FUNCTION public.export_user_data() TO authenticated;
