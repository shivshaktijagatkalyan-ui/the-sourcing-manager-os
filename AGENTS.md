# Agent Verification Guidance

This project is a **Flutter / Supabase** hybrid application. Standard Node.js build patterns do not apply to the root directory.

## Build and Typecheck Gates

### `npm run build`
**Status: Not Applicable / Redirected**
There is no root Node.js build process. The production build artifact for this repository is the Flutter Web PWA, which is built using:
`cd flutter_app && flutter build web --release`

### `npx tsc --noEmit`
**Status: Not Applicable**
TypeScript is used exclusively within Supabase Edge Functions. These are managed by the Supabase CLI (`supabase functions deploy`) which handles its own bundling and type checking via Deno. There is no global `tsconfig.json` in the root because it would conflict with the Deno-based Edge Function environments.

## Deployment Gates

Deployment requires:
1. Supabase CLI (`supabase db push`)
2. Flutter SDK (`flutter build web`)
3. Edge Function deployment (`supabase functions deploy <name>`)

Verification should focus on `REAL_BUILD_VERIFICATION_REPORT.md` and the individual Sprint smoke test results.
