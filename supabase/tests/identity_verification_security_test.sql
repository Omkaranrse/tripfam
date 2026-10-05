-- ============================================================================
-- TripFam Phase 8: Identity Verification Security & Authorization Test Script
-- Run in Supabase SQL Editor to verify DB function guards and RLS policies
-- ============================================================================

DO $$
DECLARE
    v_admin_id UUID := gen_random_uuid();
    v_user_normal UUID := gen_random_uuid();
    v_user_applicant UUID := gen_random_uuid();
    v_trip_id UUID := gen_random_uuid();
    v_req_id UUID;
    v_failed_as_expected BOOLEAN := false;
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'Starting Phase 8 Identity Verification Security Tests';
    RAISE NOTICE '==================================================';

    -- 1. Setup mock profiles
    INSERT INTO public.profiles (id, display_name, role, is_verified)
    VALUES
        (v_admin_id, 'Admin User', 'admin', true),
        (v_user_normal, 'Normal User', 'member', false),
        (v_user_applicant, 'Applicant User', 'member', false);

    -- 2. Setup mock trip with verified gating
    INSERT INTO public.trips (id, host_id, destination, start_date, end_date, budget, max_members, description, requires_verified_members)
    VALUES (v_trip_id, v_admin_id, 'Kyoto Zen Retreat', CURRENT_DATE + 10, CURRENT_DATE + 18, 1200, 4, 'Verified members only trip', true);

    -- 3. Setup mock verification request
    INSERT INTO public.verification_requests (id, user_id, selfie_storage_path, status, reviewer_notes)
    VALUES (gen_random_uuid(), v_user_applicant, 'verification-selfies/mock_selfie.jpg', 'pending', 'Live instruction: Turn head left')
    RETURNING id INTO v_req_id;

    -- ========================================================================
    -- TEST 1: Normal user cannot call approve_verification_request
    -- ========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_normal::text)::text, true);

    BEGIN
        PERFORM public.approve_verification_request(v_req_id, 'Illegal approval attempt');
        v_failed_as_expected := false;
    EXCEPTION WHEN OTHERS THEN
        v_failed_as_expected := true;
        RAISE NOTICE 'SUCCESS [Test 1]: Normal user blocked from approve_verification_request (% - %)', SQLSTATE, SQLERRM;
    END;

    IF NOT v_failed_as_expected THEN
        RAISE EXCEPTION 'SECURITY BREACH: Normal user was able to execute approve_verification_request!';
    END IF;

    -- ========================================================================
    -- TEST 2: Normal user cannot view admin verification queue
    -- ========================================================================
    v_failed_as_expected := false;
    BEGIN
        PERFORM * FROM public.get_admin_verification_queue();
    EXCEPTION WHEN OTHERS THEN
        v_failed_as_expected := true;
        RAISE NOTICE 'SUCCESS [Test 2]: Normal user blocked from get_admin_verification_queue (% - %)', SQLSTATE, SQLERRM;
    END;

    IF NOT v_failed_as_expected THEN
        RAISE EXCEPTION 'SECURITY BREACH: Normal user was able to access get_admin_verification_queue!';
    END IF;

    -- ========================================================================
    -- TEST 3: Unverified user cannot submit join request to verified-gated trip
    -- ========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_applicant::text)::text, true);

    v_failed_as_expected := false;
    BEGIN
        INSERT INTO public.join_requests (trip_id, user_id, stage, status)
        VALUES (v_trip_id, v_user_applicant, 'requested', 'pending');
    EXCEPTION WHEN OTHERS THEN
        v_failed_as_expected := true;
        RAISE NOTICE 'SUCCESS [Test 3]: Unverified user blocked from joining verified-only trip (% - %)', SQLSTATE, SQLERRM;
    END;

    IF NOT v_failed_as_expected THEN
        RAISE EXCEPTION 'SECURITY BREACH: Unverified user was able to submit join request to verified-gated trip!';
    END IF;

    -- ========================================================================
    -- TEST 4: Admin can approve, setting is_verified and creating audit log
    -- ========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin_id::text)::text, true);

    PERFORM public.approve_verification_request(v_req_id, 'Live selfie matches profile photo.');

    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_user_applicant AND is_verified = true) THEN
        RAISE EXCEPTION 'FAILED: Applicant profile was not marked as is_verified!';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'approve_verification' AND target_id = v_user_applicant) THEN
        RAISE EXCEPTION 'FAILED: Audit log was not written upon verification approval!';
    END IF;

    RAISE NOTICE 'SUCCESS [Test 4]: Admin approved applicant, profile updated to is_verified=true, and audit log created.';

    -- ========================================================================
    -- TEST 5: Now that applicant is verified, they can request to join trip
    -- ========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_applicant::text)::text, true);

    INSERT INTO public.join_requests (trip_id, user_id, stage, status)
    VALUES (v_trip_id, v_user_applicant, 'requested', 'pending');

    RAISE NOTICE 'SUCCESS [Test 5]: Newly verified applicant successfully submitted join request.';

    -- Cleanup test data
    DELETE FROM public.join_requests WHERE trip_id = v_trip_id;
    DELETE FROM public.audit_logs WHERE target_id = v_user_applicant;
    DELETE FROM public.verification_requests WHERE id = v_req_id;
    DELETE FROM public.trips WHERE id = v_trip_id;
    DELETE FROM public.profiles WHERE id IN (v_admin_id, v_user_normal, v_user_applicant);

    RAISE NOTICE '==================================================';
    RAISE NOTICE 'ALL PHASE 8 SECURITY TESTS PASSED SUCCESSFULLY!';
    RAISE NOTICE '==================================================';
END;
$$;
