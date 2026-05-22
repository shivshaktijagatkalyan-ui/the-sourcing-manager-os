# TRAINING MODE PRODUCTION GATE REPORT

Date: 2026-05-12

## Result

PASS.

Training/demo mode is now gated by build context. Release builds default to `SM_OS_ENV=production`, and production builds cannot enter training mode from URL query parameters, local storage, or drawer/login switches.

## Changed

- `app_config.dart`
  - Added `SM_OS_ENV` build environment.
  - Added `allowsTrainingMode`.
  - Ignores `training=true` and `mockRole` URL overrides unless the build is local/dev.
  - Clears persisted training mode when training is not allowed.
- `role_resolver.dart`
  - Returns `anonymous` instead of honoring mock roles when training mode is not allowed.
- `main.dart`
  - Auto-training fallback now only works when `AppConfig.allowsTrainingMode` is true.
  - Training switch is hidden when training mode is not allowed.
- `login_screen.dart`
  - Training switch is hidden when training mode is not allowed.

## Verified

- `flutter analyze` passed.
- `flutter build web --release` passed.
- `flutter build apk --release` passed.

## Remaining Risk

Debug/local builds can still use training mode by design. Production distribution must use the default release production environment and must not set `--dart-define=SM_OS_ENV=dev`.
