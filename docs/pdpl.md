# PDPL compliance record (Seera / cvcrft)

Internal record for the Saudi Personal Data Protection Law (PDPL). Last reviewed 2026-10-19,
privacy policy version `2026-10-19` (`PrivacyPolicy::VERSION`).

This is an engineering record, not legal advice. A Saudi-qualified lawyer should review it before
anyone relies on it with SDAIA or in a contract.

- Controller: Seera (cvcrft). The legal entity name is still to be filled in by the owner.
- Privacy contact: `privacy@cvcrft.com`
- Users: mainly Saudi residents. We do not offer the service to anyone under 18.
- Public notice: `/privacy` (Arabic and English) and `/terms`.

## 1. Record of processing activities (RoPA)

| Data category | Purpose | Legal basis | Processor | Location | Retention |
|---|---|---|---|---|---|
| Email, OTP login codes | Sign-in by one-time code | Contract | Own DB; AWS SES sends the email | Germany (DB); USA (SES) | OTP codes: 1 day. Email: until account deletion |
| Account profile (name, phone, city, locale, consent record) | Run the account | Contract | Own DB on netcup | Germany | Until the user deletes the account |
| CV content (work history, education, skills, certifications, languages) | Build and edit CVs | Contract | Own DB on netcup | Germany | Until the user deletes the account |
| Uploaded CVs and LinkedIn imports (extracted text) | Import an existing CV | Consent (upload) + contract | Own DB on netcup | Germany | Extracted text cleared after 30 days; failed imports deleted after 30 days |
| CV text sent for AI analysis, generation, translation, coaching | AI features | Consent (privacy policy at login) + contract | AWS Bedrock (us-east-1) | USA | Not kept by us beyond the results below |
| AI coach answers (quality check) | Check answer quality | Legitimate interest | TypeSafe Jev | USA | Per processor DPA (to confirm) |
| AI results (analyses, translations, coach chats) | Show results to the user | Contract | Own DB on netcup | Germany | Failed analyses deleted after 30 days; extracted text cleared after 30 days; the rest until account deletion |
| Generated PDFs | The user's own CV documents | Contract | Own DB on netcup | Germany | Kept with the account; deleted when the user deletes the account |
| Credit ledger and purchases | Paid credits | Contract | Own DB; Moyasar takes payment | Germany (DB); KSA (Moyasar) | Deleted with the account. Payment records stay with Moyasar under its own retention |
| Errors and stack traces (no user PII) | Detect and fix faults | Legitimate interest | Sentry | USA (ingest.us.sentry.io) | Per Sentry plan |
| Product analytics | Improve the product | Consent (cookie banner, can be withdrawn) | PostHog | USA | Per PostHog project settings |
| Server logs (user ids and counts, no emails or CV content) | Operations and security | Legitimate interest | netcup host | Germany | Per host log rotation |

Cross-border transfers: data leaves the Kingdom to Germany (hosting), the USA (Bedrock, SES,
PostHog, TypeSafe Jev) and possibly elsewhere (Sentry). No adequacy list has been published, so
each transfer relies on the processor's DPA/SCCs. Open owner actions: sign DPAs with AWS, netcup,
PostHog, Sentry, TypeSafe and Moyasar; write a transfer risk assessment; consider a Middle East
Bedrock region.

The retention rules are enforced by `DataRetentionJob` (`packs/accounts/app/jobs`), run daily at
03:15 by sidekiq-cron (`config/schedule.yml`). It logs counts only. The numbers above must match
the job and the retention section of `/privacy`.

## 2. Consent record

- The login email form has a required checkbox "I agree to the Privacy Policy and Terms". Without
  it, `AuthController#send_otp` sends no code.
- On successful `verify_otp` we store on `users`:
  - `privacy_accepted_at` (datetime): when the user accepted.
  - `privacy_policy_version` (string): the `PrivacyPolicy::VERSION` they accepted.
- Both are refreshed at every login where consent was given, so the row always holds the latest
  accepted version.
- Analytics consent is separate: the cookie banner gates PostHog and can be withdrawn at any time.
- When the policy changes materially: bump `PrivacyPolicy::VERSION` (it is also the "last updated"
  date on `/privacy`). Users with an older version accept again on their next login.

## 3. Data-subject requests

Rights: access, a copy (export), correction, deletion, withdrawal of consent, and complaint to SDAIA.

| Request | How it is handled |
|---|---|
| Access / copy | Self-service: profile page, "Download my data" (`GET /profile/export`), a JSON file `seera-data-<date>.json`. No password hashes, tokens or PDF blobs |
| Correction | Self-service: users edit their profile and CVs |
| Deletion | Self-service: profile page, "Delete my account". One transaction removes the user, CVs, imports, AI results, generated PDFs, credit ledger, purchases, coupon redemptions and OTP rows, then clears the coupon store. Nothing identifying is sent to PostHog |
| Withdraw consent | Cookie banner for analytics; account deletion for everything else |
| Anything else, or a user who cannot sign in | Email `privacy@cvcrft.com` |

For email requests:

1. Log the request (date, requester, type) in the request log kept by the owner.
2. Verify identity: the request must come from the account's email, or the user proves control of it with a login code.
3. Answer within 30 days of receipt. If more time is needed, tell the user why before the deadline.
4. Data held only by processors (PostHog persons, Sentry events, backups): delete in PostHog on
   request; Sentry and backups expire under their own retention. Tell the user this.
5. Record the outcome and the date closed.

## 4. Breach procedure

A breach is any unauthorized access, disclosure, loss or change of personal data, including at a
processor.

1. **Detect and contain (immediately).** Sources: Sentry alerts, server logs, processor notices,
   user reports to `privacy@cvcrft.com`. Stop the leak: rotate keys and credentials, revoke
   sessions, block the access path, take the affected part offline if needed. Keep the evidence
   (logs, timestamps), do not wipe it.
2. **Assess (within 24 hours of awareness).** What data, how many users, which processors, whether
   it was encrypted, and the likely harm to users. Decide whether it must be notified. If in doubt,
   treat it as notifiable and ask a lawyer.
3. **Notify SDAIA (within 72 hours of awareness).** Through SDAIA's National Data Governance
   Platform: what happened, data and users affected, likely consequences, measures taken, and the
   contact person. Send what is known by the deadline and update later.
4. **Notify affected users (without undue delay)** when the breach can harm them: in plain Arabic
   and English, what happened, what data, what we did, and what they should do (for example, watch
   for phishing).
5. **Keep a breach log.** Every incident, including ones judged not notifiable: date found,
   description, data and user count, decision and reason, notifications sent and when, fixes.
6. **Review.** After closing, record the root cause and the follow-up work.

The 72-hour and 30-day timings follow the current Implementing Regulations. SDAIA has published
draft amendments, so check them again when they are final.

## 5. Open owner actions

- Fill in the controller's legal entity name; create the `privacy@cvcrft.com` mailbox.
- Register on SDAIA's National Data Governance Platform.
- Sign the processor DPAs listed in section 1.
- With a lawyer: a DPIA for the AI features, a transfer risk assessment, and a decision on whether
  the 2026-10-12 `RAILS_MASTER_KEY` leak was notifiable.

## 6. Future reviews

The repo ships the `pdpl-compliance-checker` skill in `.claude/skills/pdpl-compliance-checker/`.
Use it for the next readiness review (for example after a new processor, a new AI feature, or the
final Implementing Regulations amendments), and update this file and `/privacy` with the result.
