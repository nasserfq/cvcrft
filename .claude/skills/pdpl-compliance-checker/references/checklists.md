# PDPL Domain Checklists

Run only in-scope domains. For each item record: Status (Pass / Gap / Partial / Unknown), Evidence, Article. No Pass without evidence.

## 1. Legal basis & consent (Arts. 5–7, 10)
- [ ] Every processing purpose is mapped to a legal basis (consent or an Art. 6 exception)
- [ ] Legitimate interest is NOT relied on for sensitive data (Art. 6 prohibits it)
- [ ] Consent is specific, informed, freely given; not bundled as a service condition unless directly connected (Art. 7)
- [ ] Consent withdrawal is as easy as granting, and downstream processing actually stops on withdrawal
- [ ] Data collected directly from the subject, or an Art. 10 exception documented
- [ ] Consent records are retained and producible (who, when, what version of the notice)

## 2. Privacy notices & transparency (Arts. 11, 13)
- [ ] Notice presented at or before collection
- [ ] Notice contains: purpose, legal basis, collector identity, recipients, disclosure/transfer intentions, retention, subject rights (Art. 13)
- [ ] Arabic version available and legally consistent with any English version
- [ ] Notice matches actual system behavior (compare against real data flows — mismatch is a Critical gap)

## 3. Data subject rights handling (Art. 4 + IR)
- [ ] Intake channel exists for access / copy / correction / destruction requests
- [ ] Identity verification proportional to request sensitivity
- [ ] Response workflow with tracked deadlines (baseline 30 days — [FLUX], verify IR)
- [ ] Copy provided in clear, readable format
- [ ] Destruction requests propagate to backups, processors, and downstream systems (or documented exception)
- [ ] Requests, decisions, and timestamps logged (producible to SDAIA)

## 4. Cross-border transfers (Art. 29 + TR)
- [ ] Complete inventory of data leaving KSA: cloud regions, SaaS, analytics SDKs, LLM/AI APIs, support tooling, backups
- [ ] Each transfer mapped to a mechanism (SCCs / BCRs / exemption) — no adequacy list is published as of mid-2026, so "adequate country" cannot be assumed ([FLUX], verify)
- [ ] Risk assessment performed for transfers involving sensitive data or large scale (SDAIA Feb 2025 guideline)
- [ ] Minimum-necessary principle applied to transferred fields (Art. 29)
- [ ] Transfer documentation maintained (contract clauses, assessments) and producible
- [ ] For AI features: does raw personal data reach an external model API? If yes — mechanism + legal basis required; strongly consider derived/de-identified features only [ADVISORY]

## 5. Breach detection & notification (Arts. 19–20 + IR)
- [ ] Technical capability to detect unauthorized access/leakage exists (logging, alerting)
- [ ] Breach response plan exists, tested, with roles named
- [ ] SDAIA notification path known (72-hour baseline — [FLUX], proposed amendments revise breach definitions)
- [ ] Data subject notification criteria and templates prepared
- [ ] Processor contracts obligate prompt breach reporting to the controller

## 6. DPO, registration & records (Arts. 30–31 + SDAIA rules)
- [ ] DPO requirement assessed against criteria (public entity / large-scale systematic monitoring / sensitive-data core activity); appointment documented if required ([FLUX] — rules being folded into IR)
- [ ] DPO contact submitted/updated on SDAIA platform if appointed
- [ ] RoPA exists, current, and covers: purposes, categories, recipients, transfers, retention (Art. 31)
- [ ] National Data Governance Platform controller registration status confirmed
- [ ] Ability to answer a SDAIA compliance inquiry within days (single owner, document index)

## 7. Security & retention (Arts. 18–19)
- [ ] Access control: least privilege on personal data stores; admin access logged
- [ ] Encryption in transit and at rest for personal data; key management documented
- [ ] Retention schedule per purpose; automated or procedural deletion at expiry (Art. 18)
- [ ] Anonymization/destruction methods meet IR standards; "deleted" data verified gone from derived stores
- [ ] Environments segregated: production personal data not in dev/test without masking [ADVISORY]

## 8. AI systems processing personal data (Art. 22 + AI Adoption Framework)
- [ ] DPIA performed for AI features processing personal data (Art. 22 — new technologies trigger)
- [ ] AI Adoption Framework five pillars assessed: data governance, model accountability, transparency, human oversight, risk management
- [ ] Training/fine-tuning data provenance: no personal data used without legal basis
- [ ] Prompt/context construction audited: what personal fields reach the model, and why each is necessary (minimization)
- [ ] Model outputs cannot disclose one subject's personal data to another user
- [ ] Human oversight defined for consequential automated decisions [ADVISORY — verify sector rules]
- [ ] Users informed they are interacting with AI where the framework requires transparency

## 9. Vendors & processors (Art. 8)
- [ ] Written contract with every processor: instructions, security guarantees, sub-processor rules, breach reporting, deletion at termination
- [ ] Processor inventory current; each mapped to data categories and locations
- [ ] Sub-processor chains known at least one level down
- [ ] Vendor offboarding includes verified data return/destruction
- [ ] Controller-side monitoring of processor compliance (attestations, audits) [ADVISORY]

## Severity quick-map
- **Critical**: no legal basis; sensitive data disclosed or sent cross-border without mechanism (Art. 35 criminal exposure); notice contradicts actual behavior
- **High**: missing RoPA, DPO (where required), breach plan, DSR workflow, platform registration
- **Medium**: control exists but weak/untested/undocumented
- **Low**: documentation and polish
