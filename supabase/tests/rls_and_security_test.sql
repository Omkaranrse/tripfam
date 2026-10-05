-- Test Script: supabase/tests/rls_and_security_test.sql
-- Description: Automated security and RLS verification test suite simulating User A and User B.
--              Validates permission boundaries, RLS filtering, trigger immutability locks,
--              and mutual blocking logic.
--
-- Execution: Run this in psql or Supabase SQL Editor.
-- Everything runs within a transaction that rolls back at the end.

BEGIN;

DO $$
DECLARE
    v_user_a UUID := '11111111-1111-1111-1111-111111111111';
    v_user_b UUID := '22222222-2222-2222-2222-222222222222';
    v_trip_b UUID;
    v_request_a UUID;
    v_rows_affected INT;
    v_count INT;
    v_err_caught BOOLEAN;
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'Starting TripMate Security & RLS Test Suite';
    RAISE NOTICE '=====================================================';

    -- ------------------------------------------------------------------------
    -- SETUP: Provision Simulated Users and Initial State as DB Superuser
    -- ------------------------------------------------------------------------
    -- Insert simulated auth.users if not present
    INSERT INTO auth.users (id, email, raw_user_meta_data)
    VALUES
        (v_user_a, 'user_a@test.com', '{"display_name": "Alice Traveler"}'::jsonb),
        (v_user_b, 'user_b@test.com', '{"display_name": "Bob Explorer"}'::jsonb)
    ON CONFLICT (id) DO NOTHING;

    -- Ensure profiles exist (via trigger or manual insert if trigger didn't run)
    INSERT INTO public.profiles (id, display_name, role, is_verified)
    VALUES
        (v_user_a, 'Alice Traveler', 'user', false),
        (v_user_b, 'Bob Explorer', 'user', false)
    ON CONFLICT (id) DO UPDATE SET
        display_name = EXCLUDED.display_name,
        role = 'user',
        is_verified = false;

    -- Insert User B's private trusted contact
    INSERT INTO public.trusted_contacts (id, user_id, name, relationship, phone_number)
    VALUES (gen_random_uuid(), v_user_b, 'Emergency Contact Bob', 'Sister', '+1234567890');

    -- Insert User B's verification request
    INSERT INTO public.verification_requests (id, user_id, selfie_storage_path, status)
    VALUES (gen_random_uuid(), v_user_b, 'verification-selfies/bob/selfie.jpg', 'pending');

    -- Insert User B's trip
    INSERT INTO public.trips (host_id, destination, start_date, end_date, max_members, description, status)
    VALUES (v_user_b, 'Tokyo, Japan', CURRENT_DATE + 30, CURRENT_DATE + 40, 4, 'Exploring Shinjuku and Kyoto', 'published')
    RETURNING id INTO v_trip_b;

    -- ------------------------------------------------------------------------
    -- TEST 1: User A CANNOT self-verify (is_verified immutability lock)
    -- ------------------------------------------------------------------------
    -- Switch context to authenticated User A
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_a::text, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
    SET LOCAL ROLE authenticated;

    v_err_caught := false;
    BEGIN
        UPDATE public.profiles
        SET is_verified = true
        WHERE id = v_user_a;
    EXCEPTION WHEN OTHERS THEN
        v_err_caught := true;
    END;

    IF NOT v_err_caught THEN
        RAISE EXCEPTION 'TEST 1 FAILED: User A was able to set is_verified = true!';
    END IF;
    RAISE NOTICE '✓ TEST 1 PASSED: Client is prevented from self-verifying.';

    -- ------------------------------------------------------------------------
    -- TEST 2: User A CANNOT escalate role to admin
    -- ------------------------------------------------------------------------
    v_err_caught := false;
    BEGIN
        UPDATE public.profiles
        SET role = 'admin'
        WHERE id = v_user_a;
    EXCEPTION WHEN OTHERS THEN
        v_err_caught := true;
    END;

    IF NOT v_err_caught THEN
        RAISE EXCEPTION 'TEST 2 FAILED: User A was able to escalate role to admin!';
    END IF;
    RAISE NOTICE '✓ TEST 2 PASSED: Client is prevented from modifying role.';

    -- ------------------------------------------------------------------------
    -- TEST 3: User A CANNOT edit User B''s profile
    -- ------------------------------------------------------------------------
    UPDATE public.profiles
    SET bio = 'Hacked by User A'
    WHERE id = v_user_b;
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected <> 0 THEN
        RAISE EXCEPTION 'TEST 3 FAILED: User A updated User B''s profile! Rows: %', v_rows_affected;
    END IF;
    RAISE NOTICE '✓ TEST 3 PASSED: User A cannot update User B''s profile (0 rows affected).';

    -- ------------------------------------------------------------------------
    -- TEST 4: User A CANNOT delete User B''s profile
    -- ------------------------------------------------------------------------
    DELETE FROM public.profiles
    WHERE id = v_user_b;
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected <> 0 THEN
        RAISE EXCEPTION 'TEST 4 FAILED: User A deleted User B''s profile!';
    END IF;
    RAISE NOTICE '✓ TEST 4 PASSED: User A cannot delete User B''s profile (0 rows affected).';

    -- ------------------------------------------------------------------------
    -- TEST 5: User A CANNOT read User B''s private trusted contacts
    -- ------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM public.trusted_contacts
    WHERE user_id = v_user_b;

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'TEST 5 FAILED: User A could see User B''s trusted contacts! Found: %', v_count;
    END IF;
    RAISE NOTICE '✓ TEST 5 PASSED: User A cannot read User B''s private trusted contacts.';

    -- ------------------------------------------------------------------------
    -- TEST 6: User A CANNOT read User B''s private verification requests
    -- ------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count
    FROM public.verification_requests
    WHERE user_id = v_user_b;

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'TEST 6 FAILED: User A could see User B''s verification requests! Found: %', v_count;
    END IF;
    RAISE NOTICE '✓ TEST 6 PASSED: User A cannot read User B''s verification requests.';

    -- ------------------------------------------------------------------------
    -- TEST 7: User A CANNOT modify or delete User B''s trip
    -- ------------------------------------------------------------------------
    UPDATE public.trips
    SET destination = 'User A Hijack'
    WHERE id = v_trip_b;
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected <> 0 THEN
        RAISE EXCEPTION 'TEST 7A FAILED: User A updated User B''s trip!';
    END IF;

    DELETE FROM public.trips
    WHERE id = v_trip_b;
    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected <> 0 THEN
        RAISE EXCEPTION 'TEST 7B FAILED: User A deleted User B''s trip!';
    END IF;
    RAISE NOTICE '✓ TEST 7 PASSED: User A cannot edit or delete User B''s trip.';

    -- ------------------------------------------------------------------------
    -- TEST 8: User A CANNOT accept requests for User B''s trip
    -- ------------------------------------------------------------------------
    -- User A submits join request to User B's trip
    INSERT INTO public.join_requests (trip_id, user_id, status, message)
    VALUES (v_trip_b, v_user_a, 'pending', 'Hey, I want to travel with you!')
    RETURNING id INTO v_request_a;

    -- User A attempts to call accept_join_request
    v_err_caught := false;
    BEGIN
        PERFORM public.accept_join_request(v_request_a);
    EXCEPTION WHEN OTHERS THEN
        v_err_caught := true;
    END;

    IF NOT v_err_caught THEN
        RAISE EXCEPTION 'TEST 8 FAILED: User A was able to accept a request on User B''s trip!';
    END IF;
    RAISE NOTICE '✓ TEST 8 PASSED: Only the host can accept join requests.';

    -- ------------------------------------------------------------------------
    -- TEST 9: Chat messages blocked until intro call confirmed by both parties
    -- ------------------------------------------------------------------------
    -- User A attempts to send message before acceptance/call
    v_err_caught := false;
    BEGIN
        INSERT INTO public.messages (trip_id, sender_id, content)
        VALUES (v_trip_b, v_user_a, 'Premature message');
    EXCEPTION WHEN OTHERS THEN
        v_err_caught := true;
    END;

    IF NOT v_err_caught THEN
        -- Also check if row was actually created (RLS WITH CHECK violation should fail)
        SELECT COUNT(*) INTO v_count
        FROM public.messages
        WHERE trip_id = v_trip_b AND sender_id = v_user_a;

        IF v_count <> 0 THEN
            RAISE EXCEPTION 'TEST 9 FAILED: User A was able to message without unlocked chat!';
        END IF;
    END IF;
    RAISE NOTICE '✓ TEST 9 PASSED: Messages are locked until intro call confirmed.';

    -- ------------------------------------------------------------------------
    -- TEST 10: Mutual blocking hides profiles and trips
    -- ------------------------------------------------------------------------
    -- Reset to superuser temporarily to simulate User B blocking User A
    RESET ROLE;
    INSERT INTO public.blocks (blocker_id, blocked_id)
    VALUES (v_user_b, v_user_a);

    -- Switch back to User A
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_a::text, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

    -- User A should no longer see User B's profile
    SELECT COUNT(*) INTO v_count
    FROM public.profiles
    WHERE id = v_user_b;

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'TEST 10A FAILED: Blocked user can still view profile!';
    END IF;

    -- User A should no longer see User B's trips
    SELECT COUNT(*) INTO v_count
    FROM public.trips
    WHERE id = v_trip_b;

    IF v_count <> 0 THEN
        RAISE EXCEPTION 'TEST 10B FAILED: Blocked user can still view trips!';
    END IF;
    RAISE NOTICE '✓ TEST 10 PASSED: Mutual blocking successfully hides profiles and trips.';

    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'ALL SECURITY & RLS TESTS PASSED SUCCESSFULLY!';
    RAISE NOTICE '=====================================================';
END;
$$;

-- Rollback entire test transaction so no dummy data persists
ROLLBACK;
