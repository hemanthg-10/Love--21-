# Love 21 Flutter app

This app is a Flutter implementation starter based on the Stitch HTML screens and the warm_editorial_romance/DESIGN.md guide. It uses the warm ivory, wine, coral, and blush palette and a mobile-first layout.

## What is implemented

- Flutter mobile/web screens for welcome, account creation/login/recovery, contact verification, age restriction, interests, profile preview, identity status, challenge rules/dashboard/completion, photo submission/review/appeal, discovery eligibility, anonymous vertical profile actions/details, server-confirmed match, text-only chat, photo-reveal consent, settings, safety, and account deletion.
- Supabase Auth calls for sign-up, sign-in, email resend, and password recovery.
- Server calls for account auth, age and challenge eligibility, verified-day count, identity status, discovery candidates/actions, private challenge-photo upload/submission/status/appeal, mutual interest, connection listing, and text messages.
- Initial Supabase/Postgres schema with RLS, private challenge photo storage, server-controlled verification fields, verified-day counting, eligibility filtering, mutual-interest checks, text-only messages, a 14-day consent gate, and deletion requests.
- Explicit preview-only behavior when Supabase is not configured. Sensitive verification and mutual-connection outcomes are never simulated as successful.
- Full-height anonymous chat with shared four-tab navigation, backend connection previews, saved discovery profiles, paged discovery queries, profile editing, private profile-photo storage, and backend-controlled 14-day mutual photo-consent delivery.

## Product decisions and launch prerequisites

1. **Minimum age:** the product owner confirmed 18+. Flutter and the migration now use 18; applying the migration updates the singleton config row for an existing project too.
2. **Missed days:** a Stitch policy screen proposes two grace tokens within 36 hours, but the text labels this as proposed. The starter database keeps verified progress and lets the member continue later; it does not reset or grant catch-up tokens. Confirm whether a missed day should pause or reset the challenge.
3. **Identity verification:** the product owner requested birth-certificate verification. No document capture or verification vendor is implemented. Do not collect/store birth-certificate images in this app until a qualified provider, lawful process, explicit consent, secure review workflow, and retention/deletion rules are selected. Prefer a provider that returns only a verification result and does not expose document images to Love 21.
4. **Challenge review:** decide who reviews evidence, review times, rejection reasons, appeals, and reviewer access. The database leaves submissions pending until a trusted backend reviewer changes the status.
5. **Daily challenge calendar:** the migration defaults the shared challenge timezone to Asia/Kolkata and allows one pending or verified activity per local date; rejected submissions can be resubmitted. Confirm this timezone and cadence before launch.
6. **14-day meaning:** timer begins at mutual acceptance and is stored as a server timestamp; confirm whether “14 days” means exactly 14×24 hours or local calendar days and which timezone governs it.

## Configure the backend

1. Create a Supabase project and review every SQL file in `supabase/migrations` in timestamp order.
2. Apply all migrations in a development project first, including `202610310001_opposite_gender_discovery.sql` and `202610310002_post_challenge_experience.sql`. These derive and enforce opposite-gender discovery preferences, page and save profiles, return member-only connection previews, and gate private profile photos behind mutual consent after 14 days. Check database and Storage policies with test accounts before adding real users or photos.
3. Configure email confirmation and password-reset URLs in Supabase Auth.
4. Pass the Supabase project URL and publishable client key using --dart-define. Do not add privileged/service-role keys to the app, source control, or .env.example.
5. Add an authorized identity provider and server-side webhook/Edge Function. Only trusted server code may change identity_status, submission status, and age-gate fields.
6. Keep challenge and profile photos in their private buckets. The new migration adds consent-aware access for profile photos; verify its Storage behavior in a development project before enabling photo upload or reveal.

Example command:

    flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY

Without both values, the app launches in preview mode:

    flutter run

Preview challenge progress is stored locally and is clearly marked as simulated. Real progress, eligibility, discovery, connections, chat, profile changes, and consent decisions must come from the backend after sign-in.

## Run checks

    flutter pub get
    flutter analyze
    flutter test

The project was scaffolded with Flutter 3.47.7 / Dart 3.13.5. Package downloads were attempted, but the package process exited unexpectedly in this environment. Android SDK was not detected. Re-run the checks on a machine with a working Flutter package connection and Android SDK.

## Important boundaries

This is not production-ready yet. The database migration is a starting schema and needs security and integration testing before use with real users. Identity-provider integration, reviewer/admin tools, moderation operations and account-deletion processing still need production setup. No real identity verification can happen until an authorized provider and trusted server callback are configured. Apply and test every migration on a development Supabase project before onboarding users.
