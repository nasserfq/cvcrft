---
name: pdpl-compliance-checker
description: Runs Saudi PDPL (Personal Data Protection Law) compliance readiness reviews against systems, apps, data flows, vendors, or codebases. Use whenever the user mentions "PDPL", "Saudi data protection", "SDAIA", "data residency Saudi", "cross-border transfer KSA", "privacy compliance Saudi", asks whether a product/feature/data flow is PDPL-compliant, asks what PDPL requires for consent, breach notification, DPO, controller registration, or data subject rights, or asks to prepare for a SDAIA audit or enforcement inquiry. Also use when reviewing an AI system, LLM feature, or app architecture that processes personal data of people in Saudi Arabia, even if the user doesn't say "PDPL" explicitly.
metadata:
  author: Reef
  version: 1.0.0
  category: compliance
---

# PDPL Compliance Checker

Run structured PDPL readiness reviews that are traceable, honest about uncertainty, and useful to both engineers and GRC teams. Every finding must cite a specific PDPL article or Implementing Regulation provision. Never present a readiness review as a legal opinion.

## Core rules (apply to every review)

1. **Cite exactly.** Every requirement finding references a specific article (e.g., "PDPL Art. 6", "Implementing Regulations Art. 12", "Transfer Regulations Art. 3"). If unable to pin an article, label the finding [ADVISORY] and say so. Never invent article numbers — consult `references/pdpl-articles.md` rather than citing from memory.
2. **Label every finding** as one of:
   - `[REQUIREMENT]` — the law or regulations demand this
   - `[ADVISORY]` — interpretation, best practice, or SDAIA guidance that is not binding law
   - `[FLUX]` — an area where the rules are under amendment or SDAIA guidance is pending; note what may change
3. **Not legal advice.** Open every output with a one-line scope statement: this is a technical/operational readiness review, not legal advice; a Saudi-qualified lawyer should review conclusions before they are relied on in an enforcement or contractual context.
4. **Enforcement is live.** PDPL has been fully enforceable since 14 September 2024. SDAIA committee proceedings move fast (responses due within days of notification). Frame findings with operational urgency, not "someday" language.
5. **Check regulatory currency.** The Implementing Regulations are under amendment (third public consultation closed May 2025; final text pending as of mid-2026). If web search is available, verify the current status of the Implementing Regulations, Transfer Regulations, and any SDAIA adequacy-country list before finalizing findings in those areas. If search is unavailable, mark affected findings [FLUX].

## Step 1: Scope the review

Establish before analyzing:
- **What is being reviewed**: system, app, feature, data flow, vendor, codebase, or organization-wide posture
- **Role**: is the entity a controller, processor, or both? (Obligations differ materially)
- **Data categories**: any sensitive data? (health, genetic, biometric, credit, location that reveals patterns, religious/ideological data, criminal records — sensitive data triggers stricter rules and criminal exposure for unlawful disclosure)
- **Data subjects**: individuals in Saudi Arabia? (PDPL applies extraterritorially to processing of Saudi residents' data by entities outside KSA)
- **Cross-border**: does any personal data leave the Kingdom, including via SaaS, cloud regions, LLM APIs, or analytics tools?

If scope is ambiguous, ask one focused clarifying question rather than assuming. If the user gives a codebase or architecture doc, extract answers from it first.

## Step 2: Run the applicable domain checklists

Read `references/checklists.md` and run only the domains in scope:

1. Legal basis & consent
2. Privacy notices & transparency
3. Data subject rights (DSR) handling
4. Cross-border transfers
5. Breach detection & notification
6. DPO, registration & records (RoPA)
7. Security & retention
8. AI systems processing personal data (PDPL + SDAIA AI Adoption Framework interplay)
9. Vendors & processors

For each checklist item, record: **status** (Pass / Gap / Partial / Unknown), **evidence seen** (what in the system or docs supports the status), and **article reference**.

"Unknown" is a valid and honest status. Do not guess a Pass. A wrong Pass in a compliance review is worse than a flagged Unknown — it creates a false sense of compliance that surfaces during an SDAIA inquiry with a 5-day response window.

## Step 3: Score and prioritize gaps

For each Gap, assign:
- **Severity**: Critical (unlawful processing, sensitive-data exposure, unauthorized cross-border transfer, no legal basis) / High (missing mandatory artifact: RoPA, DPO where required, breach plan, DSR workflow) / Medium (weak but existing control) / Low (documentation polish)
- **Enforcement relevance**: SDAIA's enforcement decisions to date cluster around processing without a valid legal basis and unauthorized disclosure. Weight those domains accordingly.
- **Fix**: a specific, actionable remediation an engineer or GRC lead could start this week — not "improve governance"

## Step 4: Assumptions and limitations (mandatory section)

Every output includes, near the top:
- Assumptions made
- Information not available that would change conclusions
- What was NOT reviewed
- Confidence level: High / Medium / Low, with one sentence of justification
- Regulatory-currency note: which findings are [FLUX] and why

## Step 5: Security review flag

Use `<!-- WARNING: COMPLIANCE ISSUE -->` on any finding where:
- A control the user believes is sufficient is not (false sense of compliance)
- Personal data reaches an LLM, analytics, or third-party API without a mapped legal basis and transfer mechanism
- Sensitive data handling could constitute the criminal offense of unlawful disclosure (PDPL Art. 35)

Never sign off on a domain you could not actually verify.

## Output format

Use this structure:

```
# PDPL Readiness Review — [subject]
> Scope statement: technical/operational readiness review, not legal advice.

## Summary verdict
One paragraph: overall posture, top 3 risks, single most urgent action.

## Assumptions & limitations
(Step 4 content)

## Findings by domain
Per domain: table or list of items with Status | Finding | Label | Article | Fix

## Prioritized remediation plan
Ordered list: Critical first. Each item = action + owner type (eng/legal/GRC) + artifact produced.

## Regulatory watch
[FLUX] items and what to monitor (Implementing Regulation amendments, adequacy list, SDAIA platform requirements).
```

Save outputs to `CLAUDE OUTPUTS/` when a filesystem is available, as `YYYY-MM-DD-pdpl-review-[subject]-vN.md` (narrative) or `.xlsx` (gap register, if the user wants a sortable register).

## Language

If the user writes in Arabic, respond in Arabic with English article references retained (e.g., "المادة السادسة — PDPL Art. 6"). Legal terms of art: نظام حماية البيانات الشخصية (PDPL), الهيئة السعودية للبيانات والذكاء الاصطناعي (SDAIA), مسؤول حماية البيانات (DPO), نقل البيانات خارج المملكة (cross-border transfer).

## Examples

**Example 1 — architecture review:**
User: "My app sends user birth data to the Claude API for chart generation. PDPL issues?"
Actions: identify cross-border transfer (API endpoint outside KSA) + legal basis question + sensitive-data assessment of birth data → run checklists 1, 4, 8 → flag that no SDAIA adequacy list is published, so transfers need SCCs/BCRs or an exemption → recommend architecture where raw personal data never reaches the LLM (derived, de-identified features only) → cite Transfer Regulations and PDPL Arts. 5, 6, 29.

**Example 2 — audit prep:**
User: "SDAIA might audit us next quarter, what do we need?"
Actions: run checklists 2, 3, 5, 6 (the artifact-heavy domains) → produce a gap register of missing mandatory artifacts (RoPA, DPO documentation, breach response plan, DSR workflow with deadlines, National Data Governance Platform registration status) → prioritized remediation plan with owners.

## Quality checks

Before finalizing:
- [ ] Every [REQUIREMENT] cites an exact article; zero invented citations
- [ ] Scope statement (not legal advice) present at top
- [ ] Assumptions & limitations section present and honest
- [ ] No Pass without evidence; Unknowns flagged rather than guessed
- [ ] [FLUX] items identified where regulations are pending
- [ ] Remediation items are specific and start-this-week actionable
- [ ] Arabic output uses correct Saudi legal terminology if applicable
