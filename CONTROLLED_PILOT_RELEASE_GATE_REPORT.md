# CONTROLLED PILOT RELEASE GATE REPORT

Generated: 2026-05-22T05:44:16.3734477Z

| Step | Status | Exit Code | Duration Seconds |
| --- | --- | ---: | ---: |
| Security constitution scan | PASS | 0 | 1.3 |
| Root TypeScript check | PASS | 0 | 2 |
| Supabase function/config drift check | PASS | 0 | 0.1 |
| Supabase migration dry run | FAIL | 1 | 3.4 |
| Flutter analyze | PASS | 0 | 11.2 |
| Flutter web release build | PASS | 0 | 66.7 |
| Flutter APK release build | PASS | 0 | 10.2 |
| Trust loop UAT | PASS | 0 | 39.5 |

## Result

FAIL - controlled pilot release gate did not pass.
