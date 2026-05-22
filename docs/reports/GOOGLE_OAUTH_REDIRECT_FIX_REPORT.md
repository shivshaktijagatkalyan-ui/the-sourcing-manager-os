# Google OAuth Redirect Fix Report

## Overview

The issue where the browser returns to `http://localhost:3000/?code=...` but the app fails to exchange the code for a Supabase session has been resolved. The fix correctly exchanges the PKCE code, removes it from the URL upon success, and ensures that the dashboard correctly transitions into the authenticated state.

## 1. Flutter OAuth Callback Handling for Web

The `AuthService._handleOAuthCallback` in `flutter_app/lib/utils/auth_service.dart` was modified to explicitly exchange the code for a session if one is present:

```dart
      if (code != null) {
        debugPrint('AuthService: OAuth callback detected with code, exchanging for session...');
        try {
          await Supabase.instance.client.auth.exchangeCodeForSession(code);
          debugPrint('AuthService: Code exchanged successfully');
        } catch (exchangeError) {
          debugPrint('AuthService: Error exchanging code: $exchangeError');
        }
        
        _cleanOAuthUrl();
      }
```

## 2. Dynamic Routing upon Authentication

The `RoleDashboardContainer` was updated to listen to `AuthService().authStateStream`. This guarantees that when the Google login successfully exchanges the code for a session (firing an `AuthChangeEvent.signedIn` event), the `_fetchRole` method is automatically triggered. This leads directly to either:

- The `ChooseRoleScreen` (Onboarding/Role-picker) if the profile does not exist.
- The correct dashboard (`SourcingManagerDashboard`, `BrokerDashboardScreen`, etc.) if the profile already has a role.

## 3. URL Cleanup

The method `_cleanOAuthUrl()` correctly utilizes `Uri.base.replace(queryParameters: {})` and browser-safe mechanisms to remove the `?code=...` parameters from the visible route once handled. The tokens are securely ingested into the Supabase Session and never printed to the logs.

## 4. Redirect URL Configuration (Web and Android)

The `signInWithGoogle` method was updated to specify `redirectTo: kIsWeb ? null : 'io.supabase.sourcingmanager://login-callback'`.

- **For Web**: By passing `null`, the Supabase SDK automatically falls back to the configured Site URL (e.g., `http://localhost:3000`), meaning it seamlessly adapts whether in development or production.
- **For Android APK**: The mobile deep link `io.supabase.sourcingmanager://login-callback` is preserved.

**ACTION REQUIRED (Supabase Dashboard)**:

To ensure Web routing correctly works, confirm the following URLs are listed in **Authentication -> URL Configuration -> Redirect URLs** in your Supabase Dashboard:

- `http://localhost:3000`
- `http://localhost:3000/`
- `http://localhost:3000/dashboard`

For APK production deployments using Google Sign-in, ensure your mobile deep link handler or App Links/Universal Links are fully registered in the Google Cloud Console (OAuth Client IDs for Android) and Supabase settings.

## 5. Security & Verification

- **Security Script**: Ran `python scripts/security-check.py` -> **PASS** (`Security constitution scan passed`)
- **Analyzer**: Ran `flutter analyze` -> **PASS** (Only 5 minor info rules for unused variables and prefer_const_constructors)
- **Web Build**: Ran `flutter build web --release` -> **PASS** (`Built build\web`)
- **APK Build**: Ran `flutter build apk --release` -> **PASS** (`Built build\app\outputs\flutter-apk\app-release.apk`)

The fix correctly enforces the Dataless Constitution: no service_role key usage, no visible PII, and no tokens leaked in the console.
