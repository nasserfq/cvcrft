# PDPL Article Map (working reference)

Saudi Personal Data Protection Law — Royal Decree M/19 (16 Sept 2021), as amended by Royal Decree M/148 (27 Mar 2023). In force 14 Sept 2023; fully enforceable 14 Sept 2024. Supported by the Implementing Regulations (IR) and the Regulation on Personal Data Transfer Outside the Kingdom (Transfer Regulations, TR). IR amendments proposed via third public consultation (Apr–May 2025); verify final status before citing IR article numbers in high-stakes outputs — numbering may shift.

> Usage rule: cite from this map. If a needed provision is not in this map and web search is unavailable, label the finding [ADVISORY] or [FLUX] instead of guessing an article number.

## Definitions & scope
- **Art. 1** — Definitions: personal data, sensitive data (health, genetic, biometric, credit, criminal record, religious/ideological/security data), controller, processor, disclosure, destruction.
- **Art. 2** — Scope: applies to any processing of personal data of individuals residing in KSA, including by entities outside the Kingdom (extraterritorial). Excludes purely personal/family use.

## Legal basis & consent
- **Art. 5** — Consent is the default legal basis; conditions for valid consent; withdrawal must be possible at any time.
- **Art. 6** — Processing without consent permitted only in enumerated cases: actual interest of the data subject where contact is impossible/difficult, processing under another law, prior agreement to which the subject is party, legitimate interest of the controller (non-sensitive data only, and not conflicting with subject's rights/interests).
- **Art. 7** — Consent cannot be a condition of service unless the processing is directly connected to that service.
- **Art. 10** — Collection directly from the data subject as default; enumerated exceptions for indirect collection.

## Purpose, minimization, retention
- **Art. 11** — Purpose limitation: collection for lawful, specific, clear purposes; methods appropriate and not misleading.
- **Art. 13** — Content of privacy notice at collection: purpose, legal basis, identity of collector, recipients, whether data will be transferred/disclosed, retention, subject rights.
- **Art. 18** — Destruction when no longer necessary; anonymization standards per IR.

## Data subject rights
- **Art. 4** — Rights: to be informed, to access, to obtain a copy (in readable, clear format), to correction/completion/updating, to destruction.
- **IR provisions** set response deadlines for DSRs (verify current deadline in IR — proposed amendments touch DSR procedures). Treat 30 days as the working baseline and mark [FLUX].

## Disclosure & sensitive data
- **Art. 15** — Conditions for disclosure of personal data.
- **Art. 16** — Cases where disclosure is prohibited even under Art. 15 (e.g., security risk, reputational harm, sensitive-data conflicts).

## Security, breach, impact assessment
- **Art. 19** — Controller must implement organizational, administrative, and technical measures to protect personal data.
- **Art. 20** — Breach notification to the Competent Authority (SDAIA) upon becoming aware of a breach/leak/unauthorized access; notification to data subjects where the breach causes damage to them or conflicts with their rights/interests. IR specifies the 72-hour window to SDAIA — verify against current IR text; proposed amendments revise breach definitions ([FLUX]).
- **Art. 22** — Impact assessment (DPIA) required for processing operations per IR criteria (e.g., sensitive data, large-scale processing, new technologies — includes AI features).

## Processors & vendors
- **Art. 8** — Controller may engage a processor; controller remains responsible; processor must provide sufficient guarantees; processing per controller's instructions and documented contract.

## DPO, records, registration
- **Art. 30 (as implemented)** — DPO appointment per SDAIA rules (criteria: public entities, core activity is large-scale/systematic monitoring, or sensitive-data core processing). Proposed IR amendments fold DPO rules into the IR ([FLUX]).
- **Art. 31** — Records of processing activities (RoPA); maintained and available to SDAIA; national register of controllers per SDAIA rules (National Data Governance Platform registration).

## Cross-border transfers
- **Art. 29** — Transfer/disclosure outside the Kingdom permitted for enumerated purposes, subject to conditions: no harm to national security/vital interests, adequate protection level not below PDPL, minimum data necessary. TR details mechanisms: adequacy decisions (no adequacy country list published as of mid-2026 — verify), Standard Contractual Clauses, Binding Common/Corporate Rules, certifications, and exemptions (with risk assessment per SDAIA's Feb 2025 Risk Assessment Guideline for transfers).
- Practical consequence: any SaaS, cloud region, analytics, or LLM API endpoint outside KSA is a transfer requiring a mechanism. Data residency inside KSA avoids the TR entirely and is the strongest position for sensitive data.

## Penalties
- **Art. 35** — Criminal: disclosure/publication of sensitive data in violation of the law — up to 2 years imprisonment and/or fine up to SAR 3,000,000. Transferring data outside the Kingdom in violation — penalties apply.
- **Art. 36** — Administrative: warning or fine up to SAR 5,000,000 per violation; doubled for repeat violations.
- Committees for Reviewing Violations run formal, electronic, deadline-driven proceedings; ~5 days to respond to a notified violation.

## Adjacent SDAIA instruments (not PDPL, but bind AI systems)
- **AI Adoption Framework (Nov 2025)** — mandatory governance baseline for AI systems: data governance, model accountability, transparency, human oversight, risk management. AI systems processing personal data must satisfy PDPL + this framework simultaneously.
- **Generative AI Guidelines (2024)**, **AI Ethics Principles (updated 2025)** — advisory layer.
- **NDMO data governance standards** — apply to entities within scope of national data regulations.
