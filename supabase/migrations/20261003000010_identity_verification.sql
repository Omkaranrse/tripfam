-- Migration: 20261003000010_identity_verification.sql
-- Description: Identity verification review workflow (approve/reject with audit logs,
--              auto-deletion of selfies after review, verified-only trip gating,
--              and staff queue function).

-- ============================================================================
-- 1. Audit Logs Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NOT NULL,
    target_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_logs_select_policy" ON public.audit_logs;
CREATE POLICY "audit_logs_select_policy"
    ON public.audit_logs
    FOR SELECT
    TO authenticated
    USING (public.is_staff(auth.uid()));

-- ============================================================================
-- 2. Verified-Only Trip Gating
-- ============================================================================

-- Add requires_verified_members flag to trips
ALTER TABLE public.trips
    ADD COLUMN IF NOT EXISTS requires_verified_members BOOLEAN NOT NULL DEFAULT false;

-- Trigger: Enforce that only verified users can request to join verified-only trips
CREATE OR REPLACE FUNCTION public.check_join_request_verification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_requires_verified BOOLEAN;
    v_is_verified BOOLEAN;
BEGIN
    SELECT requires_verified_members INTO v_requires_verified
    FROM public.trips WHERE id = NEW.trip_id;

    IF v_requires_verified = true THEN
        SELECT is_verified INTO v_is_verified
        FROM public.profiles WHERE id = NEW.user_id;

        IF v_is_verified IS NOT TRUE THEN
            RAISE EXCEPTION 'This trip requires verified travellers. Please complete profile verification first.'
                USING ERRCODE = '22000';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_join_request_verification ON public.join_requests;
CREATE TRIGGER trg_check_join_request_verification
    BEFORE INSERT ON public.join_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.check_join_request_verification();

-- ============================================================================
-- 3. Verification Request Submission Function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.submit_verification_request(
    p_selfie_storage_path TEXT,
    p_instruction_completed VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_request_id UUID;
    v_existing_status VARCHAR;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Check if already verified
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_caller_id AND is_verified = true) THEN
        RAISE EXCEPTION 'Your profile is already verified.' USING ERRCODE = '22000';
    END IF;

    -- Check if already has a pending request
    SELECT status INTO v_existing_status
    FROM public.verification_requests
    WHERE user_id = v_caller_id AND status = 'pending'
    LIMIT 1;

    IF v_existing_status = 'pending' THEN
        RAISE EXCEPTION 'You already have a verification request pending review.' USING ERRCODE = '22000';
    END IF;

    INSERT INTO public.verification_requests (
        user_id, selfie_storage_path, status, reviewer_notes
    )
    VALUES (
        v_caller_id,
        p_selfie_storage_path,
        'pending',
        CASE WHEN p_instruction_completed IS NOT NULL
             THEN 'Live instruction completed: ' || p_instruction_completed
             ELSE NULL END
    )
    RETURNING id INTO v_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_request_id,
        'status', 'pending'
    );
END;
$$;

-- ============================================================================
-- 4. Admin Verification Approval Function (Security Definer with role check)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.approve_verification_request(
    p_request_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_user_id UUID;
    v_selfie_path TEXT;
    v_status VARCHAR;
BEGIN
    -- Strict authorization check: caller must be admin or staff
    IF v_caller_id IS NULL OR NOT public.is_staff(v_caller_id) THEN
        RAISE EXCEPTION 'Permission denied: Admin privileges required.' USING ERRCODE = '42501';
    END IF;

    SELECT user_id, selfie_storage_path, status
    INTO v_user_id, v_selfie_path, v_status
    FROM public.verification_requests
    WHERE id = p_request_id;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Verification request not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_status <> 'pending' THEN
        RAISE EXCEPTION 'Cannot approve request with status "%".', v_status USING ERRCODE = '22000';
    END IF;

    -- Update profile to verified
    UPDATE public.profiles
    SET is_verified = true,
        updated_at = NOW()
    WHERE id = v_user_id;

    -- Update request status
    UPDATE public.verification_requests
    SET status = 'approved',
        reviewer_notes = COALESCE(p_notes, 'Verified by review'),
        updated_at = NOW()
    WHERE id = p_request_id;

    -- Write audit log entry
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, details)
    VALUES (
        v_caller_id,
        'approve_verification',
        'profile',
        v_user_id,
        jsonb_build_object('request_id', p_request_id, 'notes', p_notes)
    );

    -- Auto-delete selfie after review for privacy
    IF v_selfie_path IS NOT NULL THEN
        DELETE FROM storage.objects
        WHERE bucket_id = 'verification-selfies' AND name = v_selfie_path;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'status', 'approved'
    );
END;
$$;

-- ============================================================================
-- 5. Admin Verification Rejection Function
-- ============================================================================

CREATE OR REPLACE FUNCTION public.reject_verification_request(
    p_request_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_user_id UUID;
    v_selfie_path TEXT;
    v_status VARCHAR;
BEGIN
    IF v_caller_id IS NULL OR NOT public.is_staff(v_caller_id) THEN
        RAISE EXCEPTION 'Permission denied: Admin privileges required.' USING ERRCODE = '42501';
    END IF;

    IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
        RAISE EXCEPTION 'A rejection reason is required.' USING ERRCODE = '22000';
    END IF;

    SELECT user_id, selfie_storage_path, status
    INTO v_user_id, v_selfie_path, v_status
    FROM public.verification_requests
    WHERE id = p_request_id;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Verification request not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Update request status
    UPDATE public.verification_requests
    SET status = 'rejected',
        reviewer_notes = trim(p_reason),
        updated_at = NOW()
    WHERE id = p_request_id;

    -- Write audit log entry
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, details)
    VALUES (
        v_caller_id,
        'reject_verification',
        'profile',
        v_user_id,
        jsonb_build_object('request_id', p_request_id, 'reason', p_reason)
    );

    -- Auto-delete selfie after review
    IF v_selfie_path IS NOT NULL THEN
        DELETE FROM storage.objects
        WHERE bucket_id = 'verification-selfies' AND name = v_selfie_path;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'status', 'rejected'
    );
END;
$$;

-- ============================================================================
-- 6. User Verification Status & Admin Review Queue Functions
-- ============================================================================

-- Function: get_user_verification_status
CREATE OR REPLACE FUNCTION public.get_user_verification_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_is_verified BOOLEAN;
    v_req RECORD;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('status', 'not_submitted', 'is_verified', false);
    END IF;

    SELECT is_verified INTO v_is_verified
    FROM public.profiles WHERE id = v_caller_id;

    IF v_is_verified = true THEN
        RETURN jsonb_build_object(
            'status', 'verified',
            'is_verified', true
        );
    END IF;

    SELECT id, status, reviewer_notes, created_at
    INTO v_req
    FROM public.verification_requests
    WHERE user_id = v_caller_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_req.id IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'not_submitted',
            'is_verified', false
        );
    END IF;

    RETURN jsonb_build_object(
        'request_id', v_req.id,
        'status', v_req.status,
        'rejection_reason', CASE WHEN v_req.status = 'rejected' THEN v_req.reviewer_notes ELSE NULL END,
        'is_verified', false,
        'created_at', v_req.created_at
    );
END;
$$;

-- Function: get_admin_verification_queue
CREATE OR REPLACE FUNCTION public.get_admin_verification_queue()
RETURNS TABLE (
    request_id UUID,
    user_id UUID,
    display_name VARCHAR,
    avatar_path TEXT,
    selfie_storage_path TEXT,
    reviewer_notes VARCHAR,
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
        vr.id AS request_id,
        vr.user_id,
        p.display_name,
        p.avatar_path,
        vr.selfie_storage_path,
        vr.reviewer_notes,
        vr.created_at
    FROM public.verification_requests vr
    JOIN public.profiles p ON p.id = vr.user_id
    WHERE vr.status = 'pending'
    ORDER BY vr.created_at ASC;
END;
$$;
