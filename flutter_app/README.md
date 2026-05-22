# sourcing_manager_os

A Flutter Web PWA frontend for The Sourcing Manager OS.

## Local development

### Prerequisites

- Flutter SDK 3.x or later
- Chrome browser
- Supabase CLI / Supabase project credentials (for full auth flow)

### Run locally

```powershell
cd flutter_app
flutter clean
flutter pub get
flutter run -d chrome --web-renderer html --web-port 8081 --dart-define=SUPABASE_URL="https://your-project.supabase.co" --dart-define=SUPABASE_ANON_KEY="your-anon-key"
```

### Training mode

If Supabase is not configured, the app will fall back to demo training mode by default.
Use `?mockRole=sourcing_manager` in the web URL to force a mock role.

Example:

```powershell
flutter run -d chrome --web-renderer html --web-port 8081
```

Then open:

```
http://localhost:8081/?mockRole=sourcing_manager
```

### Debugging blank screen issues

- Open DevTools Console and look for `main: startup begin`.
- Verify `Supabase.initialize` logs and any errors.
- Confirm the page shows the loader text from `web/index.html`.
- If the page stays blank, there may be a widget build failure or a missing `dart-define` value.

## Notes

The app uses `AppConfig` with compile-time environment variables for Supabase.
If you are running without Supabase, use training mode or local mock roles.
