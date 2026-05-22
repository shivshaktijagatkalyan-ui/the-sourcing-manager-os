# LAUNCH RUNBOOK
## The Sourcing Manager OS v1.0.0 → Production

**Execute on:** Launch Day (T-0)
**Duration:** 2-3 hours
**Prepared by:** Deployment Gate System
**Version:** 1.0.0-stable

---

## Pre-Flight Checklist (T-2 hours)

### Prerequisites ✅
- [ ] Legal team has signed off on Privacy Policy + Terms
- [ ] Exotel SID, API Key, Token configured in Supabase Vault
- [ ] Domain DNS updated to point to production server
- [ ] Monitoring dashboard accessible to ops team
- [ ] Incident response team on standby (Slack channel active)
- [ ] Rollback procedures rehearsed
- [ ] Database backup completed
- [ ] Ops team trained on runbook

### Verification Steps
```bash
# 1. Verify Supabase connectivity
supabase link --project-ref gblvnjilpcxhygvzikwe
supabase projects list

# 2. Verify database schema
supabase db list

# 3. Verify Edge Functions deployed
supabase functions list

# 4. Verify secrets configured
supabase secrets list
```

---

## LAUNCH SEQUENCE

### Phase 1: Pre-Launch Verification (T-1:30)

```bash
# Step 1: Verify production database
echo "1. Testing Supabase connectivity..."
curl -H "apikey: $SUPABASE_ANON_KEY" \
  https://gblvnjilpcxhygvzikwe.supabase.co/rest/v1/leads_public?limit=1

# Expected: Empty list (new database) or existing leads

# Step 2: Verify Edge Functions
echo "2. Checking broker-upload-lead function..."
curl -H "apikey: $SUPABASE_ANON_KEY" \
  https://gblvnjilpcxhygvzikwe.supabase.co/functions/v1/broker-upload-lead

# Expected: 405 Method Not Allowed (function exists)

# Step 3: Verify auth system
echo "3. Testing Supabase Auth..."
curl -X POST \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test"}' \
  https://gblvnjilpcxhygvzikwe.supabase.co/auth/v1/signup

# Expected: 429 (rate limited) or 400 (user exists) - both OK

echo "✅ Pre-flight verification complete"
```

**Decision Gate:** If all checks pass, proceed to Phase 2. If any fail, ABORT and investigate.

---

### Phase 2: Deploy Web App (T-1:00)

```bash
# Step 1: Build production Flutter app
cd flutter_app
flutter clean
flutter pub get
flutter analyze

# Expected: No errors or warnings

# Step 2: Build web release
flutter build web --release

# Expected: "√ Built build/web"

# Step 3: Verify build output
ls -la build/web/
# Expected: index.html, main.dart.js, assets/ folder present

# Step 4: Deploy to production server
# (Customize based on your hosting - Firebase, Vercel, Docker, etc.)
echo "Deploying to production..."
# Example for Firebase:
firebase deploy --only hosting

# Expected: Deployment successful message

echo "✅ Web app deployed"
```

**Decision Gate:** If build fails, investigate Dart/Flutter errors and retry. Do NOT deploy broken app.

---

### Phase 3: Configure Secrets (T-0:45)

```bash
# Step 1: Set Exotel credentials
echo "Setting Exotel secrets..."
supabase secrets set EXOTEL_SID=$EXOTEL_SID
supabase secrets set EXOTEL_AUTH_TOKEN=$EXOTEL_AUTH_TOKEN
supabase secrets set EXOTEL_ACCOUNT_SID=$EXOTEL_ACCOUNT_SID
supabase secrets set EXOTEL_CALLER_ID=$EXOTEL_CALLER_ID

# Expected: "Secrets set successfully"

# Step 2: Set encryption key
supabase secrets set PHONE_ENCRYPTION_KEY=$PHONE_ENCRYPTION_KEY

# Expected: "Secrets set successfully"

# Step 3: Verify secrets (verify only, won't show values)
supabase secrets list

# Expected: All secrets listed

echo "✅ Secrets configured"
```

**⚠️ IMPORTANT:** Do NOT commit secrets to Git. Use Supabase Vault only.

---

### Phase 4: Test Complete Flow (T-0:30)

```bash
# Step 1: Create test broker account
echo "Creating test broker account..."
# Via Supabase Dashboard:
# 1. Go to Authentication → Users
# 2. Click "Create new user"
# 3. Email: test.broker@sourcing-manager-os.test
# 4. Password: TempTest@2026!Change
# 5. Click Create

# Step 2: Test broker lead upload
echo "Testing lead upload..."
node scripts/uat-phase1-auth.mjs

# Expected: "✅ Lead inserted"

# Step 3: Test manager access
echo "Testing manager queue..."
# Create manager user in Supabase Dashboard
# Then verify in Flutter app (http://your-domain)

# Step 4: Test complete cycle
echo "Testing GPS verification and commission lock..."
# Manually verify via Flutter app dashboard

echo "✅ Complete flow tested"
```

**Decision Gate:** If tests fail, check logs and fix before proceeding.

---

### Phase 5: Activate Monitoring (T-0:15)

```bash
# Step 1: Verify health dashboard
echo "Checking monitoring dashboard..."
curl https://your-domain/health

# Expected: {"status":"healthy","timestamp":"..."}

# Step 2: Test rate limiting
echo "Testing rate limit alerts..."
for i in {1..100}; do
  curl https://your-domain/api/leads -H "Authorization: Bearer $TOKEN" &
done
wait

# Expected: Some requests blocked with 429 error

# Step 3: Verify audit logging
echo "Checking audit trail..."
# Query audit_events table - should show test actions

echo "✅ Monitoring active"
```

---

### Phase 6: DNS Cutover (T-0:00) 🚀

```bash
# Step 1: Update DNS (your registrar)
# Change:  your-domain.com A record → production-ip
#
# Old:  your-domain.com A 10.0.0.1 (staging)
# New:  your-domain.com A 10.0.0.2 (production)

echo "DNS updated. Waiting for propagation..."
sleep 60

# Step 2: Verify domain resolves to production
nslookup your-domain.com

# Expected: Points to production IP

# Step 3: Test production URL
curl https://your-domain.com/health

# Expected: {"status":"healthy"}

# Step 4: Send notification to team
echo "✅ GO LIVE - Production is now active"
```

---

## POST-LAUNCH CHECKLIST (T+1 hour)

### Monitoring ✅
- [ ] Web app responsive (http://your-domain)
- [ ] Google OAuth login working
- [ ] Lead upload succeeding
- [ ] Manager queue populating
- [ ] No 5xx errors in logs
- [ ] Rate limiting active

### Performance ✅
- [ ] Page load time < 3 seconds
- [ ] API response time < 1 second
- [ ] Database queries not timing out
- [ ] No memory leaks detected

### Security ✅
- [ ] HTTPS working (green padlock)
- [ ] RLS policies enforced
- [ ] Audit trail logging all actions
- [ ] No exposed secrets in logs

### Data Integrity ✅
- [ ] Test leads created successfully
- [ ] Encryption working (phone numbers not visible)
- [ ] Commission locks applied correctly
- [ ] Payouts calculated accurately

---

## ROLLBACK PROCEDURE (If needed)

### Immediate Actions (< 5 minutes)

```bash
# Step 1: Switch DNS back to staging
# Update your-domain.com A record → staging-ip

# Step 2: Kill production deployment (if needed)
supabase projects stop gblvnjilpcxhygvzikwe

# Step 3: Notify team
echo "⚠️ ROLLBACK INITIATED - Reverting to staging"
```

### Investigation (5-30 minutes)

```bash
# Check logs
supabase logs --project-ref gblvnjilpcxhygvzikwe

# Check database
supabase db --project-ref gblvnjilpcxhygvzikwe

# Review errors in Slack #incidents channel
```

### Recovery (30+ minutes)

```bash
# Restore from backup
supabase db restore --project-ref gblvnjilpcxhygvzikwe

# Re-run migrations if needed
supabase db push --project-ref gblvnjilpcxhygvzikwe

# Verify schema
supabase db list --project-ref gblvnjilpcxhygvzikwe
```

---

## INCIDENT RESPONSE

If production is down:

1. **IMMEDIATE:** Declare incident in #incidents Slack
2. **FIRST 5 MIN:** Check Supabase status page + health dashboard
3. **FIRST 15 MIN:** Review recent deploys, database queries, error logs
4. **FIRST 30 MIN:** Execute rollback procedure above
5. **ONGOING:** Document all steps taken for postmortem

**Escalation:**
- Tech Lead: [name] ([phone])
- On-Call: [rotation schedule]
- Supabase Support: support@supabase.io

---

## SUCCESS CRITERIA

Launch is successful when:

- ✅ Web app accessible at production URL
- ✅ Google OAuth login working
- ✅ Test broker can upload lead
- ✅ Manager can view lead in queue
- ✅ Commission lock mechanism working
- ✅ Audit trail recording events
- ✅ No errors in monitoring dashboard
- ✅ Team in control center confirms all systems go

---

## TEAM ROLES (Launch Day)

| Role | Person | Responsibility |
|------|--------|-----------------|
| **Incident Commander** | [Name] | Overall coordination, escalation decisions |
| **Tech Lead** | [Name] | System monitoring, troubleshooting |
| **Database Admin** | [Name] | Schema verification, backup monitoring |
| **Ops Lead** | [Name] | Infrastructure, DNS, deployment |
| **Communications** | [Name] | Slack updates, stakeholder notification |
| **Backup Tech** | [Name] | Rollback procedures, escalation support |

---

## COMMUNICATION TEMPLATE

### Pre-Launch Notification (T-24 hours)
```
🚀 PRODUCTION LAUNCH SCHEDULED

Date: [Tomorrow]
Time: [HH:MM UTC]
Expected Duration: 2-3 hours
Impact: User-facing app will be unavailable during cutover

Watch #incidents channel for updates.
```

### Go-Live Notification
```
✅ GO LIVE - PRODUCTION ACTIVE

The Sourcing Manager OS is now live!
- 🌐 Available at: https://your-domain.com
- 🔐 Secure login with Google OAuth enabled
- 📊 Dashboard and lead queue operational

Thank you for your patience during launch preparation.
```

### Issue Notification (If needed)
```
⚠️ KNOWN ISSUE

Issue: [Description]
Status: [Investigating / Mitigating / Resolved]
ETA: [Time estimate]
Workaround: [If available]

Updates every 15 minutes in #incidents
```

---

## FINAL NOTES

- **Do not skip steps** — Follow runbook exactly
- **Communicate delays** — If any phase takes > expected time, notify team
- **Document everything** — Screenshot console output, timestamps, decisions
- **Celebrate carefully** — Declare success only after 1 hour of monitoring shows stability
- **Postmortem scheduled** — Day after launch, review what went well and improvements

---

**Runbook Version:** 1.0.0-stable
**Last Updated:** 2026-05-18
**Next Review:** After first production deploy
**Approved by:** [Sign off here]

---

## QUICK REFERENCE

```
Phase 1: Pre-flight verification
Phase 2: Deploy web app
Phase 3: Configure secrets
Phase 4: Test complete flow
Phase 5: Activate monitoring
Phase 6: DNS cutover ← GO LIVE

Total time: 2-3 hours
Success criteria: All monitoring green ✅
Rollback: Change DNS + restore from backup
```

**Status: READY FOR LAUNCH** 🚀
