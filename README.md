# Love 21 Flutter app

This app is a Flutter implementation starter based on the Stitch HTML screens and the warm_editorial_romance/DESIGN.md guide. It uses the warm ivory, wine, coral, and blush palette and a mobile-first layout.

## What is implemented

- Flutter mobile/web screens for welcome, account creation/login/recovery, contact verification, age restriction, interests, profile preview, identity status, challenge rules/dashboard/completion, photo submission/review/appeal, discovery eligibility, anonymous vertical profile actions/details, server-confirmed match, text-only chat, photo-reveal consent, settings, safety, and account deletion.
- Supabase Auth calls for sign-up, sign-in, email resend, and password recovery.
- Server calls for account auth, age and challenge eligibility, verified-day count, identity status, discovery candidates/actions, private challenge-photo upload/submission/status/appeal, mutual interest, connection listing, and text messages.
- Initial Supabase/Postgres schema with RLS, private challenge photo storage, server-controlled verification fields, verified-day counting, eligibility filtering, mutual-interest checks, text-only messages, a 14-day consent gate, and deletion requests.
- Clear demo banners. With no Supabase credentials, actions are previews only and do not claim to save or verify data.

## Product decisions that need approval

1. **Minimum age:** formal Love 21 requirements say 20+, while current Stitch screens and the internship overview say 18+. The database default and Flutter display constant use 20+ because that was the earlier mandatory business rule. Confirm the correct age before onboarding is released; update both the database config and minimumAge constant together.
2. **Missed days:** a Stitch policy screen proposes two grace tokens within 36 hours, but the text labels this as proposed. The starter database keeps verified progress and lets the member continue later; it does not reset or grant catch-up tokens. Confirm whether a missed day should pause or reset the challenge.
3. **Identity provider:** choose an authorized provider and complete its legal, consent, webhook, and retention setup before identity can be verified.
4. **Challenge review:** decide who reviews evidence, review times, rejection reasons, appeals, and reviewer access. The database leaves submissions pending until a trusted backend reviewer changes the status.
5. **Daily challenge calendar:** the migration defaults the shared challenge timezone to Asia/Kolkata and allows one pending or verified activity per local date; rejected submissions can be resubmitted. Confirm this timezone and cadence before launch.
6. **14-day meaning:** timer begins at mutual acceptance and is stored as a server timestamp; confirm whether “14 days” means exactly 14×24 hours or local calendar days and which timezone governs it.

## Configure the backend

1. Create a Supabase project and review supabase/migrations/202610290001_love21_initial.sql before applying it.
2. Apply the migration in a development project first. Check database policies and Storage policies with test accounts before adding real users or photos.
3. Configure email confirmation and password-reset URLs in Supabase Auth.
4. Pass the Supabase project URL and publishable client key using --dart-define. Do not add privileged/service-role keys to the app, source control, or .env.example.
5. Add an authorized identity provider and server-side webhook/Edge Function. Only trusted server code may change identity_status, submission status, and age-gate fields.
6. Keep challenge photos in the private bucket. A separate profile-photo bucket and a consent-aware signed-URL endpoint must be implemented before photos can be revealed.

Example command:

    flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY

Without both values, the app launches in preview mode:

    flutter run

The app does not persist demo challenge progress. Real progress must be loaded from the backend after sign-in.

## Run checks

    flutter pub get
    flutter analyze
    flutter test

The project was scaffolded with Flutter 3.47.7 / Dart 3.13.5. Package downloads were attempted, but the package process exited unexpectedly in this environment. Android SDK was not detected. Re-run the checks on a machine with a working Flutter package connection and Android SDK.

## Important boundaries

This is not production-ready yet. The database migration is a starting schema and needs a security review before use with real users. Identity-provider integration, reviewer/admin tools, consent-aware profile-photo delivery, notification delivery, persistence for profile/interests/preferences/settings, complete block/report/unmatch operations, and account-deletion processing still need implementation and tests. The reveal-consent screen is not connected to the database function yet. No real identity verification or photo reveal can happen until the provider and secure server endpoint are configured.
