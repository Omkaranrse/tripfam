-- Migration: 20261003000001_initial_schema.sql
-- Description: Core schema definition for TripMate (profiles, trips, trip_members,
--              join_requests, intro_calls, messages, trusted_contacts, check_ins,
--              reports, blocks, verification_requests).

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. Helper function: updated_at auto-updater
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_current_timestamp_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ============================================================================
-- 2. Profiles Table
-- ============================================================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name VARCHAR(60) NOT NULL,
    bio VARCHAR(1000),
    home_city VARCHAR(100),
    avatar_path TEXT,
    travel_style JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_profiles_role CHECK (role IN ('user', 'moderator', 'admin')),
    CONSTRAINT chk_profiles_display_name_length CHECK (char_length(display_name) >= 2)
);

CREATE TRIGGER trg_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_profiles_is_verified ON public.profiles(is_verified);

-- ============================================================================
-- 3. Trips Table
-- ============================================================================
CREATE TABLE public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    destination VARCHAR(150) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    budget NUMERIC(10, 2) CHECK (budget IS NULL OR budget >= 0),
    max_members INT NOT NULL DEFAULT 4,
    description VARCHAR(5000) NOT NULL,
    tags TEXT[] NOT NULL DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'published',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_trips_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_trips_max_members CHECK (max_members BETWEEN 2 AND 12),
    CONSTRAINT chk_trips_status CHECK (status IN ('draft', 'published', 'completed', 'cancelled')),
    CONSTRAINT chk_trips_destination_length CHECK (char_length(destination) >= 2)
);

CREATE TRIGGER trg_trips_updated_at
    BEFORE UPDATE ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_trips_host_id ON public.trips(host_id);
CREATE INDEX idx_trips_status ON public.trips(status);
CREATE INDEX idx_trips_start_date ON public.trips(start_date);
CREATE INDEX idx_trips_destination ON public.trips(destination);

-- ============================================================================
-- 4. Trip Members Table
-- ============================================================================
CREATE TABLE public.trip_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_trip_members_trip_user UNIQUE (trip_id, user_id),
    CONSTRAINT chk_trip_members_role CHECK (role IN ('host', 'member'))
);

CREATE TRIGGER trg_trip_members_updated_at
    BEFORE UPDATE ON public.trip_members
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_trip_members_trip_id ON public.trip_members(trip_id);
CREATE INDEX idx_trip_members_user_id ON public.trip_members(user_id);

-- ============================================================================
-- 5. Join Requests Table
-- ============================================================================
CREATE TABLE public.join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    message VARCHAR(1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_join_requests_trip_user UNIQUE (trip_id, user_id),
    CONSTRAINT chk_join_requests_status CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled'))
);

CREATE TRIGGER trg_join_requests_updated_at
    BEFORE UPDATE ON public.join_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_join_requests_trip_id ON public.join_requests(trip_id);
CREATE INDEX idx_join_requests_user_id ON public.join_requests(user_id);
CREATE INDEX idx_join_requests_status ON public.join_requests(status);

-- ============================================================================
-- 6. Intro Calls Table
-- ============================================================================
CREATE TABLE public.intro_calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL UNIQUE REFERENCES public.join_requests(id) ON DELETE CASCADE,
    scheduled_at TIMESTAMPTZ,
    meeting_link VARCHAR(500),
    host_confirmed BOOLEAN NOT NULL DEFAULT false,
    traveller_confirmed BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_intro_calls_updated_at
    BEFORE UPDATE ON public.intro_calls
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_intro_calls_request_id ON public.intro_calls(request_id);

-- ============================================================================
-- 7. Messages Table
-- ============================================================================
CREATE TABLE public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content VARCHAR(4000) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_messages_content_non_empty CHECK (char_length(trim(content)) > 0)
);

CREATE TRIGGER trg_messages_updated_at
    BEFORE UPDATE ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_messages_trip_id_created ON public.messages(trip_id, created_at ASC);
CREATE INDEX idx_messages_sender_id ON public.messages(sender_id);

-- ============================================================================
-- 8. Trusted Contacts Table
-- ============================================================================
CREATE TABLE public.trusted_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    relationship VARCHAR(50) NOT NULL,
    phone_number VARCHAR(30) NOT NULL,
    email VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_trusted_contacts_name CHECK (char_length(trim(name)) >= 2)
);

CREATE TRIGGER trg_trusted_contacts_updated_at
    BEFORE UPDATE ON public.trusted_contacts
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_trusted_contacts_user_id ON public.trusted_contacts(user_id);

-- ============================================================================
-- 9. Check-Ins Table
-- ============================================================================
CREATE TABLE public.check_ins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    location_name VARCHAR(200) NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    status_note VARCHAR(1000),
    is_safe BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_check_ins_lat CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90)),
    CONSTRAINT chk_check_ins_lng CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180))
);

CREATE TRIGGER trg_check_ins_updated_at
    BEFORE UPDATE ON public.check_ins
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_check_ins_trip_id ON public.check_ins(trip_id);
CREATE INDEX idx_check_ins_user_id ON public.check_ins(user_id);

-- ============================================================================
-- 10. Reports Table
-- ============================================================================
CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES public.trips(id) ON DELETE SET NULL,
    reason VARCHAR(100) NOT NULL,
    details VARCHAR(2000) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reports_different_users CHECK (reporter_id <> reported_user_id),
    CONSTRAINT chk_reports_status CHECK (status IN ('pending', 'reviewed', 'dismissed', 'action_taken'))
);

CREATE TRIGGER trg_reports_updated_at
    BEFORE UPDATE ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_reports_reporter ON public.reports(reporter_id);
CREATE INDEX idx_reports_reported_user ON public.reports(reported_user_id);
CREATE INDEX idx_reports_status ON public.reports(status);

-- ============================================================================
-- 11. Blocks Table
-- ============================================================================
CREATE TABLE public.blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_blocks_blocker_blocked UNIQUE (blocker_id, blocked_id),
    CONSTRAINT chk_blocks_no_self_block CHECK (blocker_id <> blocked_id)
);

CREATE TRIGGER trg_blocks_updated_at
    BEFORE UPDATE ON public.blocks
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_blocks_blocker ON public.blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON public.blocks(blocked_id);

-- ============================================================================
-- 12. Verification Requests Table
-- ============================================================================
CREATE TABLE public.verification_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    selfie_storage_path TEXT NOT NULL,
    id_document_storage_path TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewer_notes VARCHAR(1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_verification_requests_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE TRIGGER trg_verification_requests_updated_at
    BEFORE UPDATE ON public.verification_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.set_current_timestamp_updated_at();

CREATE INDEX idx_verification_requests_user ON public.verification_requests(user_id);
CREATE INDEX idx_verification_requests_status ON public.verification_requests(status);
