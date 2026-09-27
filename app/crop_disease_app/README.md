# crop_disease_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Backend (Supabase) setup

Scans sync to a Supabase project via the REST API (insert-only). To set it up:

1. **Create/update the database schema** — in Supabase, open **SQL Editor → New
   query**, paste the contents of `schema.sql` (in the `../app/` folder, shared
   with the admin dashboard) and run it. It is idempotent: `create table if
   not exists` + `alter table add column if not exists` statements safely
   migrate existing databases with zero data loss.
2. **Embed your project credentials** in `lib/supabase_config.dart` —
   replace the two placeholder constants with your real values from
   Supabase → **Settings → API**:

   ```dart
   // lib/supabase_config.dart
   static const String url = 'https://YOUR-PROJECT-REF.supabase.co';
   static const String anonKey = 'YOUR-SUPABASE-ANON-KEY';
   ```

   The anon key is a public key, safe to ship in the app binary. Until the
   placeholders are replaced, sync silently no-ops — the app still works
   fully offline and scans stay local.

### How scans are attributed

- Onboarding collects the farmer's **name, phone, village**, a language
  preference, and data-sharing consent — all stored on-device.
- The app **auto-generates a Farmer ID** (e.g. `AGD-4821`) and sends it, plus
  a name/village/phone snapshot, with every synced scan
  (`device_farmer_id`, `farmer_name`, `farmer_village`, `farmer_phone`).
- The admin dashboard (`../app/adminDashboard/`) shows these values directly;
  pre-seeding `farmers` rows is no longer required (but still supported).
