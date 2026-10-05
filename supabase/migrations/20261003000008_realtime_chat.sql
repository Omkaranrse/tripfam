-- Migration: 20261003000008_realtime_chat.sql
-- Description: Realtime chat publication, RLS chat unlock enforcement,
--              in-chat moderation (block and report), and unlocked trip chats RPC.

-- ============================================================================
-- 1. Realtime Publication & Replica Identity
-- ============================================================================

-- Ensure messages table uses REPLICA IDENTITY FULL so websocket broadcasts respect RLS
ALTER TABLE public.messages REPLICA IDENTITY FULL;

-- Add messages table to Supabase Realtime publication if not already present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;
END $$;

-- ============================================================================
-- 2. Refined has_unlocked_chat Function
-- Chat unlocks ONLY after mutual confirmation of the intro call by both sides
-- ============================================================================
CREATE OR REPLACE FUNCTION public.has_unlocked_chat(p_trip_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_host BOOLEAN;
    v_is_member BOOLEAN;
    v_call_confirmed BOOLEAN;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- Host check: host chat is unlocked ONLY when at least one intro call has been mutually confirmed
    SELECT EXISTS (
        SELECT 1 FROM public.trips
        WHERE id = p_trip_id AND host_id = p_user_id
    ) INTO v_is_host;

    IF v_is_host THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.join_requests jr
            JOIN public.intro_calls ic ON ic.request_id = jr.id
            WHERE jr.trip_id = p_trip_id
              AND ic.host_confirmed = true
              AND ic.traveller_confirmed = true
        ) INTO v_call_confirmed;
        RETURN v_call_confirmed;
    END IF;

    -- Non-host check: must be a registered trip member AND have their own mutual intro call confirmation
    SELECT EXISTS (
        SELECT 1 FROM public.trip_members
        WHERE trip_id = p_trip_id AND user_id = p_user_id
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RETURN false;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM public.join_requests jr
        JOIN public.intro_calls ic ON ic.request_id = jr.id
        WHERE jr.trip_id = p_trip_id
          AND jr.user_id = p_user_id
          AND ic.host_confirmed = true
          AND ic.traveller_confirmed = true
    ) INTO v_call_confirmed;

    RETURN v_call_confirmed;
END;
$$;

-- ============================================================================
-- 3. Refined Messages RLS Policies
-- Blocked users cannot message if blocked by host or if blocked mutually
-- ============================================================================
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
CREATE POLICY "messages_insert_policy"
    ON public.messages
    FOR INSERT
    TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND public.has_unlocked_chat(trip_id, auth.uid())
        AND NOT public.is_blocked_mutually(auth.uid(), (SELECT host_id FROM public.trips WHERE id = trip_id))
    );

-- ============================================================================
-- 4. In-Chat Moderation Functions (Block & Report)
-- ============================================================================

-- Function: block_user
CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF v_caller_id = p_blocked_id THEN
        RAISE EXCEPTION 'Cannot block yourself.' USING ERRCODE = '22000';
    END IF;

    INSERT INTO public.blocks (blocker_id, blocked_id)
    VALUES (v_caller_id, p_blocked_id)
    ON CONFLICT (blocker_id, blocked_id) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'blocker_id', v_caller_id,
        'blocked_id', p_blocked_id
    );
END;
$$;

-- Function: unblock_user
CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    DELETE FROM public.blocks
    WHERE blocker_id = v_caller_id AND blocked_id = p_blocked_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- Function: report_user
CREATE OR REPLACE FUNCTION public.report_user(
    p_reported_user_id UUID,
    p_reason VARCHAR,
    p_details VARCHAR,
    p_trip_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_report_id UUID;
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF v_caller_id = p_reported_user_id THEN
        RAISE EXCEPTION 'Cannot report yourself.' USING ERRCODE = '22000';
    END IF;

    IF length(trim(coalesce(p_reason, ''))) = 0 THEN
        RAISE EXCEPTION 'A reason is required to submit a report.' USING ERRCODE = '22000';
    END IF;

    INSERT INTO public.reports (reporter_id, reported_user_id, trip_id, reason, details)
    VALUES (
        v_caller_id,
        p_reported_user_id,
        p_trip_id,
        trim(p_reason),
        trim(coalesce(p_details, 'No additional details provided.'))
    )
    RETURNING id INTO v_report_id;

    RETURN jsonb_build_object(
        'success', true,
        'report_id', v_report_id
    );
END;
$$;

-- ============================================================================
-- 5. RPC to Fetch Unlocked Trip Chats for the Current User
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_unlocked_trip_chats()
RETURNS TABLE (
    trip_id UUID,
    trip_title VARCHAR,
    destination VARCHAR,
    host_id UUID,
    host_name VARCHAR,
    member_count BIGINT,
    last_message TEXT,
    last_message_at TIMESTAMPTZ,
    last_sender_id UUID
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    WITH unlocked_trips AS (
        SELECT t.id, t.title, t.destination, t.host_id, hp.display_name AS host_name
        FROM public.trips t
        LEFT JOIN public.profiles hp ON hp.id = t.host_id
        WHERE public.has_unlocked_chat(t.id, v_caller_id) = true
          AND NOT public.is_blocked_mutually(v_caller_id, t.host_id)
    ),
    trip_member_counts AS (
        SELECT tm.trip_id, COUNT(*) AS count
        FROM public.trip_members tm
        JOIN unlocked_trips ut ON ut.id = tm.trip_id
        GROUP BY tm.trip_id
    ),
    latest_messages AS (
        SELECT DISTINCT ON (m.trip_id)
            m.trip_id,
            m.content,
            m.created_at,
            m.sender_id
        FROM public.messages m
        JOIN unlocked_trips ut ON ut.id = m.trip_id
        WHERE NOT public.is_blocked_mutually(v_caller_id, m.sender_id)
        ORDER BY m.trip_id, m.created_at DESC
    )
    SELECT
        ut.id AS trip_id,
        ut.title AS trip_title,
        ut.destination,
        ut.host_id,
        ut.host_name,
        COALESCE(tmc.count, 1) AS member_count,
        lm.content AS last_message,
        lm.created_at AS last_message_at,
        lm.sender_id AS last_sender_id
    FROM unlocked_trips ut
    LEFT JOIN trip_member_counts tmc ON tmc.trip_id = ut.id
    LEFT JOIN latest_messages lm ON lm.trip_id = ut.id
    ORDER BY COALESCE(lm.created_at, NOW() - INTERVAL '100 years') DESC;
END;
$$;
