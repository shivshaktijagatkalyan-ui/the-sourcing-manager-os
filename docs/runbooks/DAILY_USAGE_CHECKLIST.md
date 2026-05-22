# Daily Sourcing Operations Checklist

Follow this routine every day during the 7-day Pilot for **The Wadhwa Wise City, Panvel**.

---

## 🌅 Morning: Setup & Planning (15 Mins)

- [ ] **Check Security**: Run `python scripts/security-check.py` to verify the environment.
- [ ] **Open Dashboard**: Check "DUE TODAY" count in the Sourcing Dashboard.
- [ ] **Review Queue**: Open `Today's Follow-ups` and identify High-Priority (Hot) brokers.

## 📞 Peak Hours: Broker Activation (Daily Work)

- [ ] **Secure Call**: Use the call button for every follow-up.
- [ ] **Update Stage**: Immediately move the broker stage (e.g., `First Call Done` -> `Project Explained`).
- [ ] **Set Next Task**: Always set the `Next Follow-up Date` before closing a broker detail view.
- [ ] **Log Notes**: Add a quick `notes_safe` (e.g., "Wadhwa inventory PDF") after every call.

## 📥 Real-Time: Lead Intake

- [ ] **Secure Intake**: As soon as a broker shares a lead, open `Add Lead from Broker`.
- [ ] **Wipe PII**: Ensure you clear the phone input before submitting if entering manually.
- [ ] **Verify Source**: Confirm the lead is linked to the correct `source_broker_alias`.

## 📍 On-Site: Visit Verification

- [ ] **Schedule Visit**: Convert the lead to a `visit_scheduled` state.
- [ ] **Verify Proof**: Ensure GPS verification and live photo are captured at the site.
- [ ] **Link Source**: Confirm the visit shows the source broker's alias for performance tracking.

## 🌇 Evening: Review & Audit (10 Mins)

- [ ] **Close Queue**: Ensure all "Pending" follow-ups for today are either `Completed` or `Rescheduled`.
- [ ] **Check Pipeline**: Look at the `Activation Pipeline Board`—any bottlenecks?
- [ ] **Sync Log**: Record any friction or "pain points" in the `PILOT_FEEDBACK_LOG.md`.
