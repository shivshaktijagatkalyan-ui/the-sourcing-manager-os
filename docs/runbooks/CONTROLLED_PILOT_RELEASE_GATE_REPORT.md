# CONTROLLED PILOT RELEASE GATE REPORT

Generated: 2026-05-18T05:49:02.4940455Z

| Step | Status | Exit Code | Duration Seconds |
| --- | --- | ---: | ---: |
| Security constitution scan | PASS | 0 | 1.4 |
| Root TypeScript check | PASS | 0 | 2.8 |
| Supabase function/config drift check | PASS | 0 | 0.1 |
| Supabase migration dry run | PASS | 0 | 4 |
| Flutter analyze | PASS | 0 | 12 |
| Flutter web release build | PASS | 0 | 68.4 |
| Flutter APK release build | PASS | 0 | 155.3 |
| Trust loop UAT | FAIL | 1 | 44.1 |

## Result

FAIL - controlled pilot release gate did not pass.
