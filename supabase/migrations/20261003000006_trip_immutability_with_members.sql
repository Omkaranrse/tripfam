-- Migration: 20261003000006_trip_immutability_with_members.sql
-- Description: Trigger preventing trip hosts from altering destination or dates
--              once travellers have confirmed membership in the trip.

CREATE OR REPLACE FUNCTION public.enforce_trip_immutability_with_members()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_has_members BOOLEAN;
BEGIN
    -- Check if critical fields (destination, start_date, end_date) are changing
    IF (
        NEW.destination IS DISTINCT FROM OLD.destination
        OR NEW.start_date IS DISTINCT FROM OLD.start_date
        OR NEW.end_date IS DISTINCT FROM OLD.end_date
    ) THEN
        -- Check if confirmed members exist in trip_members (excluding host)
        SELECT EXISTS (
            SELECT 1 FROM public.trip_members
            WHERE trip_id = OLD.id
              AND role = 'member'
        ) INTO v_has_members;

        IF v_has_members THEN
            RAISE EXCEPTION 'Cannot modify trip dates or destination once members have joined.'
                USING ERRCODE = '22000';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_trip_immutability_with_members ON public.trips;

CREATE TRIGGER trg_enforce_trip_immutability_with_members
    BEFORE UPDATE ON public.trips
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_trip_immutability_with_members();
