// Supabase Edge Function: send-missed-checkin-alert
// Purpose: Scheduled job to detect overdue traveller check-ins and dispatch
//          emergency alerts to their registered trusted contacts.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface TrustedContact {
  name: string;
  email?: string;
  phone?: string;
  relationship: string;
}

interface MissedCheckinPayload {
  schedule_id: string;
  traveller_name: string;
  trip_destination: string;
  trip_start: string;
  trip_end: string;
  host_name?: string;
  missed_deadline: string;
  last_checkin_at?: string;
  interval_hours: number;
  last_known_location?: {
    latitude: number;
    longitude: number;
    accuracy?: number;
    recorded_at: string;
  };
  trusted_contacts: TrustedContact[];
}

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Missing Supabase service environment configuration." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Call database function to fetch overdue checkins and mark them alert_sent
    const { data: missedCheckins, error: dbError } = await supabase.rpc(
      "get_missed_checkins_for_alert"
    );

    if (dbError) {
      console.error("[CRON ERROR] Failed to fetch missed check-ins:", dbError.message);
      return new Response(
        JSON.stringify({ error: dbError.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const list = (missedCheckins as MissedCheckinPayload[]) || [];
    let dispatchedAlertsCount = 0;

    for (const checkin of list) {
      const {
        traveller_name,
        trip_destination,
        missed_deadline,
        last_checkin_at,
        interval_hours,
        host_name,
        last_known_location,
        trusted_contacts,
      } = checkin;

      let locationText = "Location was not shared for this trip.";
      if (last_known_location) {
        const mapsUrl = `https://www.google.com/maps?q=${last_known_location.latitude},${last_known_location.longitude}`;
        locationText = `Last Known Coordinates: ${last_known_location.latitude}, ${last_known_location.longitude} (Recorded: ${last_known_location.recorded_at})\nView on Map: ${mapsUrl}`;
      }

      for (const contact of trusted_contacts) {
        if (!contact.email && !contact.phone) continue;

        const emailSubject = `[URGENT] Safety Alert: ${traveller_name} missed scheduled check-in on TripFam`;
        const emailBody = `
Dear ${contact.name},

You are listed as a trusted emergency contact for ${traveller_name} on TripFam.

This is an automated safety alert because ${traveller_name} has missed their scheduled check-in window.

Trip Details:
- Destination: ${trip_destination}
- Trip Host: ${host_name || "Community Host"}
- Check-in Interval: Every ${interval_hours} hours
- Expected Check-in Deadline: ${new Date(missed_deadline).toUTCString()}
- Last Check-in Recorded: ${last_checkin_at ? new Date(last_checkin_at).toUTCString() : "Never recorded"}

Location Data:
${locationText}

Recommended Next Steps:
1. Attempt to reach ${traveller_name} directly via call or message.
2. If unable to reach them and you believe there is immediate danger, contact local emergency services or the destination authorities.

Sincerely,
TripFam Safety & Response Team
        `.trim();

        // Dispatch email through Resend API or SMTP provider if configured
        const resendApiKey = Deno.env.get("RESEND_API_KEY");
        if (resendApiKey && contact.email) {
          try {
            await fetch("https://api.resend.com/emails", {
              method: "POST",
              headers: {
                Authorization: `Bearer ${resendApiKey}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                from: "TripFam Safety <safety@tripfam.app>",
                to: [contact.email],
                subject: emailSubject,
                text: emailBody,
              }),
            });
          } catch (mailErr) {
            console.error(`[MAIL ERROR] Failed sending to contact: ${mailErr}`);
          }
        } else {
          // In development or without Resend key, log the alert dispatch
          console.log(`[ALERT DISPATCHED] To contact for traveller ID: ${checkin.schedule_id}`);
        }

        dispatchedAlertsCount++;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        overdue_schedules_processed: list.length,
        alerts_dispatched: dispatchedAlertsCount,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
