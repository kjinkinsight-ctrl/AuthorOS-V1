# Supabase setup for Author Studio

Use these steps to connect the Flutter app to your live Supabase project.

## 1) Set the app config

Add your live project URL and anon key as compile-time values when running the app:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://dzhfhypgkukvfliubykv.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

You can also use the same values in a release build or CI environment.

## 2) Enable Google OAuth

In the Supabase dashboard:

1. Open Authentication > Providers.
2. Enable Google.
3. Add your Google OAuth client credentials.
4. Add the redirect URL for your app as:
   - `https://dzhfhypgkukvfliubykv.supabase.co/auth/v1/callback`
5. Save changes.

For a Flutter mobile app, also ensure your app is configured with the redirect URL expected by the OAuth flow used by `supabase_flutter`.

## 3) Create the database schema

Open the Supabase SQL editor and execute the contents of `schema.sql`.

This creates:

- `public.projects`
- `public.sync_records`
- Row Level Security policies for each user
- indexes for project and sync lookups

## 4) App behavior

The app now supports a fallback pattern:

- If Supabase is configured and the user is signed in, project data is read/written to Supabase.
- If Supabase is not configured or the user is signed out, the app continues to use local SharedPreferences storage.

This keeps local-first usage working while allowing cloud sync once the backend is ready.
