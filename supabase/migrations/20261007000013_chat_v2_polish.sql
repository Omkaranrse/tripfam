-- Migration: 20261007000013_chat_v2_polish.sql
-- Description: Chat v2 polish: client_id deduplication, kind ('user'/'system'),
-- chat_reads tracking, rate limiting, and privacy-preserving chat_list_summary RPC.

-- ============================================================================
-- 1. Messages Schema Enhancements (client_id and kind)
-- ============================================================================

-- Add client_id for idempotent client-side sends / deduplication
ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS client_id UUID;

-- Add kind column ('user' vs 'system')
ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS kind VARCHAR(20) NOT NULL DEFAULT 'user'
    CONSTRAINT chk_messages_kind CHECK (kind IN ('user', 'system'));

-- Unique constraint on client_id per sender and trip (prevents duplicate sends on network retry)
CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_trip_sender_client_id
    ON public.messages(trip_id, sender_id, client_id)
    WHERE client_id IS NOT NULL;

-- Index for kind queries if filtered
CREATE INDEX IF NOT EXISTS idx_messages_kind
    ON public.messages(kind);

-- ============================================================================
-- 2. Message Insertion RLS Policy
-- Clients can ONLY insert kind='user' with sender_id = auth.uid().
-- System messages are reserved for server-side functions / triggers.
-- ============================================================================
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
CREATE POLICY "messages_insert_policy"
    ON public.messages
    FOR INSERT
    TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND kind = 'user'
        AND public.has_unlocked_chat(trip_id, auth.uid())
        AND NOT public.is_blocked_mutually(auth.uid(), (SELECT host_id FROM public.trips WHERE id = trip_id))
    );

-- ============================================================================
-- 3. Database Rate Limiting on Messages
-- Enforces a maximum of 30 messages per minute per user
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_message_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
    v_recent_count INTEGER;
BEGIN
    -- Only rate-limit user messages
    IF NEW.kind = 'user' THEN
        SELECT count(*) INTO v_recent_count
        FROM public.messages
        WHERE sender_id = NEW.sender_id
          AND created_at > (NOW() - INTERVAL '1 minute');

        IF v_recent_count >= 30 THEN
            RAISE EXCEPTION 'Rate limit exceeded: maximum 30 messages per minute.'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_messages_rate_limit ON public.messages;
CREATE TRIGGER trg_messages_rate_limit
    BEFORE INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.check_message_rate_limit();

-- ============================================================================
-- 4. Chat Reads Table
-- Tracks the last time each user read a trip chat to compute unread counts
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.chat_reads (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, trip_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_reads_user_id ON public.chat_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_reads_trip_id ON public.chat_reads(trip_id);

ALTER TABLE public.chat_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can select own chat_reads"
    ON public.chat_reads
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own chat_reads"
    ON public.chat_reads
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own chat_reads"
    ON public.chat_reads
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- RPC to mark a chat as read
CREATE OR REPLACE FUNCTION public.mark_chat_read(p_trip_id UUID)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_now TIMESTAMPTZ := NOW();
BEGIN
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Only allow marking read if chat is unlocked for user
    IF NOT public.has_unlocked_chat(p_trip_id, v_caller_id) THEN
        RAISE EXCEPTION 'Access denied: not a member of unlocked chat.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.chat_reads (user_id, trip_id, last_read_at)
    VALUES (v_caller_id, p_trip_id, v_now)
    ON CONFLICT (user_id, trip_id)
    DO UPDATE SET last_read_at = EXCLUDED.last_read_at;

    RETURN v_now;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_chat_read(UUID) TO authenticated;

-- ============================================================================
-- 5. Security-Definer Function: chat_list_summary()
-- Returns chat-eligible trips for caller only:
-- - Last message (excluding blocked users)
-- - Last message timestamp
-- - Unread count (excluding blocked users and caller's own messages)
-- - Past status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.chat_list_summary()
RETURNS TABLE (
    trip_id UUID,
    trip_title VARCHAR,
    destination VARCHAR,
    host_id UUID,
    host_name VARCHAR,
    member_count BIGINT,
    start_date DATE,
    end_date DATE,
    is_past BOOLEAN,
    last_message TEXT,
    last_message_at TIMESTAMPTZ,
    last_sender_id UUID,
    last_sender_name VARCHAR,
    unread_count BIGINT
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
        SELECT
            t.id,
            t.title,
            t.destination,
            t.host_id,
            hp.display_name AS host_name,
            t.start_date,
            t.end_date,
            (t.end_date < CURRENT_DATE) AS is_past
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
            m.sender_id,
            sp.display_name AS sender_name
        FROM public.messages m
        JOIN unlocked_trips ut ON ut.id = m.trip_id
        LEFT JOIN public.profiles sp ON sp.id = m.sender_id
        WHERE NOT public.is_blocked_mutually(v_caller_id, m.sender_id)
        ORDER BY m.trip_id, m.created_at DESC
    ),
    unread_counts AS (
        SELECT
            m.trip_id,
            COUNT(*) AS unread_count
        FROM public.messages m
        JOIN unlocked_trips ut ON ut.id = m.trip_id
        LEFT JOIN public.chat_reads cr
            ON cr.trip_id = m.trip_id AND cr.user_id = v_caller_id
        WHERE m.sender_id <> v_caller_id
          AND m.created_at > COALESCE(cr.last_read_at, '1970-01-01'::timestamptz)
          AND NOT public.is_blocked_mutually(v_caller_id, m.sender_id)
        GROUP BY m.trip_id
    )
    SELECT
        ut.id AS trip_id,
        ut.title AS trip_title,
        ut.destination,
        ut.host_id,
        ut.host_name,
        COALESCE(tmc.count, 1) AS member_count,
        ut.start_date,
        ut.end_date,
        ut.is_past,
        lm.content AS last_message,
        lm.created_at AS last_message_at,
        lm.sender_id AS last_sender_id,
        lm.sender_name AS last_sender_name,
        COALESCE(uc.unread_count, 0) AS unread_count
    FROM unlocked_trips ut
    LEFT JOIN trip_member_counts tmc ON tmc.trip_id = ut.id
    LEFT JOIN latest_messages lm ON lm.trip_id = ut.id
    LEFT JOIN unread_counts uc ON uc.trip_id = ut.id
    ORDER BY COALESCE(lm.created_at, ut.start_date::timestamptz, NOW() - INTERVAL '100 years') DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.chat_list_summary() TO authenticated;

-- ============================================================================
-- 6. SQL Security Verification Script
-- Run within a psql or Supabase SQL Editor test harness
-- ============================================================================
/*
DO $$
DECLARE
    v_user_a UUID := '00000000-0000-0000-0000-00000000000a';
    v_user_b UUID := '00000000-0000-0000-0000-00000000000b';
    v_trip_1 UUID := '11111111-1111-1111-1111-111111111111';
    v_read_count INTEGER;
BEGIN
    -- 1. Test: User A cannot read User B's chat_reads
    PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
    PERFORM set_config('role', 'authenticated', true);

    SELECT count(*) INTO v_read_count
    FROM public.chat_reads
    WHERE user_id = v_user_b;

    ASSERT v_read_count = 0, 'SECURITY VIOLATION: User A read User B chat_reads';

    -- 2. Test: User A cannot insert system messages
    BEGIN
        INSERT INTO public.messages (trip_id, sender_id, content, kind)
        VALUES (v_trip_1, v_user_a, 'Illegal system announcement', 'system');
        RAISE EXCEPTION 'SECURITY VIOLATION: User A inserted system message';
    EXCEPTION
        WHEN insufficient_privilege OR check_violation THEN
            -- Expected rejection by RLS policy
            NULL;
    END;

    -- 3. Test: User A cannot see summaries for trips they don't belong to
    -- (chat_list_summary() filters by public.has_unlocked_chat)

    -- 4. Test: Blocked users' messages do not appear in chat_list_summary()
    -- (chat_list_summary() joins on NOT public.is_blocked_mutually)
END $$;
*/
