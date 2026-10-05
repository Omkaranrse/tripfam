-- Migration: 20261003000002_profile_security_and_triggers.sql
-- Description: Automated profile provisioning on auth signup, and strict enforcement
--              preventing clients from self-verifying or changing their role.

-- ============================================================================
-- 1. Automatic Profile Provisioning on User Signup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_display_name TEXT;
    v_home_city TEXT;
BEGIN
    -- Extract display name from user metadata or fallback to email prefix or 'Traveler'
    v_display_name := NULLIF(TRIM(NEW.raw_user_meta_data->>'display_name'), '');
    IF v_display_name IS NULL THEN
        IF NEW.email IS NOT NULL AND POSITION('@' IN NEW.email) > 1 THEN
            v_display_name := SUBSTRING(NEW.email FROM 1 FOR POSITION('@' IN NEW.email) - 1);
        ELSE
            v_display_name := 'Traveler';
        END IF;
    END IF;

    -- Ensure display name meets minimum length
    IF char_length(v_display_name) < 2 THEN
        v_display_name := v_display_name || ' Wanderer';
    END IF;

    v_home_city := NULLIF(TRIM(NEW.raw_user_meta_data->>'home_city'), '');

    INSERT INTO public.profiles (
        id,
        display_name,
        bio,
        home_city,
        avatar_path,
        travel_style,
        is_verified,
        role
    ) VALUES (
        NEW.id,
        SUBSTRING(v_display_name FROM 1 FOR 60),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'bio'), ''),
        v_home_city,
        NULLIF(TRIM(NEW.raw_user_meta_data->>'avatar_path'), ''),
        COALESCE(NEW.raw_user_meta_data->'travel_style', '{}'::jsonb),
        false,  -- Never verified on signup
        'user'  -- Never elevated role on signup
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

-- Drop if previously attached to prevent duplicate trigger execution
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- 2. Strict Trigger: Prevent Client-Side Mutation of is_verified & role
-- ============================================================================
CREATE OR REPLACE FUNCTION public.enforce_profile_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_caller_role TEXT;
BEGIN
    -- Determine calling role (handles PostgREST JWT claims, auth.role(), or session role)
    v_caller_role := COALESCE(
        NULLIF(current_setting('request.jwt.claim.role', true), ''),
        NULLIF(auth.role(), ''),
        CURRENT_USER
    );

    -- If a client (authenticated or anon) attempts to modify is_verified or role, reject it
    IF v_caller_role IN ('authenticated', 'anon') THEN
        IF (NEW.is_verified IS DISTINCT FROM OLD.is_verified) THEN
            RAISE EXCEPTION 'Permission denied: Client cannot modify is_verified status.'
                USING ERRCODE = '42501';
        END IF;

        IF (NEW.role IS DISTINCT FROM OLD.role) THEN
            RAISE EXCEPTION 'Permission denied: Client cannot modify account role.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_profile_immutability ON public.profiles;

CREATE TRIGGER trg_enforce_profile_immutability
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_profile_immutability();

-- Revoke direct column updates if column privileges are used in addition
REVOKE UPDATE (is_verified, role) ON public.profiles FROM authenticated, anon;
