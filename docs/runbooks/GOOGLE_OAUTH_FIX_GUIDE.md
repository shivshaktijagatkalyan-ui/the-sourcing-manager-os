# Google OAuth Login Flow - Fix & Setup Guide

## What Was Fixed

### 1. **OAuth Callback Handling** (NEW)

- Created `AuthService` singleton to centralize all OAuth logic
- Added automatic OAuth callback detection and token exchange
- Supabase Flutter now properly handles the callback URL and session establishment

### 2. **Auth State Management** (IMPROVED)

- Implemented `AuthService.initialize()` called on app startup
- Auth state changes now properly propagate to UI
- Role resolver fetches user role immediately after OAuth completes

### 3. **Error Messages** (ENHANCED)

- Added specific error messages for each OAuth failure scenario
- Login screen now shows "Signing in..." state during OAuth
- Users see clear feedback instead of silent failures

### 4. **URL Cleanup** (ADDED)

- OAuth callback URLs are detected and cleaned after session established
- Browser history no longer cluttered with `?code=` parameters

---

## Prerequisites

### 1. Supabase Project Setup

- [Create a Supabase project](https://database.new)
- Select **India (Mumbai)** region for production compliance
- Note your project URL and anon key

### 2. Google OAuth Credentials (Already Configured)

Your Supabase project has Google OAuth enabled:

- **Client ID**: `1003222071356-4ca6onu3tmpjqpp1ttbi8bktf5ftq3m7.apps.googleusercontent.com`
- **Project ID**: `uplifted-mantra-495809-g8`
- **Redirect URI**: `https://gblvnjilpcxhygvzikwe.supabase.co/auth/v1/callback`

If you need to change this for production, see **"Updating Google OAuth Credentials"** below.

---

## Running the App Locally

### Option 1: With Supabase Connection (Recommended)

1. **Set Environment Variables**

```bash
# On Windows PowerShell:
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_ANON_KEY="your-anon-key"

# On macOS/Linux:
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
```

1. **Run the App**

```bash
cd flutter_app
flutter clean
flutter pub get
flutter run -d chrome
```

1. **Test Google Login**
   - Click "Sign in with Google" button
   - You'll be redirected to Google login
   - After Google auth, you'll be redirected back to your app
   - Role dashboard should load automatically

### Option 2: Training Mode (For Offline Testing)

Open the app with training mode enabled:

```bash
# Via URL parameter
flutter run -d chrome

# Then open browser to:
http://localhost:YOUR_PORT/?mockRole=sourcing_manager

# Or toggle the switch in the app's login screen
```

---

## OAuth Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│ User clicks "Sign in with Google"                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ AuthService.signInWithGoogle()                          │
│ - Calls Supabase.auth.signInWithOAuth(OAuthProvider.    │
│   google, redirectTo: Uri.base.toString())              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │ Redirect to Google    │
         │ accounts.google.com   │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │ User enters creds     │
         │ Google authenticates  │
         └───────────┬───────────┘
                     │
                     ▼
   ┌─────────────────────────────────┐
   │ Google redirects to:            │
   │ YOUR_SUPABASE_URL/auth/v1/      │
   │ callback?code=CODE&state=STATE  │
   └─────────────┬───────────────────┘
                 │
                 ▼
   ┌──────────────────────────────────┐
   │ Supabase exchanges CODE for JWT  │
   │ (Automatic via supabase_flutter) │
   └─────────────┬────────────────────┘
                 │
                 ▼
   ┌──────────────────────────────────┐
   │ AuthService._handleOAuthCallback │
   │ - Detects ?code= parameter       │
   │ - Cleans URL                     │
   │ - Broadcasts auth state change   │
   └─────────────┬────────────────────┘
                 │
                 ▼
   ┌──────────────────────────────────┐
   │ MainNavigation listens to auth   │
   │ state and calls _fetchRole()     │
   └─────────────┬────────────────────┘
                 │
                 ▼
   ┌──────────────────────────────────┐
   │ RoleResolver.currentRole() gets  │
   │ user role from Supabase JWT      │
   └─────────────┬────────────────────┘
                 │
                 ▼
   ┌──────────────────────────────────┐
   │ User Dashboard Loads             │
   │ (Broker/Caller/Manager/Admin)    │
   └──────────────────────────────────┘
```

---

## Testing Checklist

- [ ] **Email/Password Login Works**
  - Enter test credentials
  - Click "SECURE SIGN IN"
  - Verify dashboard loads

- [ ] **Google OAuth Initiation**
  - Click "Sign in with Google"
  - Verify redirects to Google login page
  - Verify popup is not blocked

- [ ] **Google OAuth Completion**
  - Enter Google credentials
  - Verify redirects back to app
  - Verify URL is cleaned (no `?code=` parameter)
  - Verify dashboard loads with correct role

- [ ] **Auth State Persistence**
  - Reload page (Ctrl+R / Cmd+R)
  - Verify still logged in (user not redirected to login)

- [ ] **Training Mode**
  - Toggle "TRAINING MODE" switch
  - Verify dashboard works without Supabase
  - Verify "TRAINING" badge appears in app bar

- [ ] **Logout**
  - Click logout in drawer
  - Verify redirected to login screen
  - Verify cannot access dashboard without re-login

---

## Troubleshooting

### Issue: "Google login failed: Unable to launch"

**Cause**: Popup blocker or browser security issue
**Fix**:

1. Allow popups for your app domain
2. Check browser console for detailed errors (F12 → Console)
3. Ensure `redirect_uri` in `supabase/config.toml` matches your domain

### Issue: "Supabase is not configured"

**Cause**: Environment variables not set
**Fix**:

```bash
# Verify environment variables are set:
echo $SUPABASE_URL
echo $SUPABASE_ANON_KEY

# If empty, set them again
export SUPABASE_URL="..."
export SUPABASE_ANON_KEY="..."

# Then restart flutter
flutter run -d chrome
```

### Issue: User logged in but gets "Access Restricted"

**Cause**: User role not set in Supabase or user not activated
**Fix**:

1. Check Supabase Dashboard → Authentication → Users
2. Verify user exists and is confirmed
3. Check user_roles table to ensure role is assigned
4. Ensure user's organization is not paused

### Issue: OAuth redirects in loop

**Cause**: Session token expired or invalid JWT
**Fix**:

1. Clear browser cookies for Supabase domain
2. Clear Flutter/Dart cache: `flutter clean`
3. Restart browser and app

### Issue: Role dashboard shows "loading" forever

**Cause**: RoleResolver failing to fetch role
**Fix**:

1. Check browser console (F12 → Console)
2. Verify user has a row in `user_roles` table
3. Check RLS policies on `user_roles` allow SELECT

---

## Updating Google OAuth Credentials (For Production)

When deploying to production, you'll need new Google OAuth credentials:

### 1. Get New Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new OAuth 2.0 Client ID (type: Web Application)
3. Add your production domain to "Authorized JavaScript origins"
4. Add your production callback URL to "Authorized redirect URIs":

   ```
   https://YOUR_PRODUCTION_DOMAIN.supabase.co/auth/v1/callback
   ```

5. Note the new Client ID and Client Secret

### 2. Update Supabase Config

Edit `supabase/config.toml`:

```toml
[auth.external.google]
enabled = true
client_id = "YOUR_NEW_CLIENT_ID.apps.googleusercontent.com"
secret = "YOUR_NEW_CLIENT_SECRET"
redirect_uri = "https://YOUR_PRODUCTION_DOMAIN.supabase.co/auth/v1/callback"
```

### 3. Redeploy

```bash
supabase link --project-ref your-production-project
supabase push
```

---

## Files Modified

1. **`flutter_app/lib/utils/auth_service.dart`** (NEW)
   - Centralized OAuth and auth management
   - Handles OAuth callback detection
   - Manages auth state streams

2. **`flutter_app/lib/screens/login_screen.dart`** (UPDATED)
   - Uses AuthService instead of direct Supabase calls
   - Better error handling and user feedback
   - OAuth callback handling integrated

3. **`flutter_app/lib/main.dart`** (UPDATED)
   - Initializes AuthService on app startup
   - Improved auth state change logging
   - OAuth callback support in MainNavigation

---

## Next Steps

1. **Test locally** with your Supabase project
2. **Create test users** in Supabase Auth
3. **Assign roles** to users in `user_roles` table
4. **Run full UAT** (see Phase 7 in launch roadmap)
5. **Deploy to production** when ready

For deployment instructions, see `DEPLOYMENT.md`.
