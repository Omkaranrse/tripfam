-- Migration: 20261003000003_row_level_security.sql
-- Description: Complete Row Level Security policies for all tables.
--              Includes discrete SELECT, INSERT, UPDATE, DELETE policies.

-- ============================================================================
-- 1. Helper Security Functions (STABLE, SECURITY DEFINER)
-- ============================================================================

-- Check if two users have an active block in either direction
CREATE OR REPLACE FUNCTION public.is_blocked_mutually(p_user_a UUID, p_user_b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.blocks
        WHERE (blocker_id = p_user_a AND blocked_id = p_user_b)
           OR (blocker_id = p_user_b AND blocked_id = p_user_a)
    );
$$;

-- Check if a user has staff privileges (admin / moderator)
CREATE OR REPLACE FUNCTION public.is_staff(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = p_user_id AND role IN ('admin', 'moderator')
    );
$$;

-- Verify if user has unlocked chat access for a trip
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

    -- Host always has base trip access
    SELECT EXISTS (
        SELECT 1 FROM public.trips
        WHERE id = p_trip_id AND host_id = p_user_id
    ) INTO v_is_host;

    IF v_is_host THEN
        RETURN true;
    END IF;

    -- Non-host must be a trip member
    SELECT EXISTS (
        SELECT 1 FROM public.trip_members
        WHERE trip_id = p_trip_id AND user_id = p_user_id
    ) INTO v_is_member;

    IF NOT v_is_member THEN
        RETURN false;
    END IF;

    -- And must have both host and traveller confirmed intro call
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
-- 2. Enable RLS on All Tables
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intro_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trusted_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. PROFILES POLICIES
-- ============================================================================
-- SELECT: Users can view any profile unless blocked by or blocking the profile owner
CREATE POLICY "profiles_select_policy"
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        id = auth.uid()
        OR NOT public.is_blocked_mutually(auth.uid(), id)
    );

-- INSERT: Only the profile owner can insert their own row (used by trigger or fallback)
CREATE POLICY "profiles_insert_policy"
    ON public.profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (
        id = auth.uid()
    );

-- UPDATE: Users can edit only their own profile
CREATE POLICY "profiles_update_policy"
    ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- DELETE: Users can delete only their own profile
CREATE POLICY "profiles_delete_policy"
    ON public.profiles
    FOR DELETE
    TO authenticated
    USING (id = auth.uid() OR public.is_staff(auth.uid()));

-- ============================================================================
-- 4. TRIPS POLICIES
-- ============================================================================
-- SELECT: Anyone can view published/completed trips (unless blocked by host);
--         drafts viewable only by host.
CREATE POLICY "trips_select_policy"
    ON public.trips
    FOR SELECT
    TO authenticated
    USING (
        (
            host_id = auth.uid()
            OR (status IN ('published', 'completed') AND NOT public.is_blocked_mutually(auth.uid(), host_id))
        )
    );

-- INSERT: Authenticated users can create trips where they are host
CREATE POLICY "trips_insert_policy"
    ON public.trips
    FOR INSERT
    TO authenticated
    WITH CHECK (
        host_id = auth.uid()
    );

-- UPDATE: Only the host can edit their trip
CREATE POLICY "trips_update_policy"
    ON public.trips
    FOR UPDATE
    TO authenticated
    USING (host_id = auth.uid())
    WITH CHECK (host_id = auth.uid());

-- DELETE: Only the host can delete their trip
CREATE POLICY "trips_delete_policy"
    ON public.trips
    FOR DELETE
    TO authenticated
    USING (host_id = auth.uid() OR public.is_staff(auth.uid()));

-- ============================================================================
-- 5. TRIP_MEMBERS POLICIES
-- ============================================================================
-- SELECT: Members of the trip, host of the trip, or users browsing published trips
CREATE POLICY "trip_members_select_policy"
    ON public.trip_members
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = trip_members.trip_id
              AND (t.host_id = auth.uid() OR (t.status = 'published' AND NOT public.is_blocked_mutually(auth.uid(), trip_members.user_id)))
        )
    );

-- INSERT: Only host or system functions can add members
CREATE POLICY "trip_members_insert_policy"
    ON public.trip_members
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = trip_members.trip_id
              AND t.host_id = auth.uid()
        )
    );

-- UPDATE: Only the host can update trip member roles
CREATE POLICY "trip_members_update_policy"
    ON public.trip_members
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = trip_members.trip_id
              AND t.host_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = trip_members.trip_id
              AND t.host_id = auth.uid()
        )
    );

-- DELETE: Host can remove members, or a member can remove themselves (leave trip)
CREATE POLICY "trip_members_delete_policy"
    ON public.trip_members
    FOR DELETE
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = trip_members.trip_id
              AND t.host_id = auth.uid()
        )
    );

-- ============================================================================
-- 6. JOIN_REQUESTS POLICIES
-- ============================================================================
-- SELECT: Requester and trip host can view
CREATE POLICY "join_requests_select_policy"
    ON public.join_requests
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = join_requests.trip_id
              AND t.host_id = auth.uid()
        )
    );

-- INSERT: Only prospective travellers can request (not host, not blocked, status pending)
CREATE POLICY "join_requests_insert_policy"
    ON public.join_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND status = 'pending'
        AND EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = join_requests.trip_id
              AND t.host_id <> auth.uid()
              AND t.status = 'published'
              AND NOT public.is_blocked_mutually(auth.uid(), t.host_id)
        )
    );

-- UPDATE: Host can update status (accept/decline), or requester can cancel
CREATE POLICY "join_requests_update_policy"
    ON public.join_requests
    FOR UPDATE
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = join_requests.trip_id
              AND t.host_id = auth.uid()
        )
    )
    WITH CHECK (
        -- Requester can only mark as cancelled
        (user_id = auth.uid() AND status = 'cancelled')
        -- Host can transition between pending, accepted, declined
        OR (
            EXISTS (
                SELECT 1 FROM public.trips t
                WHERE t.id = join_requests.trip_id
                  AND t.host_id = auth.uid()
            )
            AND status IN ('accepted', 'declined')
        )
    );

-- DELETE: Requester can delete/withdraw request
CREATE POLICY "join_requests_delete_policy"
    ON public.join_requests
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- ============================================================================
-- 7. INTRO_CALLS POLICIES
-- ============================================================================
-- SELECT: Requester or trip host
CREATE POLICY "intro_calls_select_policy"
    ON public.intro_calls
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.join_requests jr
            JOIN public.trips t ON t.id = jr.trip_id
            WHERE jr.id = intro_calls.request_id
              AND (jr.user_id = auth.uid() OR t.host_id = auth.uid())
        )
    );

-- INSERT: Host or requester
CREATE POLICY "intro_calls_insert_policy"
    ON public.intro_calls
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.join_requests jr
            JOIN public.trips t ON t.id = jr.trip_id
            WHERE jr.id = intro_calls.request_id
              AND (jr.user_id = auth.uid() OR t.host_id = auth.uid())
        )
    );

-- UPDATE: Host or traveller can confirm or update schedule
CREATE POLICY "intro_calls_update_policy"
    ON public.intro_calls
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.join_requests jr
            JOIN public.trips t ON t.id = jr.trip_id
            WHERE jr.id = intro_calls.request_id
              AND (jr.user_id = auth.uid() OR t.host_id = auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.join_requests jr
            JOIN public.trips t ON t.id = jr.trip_id
            WHERE jr.id = intro_calls.request_id
              AND (jr.user_id = auth.uid() OR t.host_id = auth.uid())
        )
    );

-- DELETE: Trip host only
CREATE POLICY "intro_calls_delete_policy"
    ON public.intro_calls
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.join_requests jr
            JOIN public.trips t ON t.id = jr.trip_id
            WHERE jr.id = intro_calls.request_id
              AND t.host_id = auth.uid()
        )
    );

-- ============================================================================
-- 8. MESSAGES POLICIES
-- Allowed only between members of the same trip after both confirmed the intro call
-- ============================================================================
-- SELECT: Trip members with unlocked chat and not blocked with sender
CREATE POLICY "messages_select_policy"
    ON public.messages
    FOR SELECT
    TO authenticated
    USING (
        public.has_unlocked_chat(trip_id, auth.uid())
        AND NOT public.is_blocked_mutually(auth.uid(), sender_id)
    );

-- INSERT: Members with unlocked chat can send messages
CREATE POLICY "messages_insert_policy"
    ON public.messages
    FOR INSERT
    TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND public.has_unlocked_chat(trip_id, auth.uid())
    );

-- UPDATE: Sender can edit their own message
CREATE POLICY "messages_update_policy"
    ON public.messages
    FOR UPDATE
    TO authenticated
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());

-- DELETE: Sender can delete their message, or host can moderate
CREATE POLICY "messages_delete_policy"
    ON public.messages
    FOR DELETE
    TO authenticated
    USING (
        sender_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.trips t
            WHERE t.id = messages.trip_id
              AND t.host_id = auth.uid()
        )
        OR public.is_staff(auth.uid())
    );

-- ============================================================================
-- 9. TRUSTED_CONTACTS POLICIES
-- Private to the owner only
-- ============================================================================
CREATE POLICY "trusted_contacts_select_policy"
    ON public.trusted_contacts
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "trusted_contacts_insert_policy"
    ON public.trusted_contacts
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "trusted_contacts_update_policy"
    ON public.trusted_contacts
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "trusted_contacts_delete_policy"
    ON public.trusted_contacts
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- ============================================================================
-- 10. CHECK_INS POLICIES
-- Accessible to the user, trip host, and trip members with unlocked chat
-- ============================================================================
CREATE POLICY "check_ins_select_policy"
    ON public.check_ins
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR (
            public.has_unlocked_chat(trip_id, auth.uid())
            AND NOT public.is_blocked_mutually(auth.uid(), user_id)
        )
    );

CREATE POLICY "check_ins_insert_policy"
    ON public.check_ins
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND public.has_unlocked_chat(trip_id, auth.uid())
    );

CREATE POLICY "check_ins_update_policy"
    ON public.check_ins
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "check_ins_delete_policy"
    ON public.check_ins
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- ============================================================================
-- 11. REPORTS POLICIES
-- Reporter can view their own reports; staff can view and manage all
-- ============================================================================
CREATE POLICY "reports_select_policy"
    ON public.reports
    FOR SELECT
    TO authenticated
    USING (
        reporter_id = auth.uid()
        OR public.is_staff(auth.uid())
    );

CREATE POLICY "reports_insert_policy"
    ON public.reports
    FOR INSERT
    TO authenticated
    WITH CHECK (
        reporter_id = auth.uid()
        AND reporter_id <> reported_user_id
    );

CREATE POLICY "reports_update_policy"
    ON public.reports
    FOR UPDATE
    TO authenticated
    USING (public.is_staff(auth.uid()))
    WITH CHECK (public.is_staff(auth.uid()));

CREATE POLICY "reports_delete_policy"
    ON public.reports
    FOR DELETE
    TO authenticated
    USING (public.is_staff(auth.uid()));

-- ============================================================================
-- 12. BLOCKS POLICIES
-- Users control and see only their own blocks
-- ============================================================================
CREATE POLICY "blocks_select_policy"
    ON public.blocks
    FOR SELECT
    TO authenticated
    USING (blocker_id = auth.uid());

CREATE POLICY "blocks_insert_policy"
    ON public.blocks
    FOR INSERT
    TO authenticated
    WITH CHECK (
        blocker_id = auth.uid()
        AND blocker_id <> blocked_id
    );

CREATE POLICY "blocks_update_policy"
    ON public.blocks
    FOR UPDATE
    TO authenticated
    USING (blocker_id = auth.uid())
    WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "blocks_delete_policy"
    ON public.blocks
    FOR DELETE
    TO authenticated
    USING (blocker_id = auth.uid());

-- ============================================================================
-- 13. VERIFICATION_REQUESTS POLICIES
-- Users see and create only their own requests; staff review them
-- ============================================================================
CREATE POLICY "verification_requests_select_policy"
    ON public.verification_requests
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_staff(auth.uid())
    );

CREATE POLICY "verification_requests_insert_policy"
    ON public.verification_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND status = 'pending'
    );

CREATE POLICY "verification_requests_update_policy"
    ON public.verification_requests
    FOR UPDATE
    TO authenticated
    USING (public.is_staff(auth.uid()))
    WITH CHECK (public.is_staff(auth.uid()));

CREATE POLICY "verification_requests_delete_policy"
    ON public.verification_requests
    FOR DELETE
    TO authenticated
    USING (
        (user_id = auth.uid() AND status = 'pending')
        OR public.is_staff(auth.uid())
    );
