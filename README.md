# TripMate

TripMate is a Flutter foundation for solo travellers to discover planned trips
and meet fellow travellers before departure.

## Run locally

1. Install Flutter stable and enable the platform you want to run.
2. Copy `.env.example` to `.env.local` and replace its values with the Supabase
	project URL and the public anon/publishable key. Never use a `service_role`
	or `sb_secret_` key in this file.
3. Run:

	```sh
	flutter pub get
	flutter run --dart-define-from-file=.env.local
	```

	For web, use `flutter run -d chrome --dart-define-from-file=.env.local`.

The local environment file is git-ignored. Supabase is not initialized when
configuration is missing or invalid. The current trip repository serves sample
content only; no authentication flow, database schema, RLS policies, storage
bucket, or Edge Function is part of this foundation. Do not use this build with
real traveller data until those backend controls and feature repositories have
been implemented and tested.

Poppins is bundled from Google Fonts under the SIL Open Font License; the
license is included in `assets/fonts/OFL.txt`.
