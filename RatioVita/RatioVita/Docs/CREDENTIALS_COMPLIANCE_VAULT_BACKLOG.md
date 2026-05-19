# Credentials & compliance vault — deferred backlog

**Status:** **Come back later** (May 2026). Articles-of-incorporation import on **My corporations** is a thin first slice only; do not treat it as the final design.

**Owner intent:** Employee and **corporate** profiles must hold every certification, licence, and supporting document that productions and payroll vendors (EP, Cast & Crew, in-house payroll, etc.) may request — with correct **single-page vs multi-page** handling and **production-safe sharing** (usually page 1 only).

---

## Why defer full build

Requirements vary by **department**, **union**, **jurisdiction**, and **production contract**. We need a researched matrix before locking schema and UI. Examples called out so far:

| Area | Examples (non-exhaustive) |
|------|---------------------------|
| **Safety / site** | Working at heights, fall protection, WHMIS, confined space, first aid |
| **Transport** | DZ licence, clean abstract, vehicle insurance |
| **Craft / service** | Food Handler, smart serve (where applicable) |
| **Corporate / tax** | Articles of incorporation (page 1 vs full package), CRA business number, GST/HST registration, **CRA assessment** packages (multi-page; share summary or page 1 only) |
| **Payroll / union** | Union cards, permittee letters, residency attestations, deal-memo attachments |

Most items are **single-page** PDFs or photos. Some are **multi-page** (full articles, CRA notices of assessment, insurance binders). Pattern:

- **Vault:** store the **full package** on the entity (person or corporation).
- **Production / payroll export:** expose only what they need — often **page 1** or a redacted summary — on demand (EP portal upload failures, shows not on C&C, etc.).

---

## Current code (placeholder only)

- `BusinessEntity`: `articlesFullDocumentData`, `articlesPageOneDocumentData`, `articlesDocumentFilename` — manual import, page-1 extract, light text suggest.
- Production **Loan-out** syncs from linked corporate entity legal name.
- No general credential model, expiry tracking, department rules, or share manifests yet.

---

## Proposed direction (when we return)

### 1. Research pass (required first)

- Per **department** (Costumes, Transport, Catering, Grip, etc.): list mandatory vs optional credentials for typical Ontario / union shows.
- Per **document type**: retention, expiry, renewal, who requests it (production coordinator, payroll, AD, transport captain).
- Map each type to **share policy**: `none` | `page1` | `summary` | `full` (default conservative).

Deliverable: **`CredentialsMatrix.md`** (or table in this file) before major schema work.

### 2. Data model (sketch)

```text
ComplianceDocumentKind     // enum: articlesPage1, articlesFull, foodHandler, dzLicense, whims, craAssessment, …
ComplianceDocumentRecord   // attached to PersonProfile | BusinessEntity | CrewMember
  - kind
  - fullDocumentData
  - productionShareData?   // page 1 or redacted PDF
  - issuedAt, expiresAt?
  - issuer, certificateNumber?
  - departmentTags[]       // which shows/depts this satisfies
  - sharePolicy
```

Separate **employee** vs **corporate** attachments; productions link to both via show profile.

### 3. UX themes

- **Corporate registry** and future **crew identity** screens: vault list by category (Safety, Licences, Tax, Corporate).
- Import: PDF / photo → ingest → suggest fields → human confirm.
- **Share with production:** one action per document kind (“Send page 1 to EP”, “Send full package to payroll only”).
- Labor Sentinel / production workspace: read-only “compliance packet” checklist per show (what’s missing before week 1).

### 4. Integrations

- EP / C&C: attach page-1 PDFs where portals allow; fallback export + email trail in app.
- Deal memo / onboarding: pull required doc list from production template.

---

## Related docs

- `PRODUCT_AND_ROADMAP.md` — payroll / production thread
- `VISION_AND_INSPIRATION.md` — long-term payroll & document depth
- `ArticlesOfIncorporationService.swift` — interim helper; replace with generic document vault service

---

*Update when research starts or when the first `ComplianceDocumentRecord` model lands.*
