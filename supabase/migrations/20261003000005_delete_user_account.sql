-- Migration: 20261003000005_delete_user_account.sql
-- Description: Server-side function allowing authenticated users to completely
--              delete their account and associated profile, storage files, and records.

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, storage
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to delete account.' USING ERRCODE = '42501';
    END IF;

    -- 1. Remove user files from private storage buckets
    DELETE FROM storage.objects
    WHERE bucket_id IN ('avatars', 'verification-selfies')
      AND (storage.foldername(name))[1] = v_user_id::text;

    -- 2. Remove user profile (cascades to trip memberships, requests, contacts, etc.)
    DELETE FROM public.profiles
    WHERE id = v_user_id;

    -- 3. Delete auth account from auth.users
    DELETE FROM auth.users
    WHERE id = v_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_user_id,
        'deleted_at', NOW()
    );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
