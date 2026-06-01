# Rafiq App

Flutter web app connected to Supabase.

## Supabase

Frontend configuration lives in `lib/core/config/supabase_config.dart`.

The app currently uses:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_RECOVERY_REDIRECT_URL` optional, for password recovery redirects

The `service_role` key should stay server-side only. Do not place it in Flutter web code.

Auth setup notes:

- Disable email confirmation in Supabase Auth if you want signup to complete immediately
- The app validates emails to `@gmail.com` only
- Passwords must be strong: 8+ characters with upper, lower, number, and symbol
- Password reset uses Supabase recovery email, then the app opens the new password screen

Database schema:

- `supabase/schema.sql`

## Vercel

Use `vercel.json` for SPA routing so Flutter routes keep working on refresh.

Suggested build settings:

- Build command: `flutter build web --release`
- Output directory: `build/web`

If you use environment variables in the build pipeline, pass them as:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## Getting Started

1. Install Flutter dependencies with `flutter pub get`
2. Apply `supabase/schema.sql` in your Supabase SQL editor
3. Configure the Vercel project with the build settings above
4. If you use password recovery, set `SUPABASE_RECOVERY_REDIRECT_URL` to your deployed app URL
5. If you enable the AI assistant, configure `GEMINI_API_KEY` as a Supabase
   Edge Function secret, not as a Flutter build secret
6. Deploy the web build

## iOS Release (TestFlight)

iOS direct install requires a signed `.ipa` uploaded to App Store Connect/TestFlight.

This repo now includes `codemagic.yaml` for automated iOS builds and upload to TestFlight.

Guide:

- `docs/ios_testflight_release.md`
