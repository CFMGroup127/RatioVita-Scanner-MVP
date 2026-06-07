# RatioVita Ecosystem — Master Feature Ledger & Coverage Map
**Consolidated:** 2026-06-07 · **Purpose:** Single source-of-truth that reconciles every historical feature note (V2 founding prompt, financial-forecasting research, competitor analyses, document/asset/personal-wealth deep-dives) against the *actual* 2026 build status across all repositories — so nothing is lost before New Horizons engineering is layered in.

> This ledger consolidates the user's separately-kept notes (Parts 1–4: the original V2 development prompt, financial forecasting research, and the QuickBooks / Mint / NeatDesk / Expensify / asset-management / personal-asset / document-scanning comparison studies from Aug 2025) with the live forensic audit of the code on disk.

---

## 1. The Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  VITALOGIC  (macOS) — The Cognitive Layer                         │
│  AI agency desk shell: Gmail/Calendar/Docs/Boardroom,             │
│  15 agents (@ratiovita.com), Memory Module, mock ERP, valuation   │
└────────────────────────────────┬────────────────────────────────┘
                                  │ inter-process / sync
┌────────────────────────────────┴────────────────────────────────┐
│  RATIOVITA_V2  (Universal) — The Operational Layer                │
│  SetOS production core, Vision OCR, SwiftData local-first,         │
│  receipts/assets/timecards/transport, real-time on-set ops        │
└────────────────────────────────┬────────────────────────────────┘
                                  │ data ingestion / framework injection
┌────────────────────────────────┴────────────────────────────────┐
│  NEW HORIZONS  — The Sovereign Infrastructure Layer (FUTURE)      │
│  Off-grid telemetry, vertical farming, curated estate assets,     │
│  geothermal/solar logs, real-estate & legal/land ledgers          │
└─────────────────────────────────────────────────────────────────┘
```

- **Cognitive (VitaLogic):** strategy, agent orchestration, high-level comms, macro analytics. Repo: `CFMGroup127/VitaLogic` (clean flat repo at `/Users/colliemorris/VitaLogic`).
- **Operational (RatioVita_v2):** boots-on-the-ground ingestion, OCR, on-set workflows. Repo: `CFMGroup127/RatioVita-Scanner-MVP`.
- **Sovereign (New Horizons):** physical estate (Burlington waterfront) — geothermal, off-grid, vertical farming, real-estate/legal ledgers. **Not yet built.**

**Status legend:** 🟢 Built · 🟡 Partial/Scaffolded/Simulated · 🔴 Unbuilt backlog · ⚪️ New Horizons target

---

## 2. Master Feature Ledger (by domain)

### 2.1 Document Management & Digital Filing
| Feature | Inspiration | Status | Where |
|---|---|---|---|
| Receipt capture + Vision OCR + data extraction (merchant/date/amount) | NeatDesk, Expensify, Veryfi | 🟢 | RatioVita_v2 |
| Multi-page scanning / batch stitching | Scanner Pro, CamScanner, TurboScan | 🔴 | backlog |
| Image preprocessing (edge detect, perspective, orientation) | Scanner Pro, Office Lens | 🟢 | RatioVita_v2 |
| Hierarchical filing (Cabinets → Folders → Documents) | NeatDesk, Notion | 🟡 (built V1 `FilingCabinetManager`; not in V2 UI) | V1 → port |
| Document type recognition (receipt/invoice/contract) | Veryfi, Office Lens | 🟡 (VitaLogic triage) | VitaLogic |
| Full-text / OCR / semantic search | Evernote, Google Lens | 🟡 (VitaLogic Memory Module) | VitaLogic |
| Document versioning & history | Adobe, Notion | 🟡 (V1 `DocumentVersion`; VitaLogic memory versions) | V1/VitaLogic |
| PDF tools: merge/split/redact/compare/compress | Adobe Acrobat | 🟡 (V1 `DocumentProcessingService`) | V1 → port |
| Local PDF generation / iWork export | — | 🟢 | RatioVita_v2 |
| Smart categorization / tagging | Mint, Veryfi | 🟡 (rules + Gemini triage) | both |

### 2.2 Asset Management & Inventory
| Feature | Inspiration | Status | Where |
|---|---|---|---|
| Asset lifecycle: purchase → warranty → insurance → maintenance → lending | Asset Panda, AssetTiger | 🔴 (full 22-entity graph existed in V1; V2 is receipt-centric) | V1 → port |
| Production kit rentals / costume & wardrobe inventory | Sortly, AssetCloud | 🟢 | RatioVita_v2 (SetOS) |
| QR / barcode generate + scan | Sortly, Asset Panda | 🟡 (basic in SwiftData) | RatioVita_v2 |
| RFID / NFC tracking | AssetCloud/Wasp | 🔴 (Phase 2) | backlog ⚪️ |
| Depreciation / TCO / valuation over time | Asset Panda, NetSuite | 🔴 | backlog |
| Multi-location, condition monitoring, check-in/out | Sortly, AssetTiger | 🟡 (SetOS partial) | RatioVita_v2 |
| Stock levels, reorder points, multi-warehouse | Zoho Inventory, Fishbowl | 🔴 | backlog ⚪️ |
| Photo documentation (4–6 views per item) | Sortly | 🟡 | RatioVita_v2 |

### 2.3 Personal Wealth & High-Value Assets *(the "track everything you own" scope)*
| Feature | Inspiration | Status | Where |
|---|---|---|---|
| Artwork/collectibles: provenance, certificates, condition, appraisal history | Artwork Archive, Collectarium, ArtBinder | 🔴 | ⚪️ New Horizons "Curated Assets Ledger" |
| Real estate: valuation, property tax, rental income, mortgage, repairs | (real-estate engines) | 🔴 | ⚪️ New Horizons "Sovereign Estate Ledger" |
| Investment portfolio: stocks/bonds/crypto/commodities, market data | Personal Capital, Acorns | 🔴 | backlog |
| Net worth aggregate + asset allocation + wealth forecasting | Personal Capital | 🔴 | ⚪️ VitaLogic macro engine |

### 2.4 Financial Management, Analytics & Forecasting
| Feature | Inspiration | Status | Where |
|---|---|---|---|
| Daily ledger + PDF export | — | 🟢 | RatioVita_v2 |
| Zero-based / envelope / sinking-funds budgeting | YNAB, EveryDollar, Goodbudget | 🔴 (V1 `AdvancedBudgetService` mock) | backlog (Phase 5) |
| Financial health scoring, savings rate, DTI, emergency fund | Credit Karma, Mint | 🔴 | backlog |
| Goal-based planning + progress viz | YNAB, Personal Capital | 🔴 (V1 `FinancialGoal` entity only) | backlog |
| Cash-flow forecasting (30-day), predictive spend, anomaly detection | YNAB, Mint, PocketGuard | 🔴 | backlog |
| Subscription / recurring-bill management | Truebill, PocketGuard | 🔴 (V1 `RecurringTransaction` entity only) | backlog |
| Double-entry bookkeeping / general ledger | QuickBooks | 🔴 (neither repo has it) | backlog |
| CRA-compliant tax prep, P&L, payroll sub-ledgers, invoicing | QuickBooks, Zoho Books | 🟡 (RatioVita_v2 local ledgers/PDF; broader suite = simulated Zoho mock) | RatioVita_v2 / VitaLogic |
| Bank feeds / credit-card matching / multi-currency FX | Plaid, Mint | 🔴 (`isLocalOnlyMode = true`) | backlog |
| Tip calculator / bill split | — | 🟢 (V1) | V1 → port (optional) |
| Mileage / trip tracking | — | 🟡 (V1 `MileageManager`; SetOS transport) | V1/RatioVita_v2 |

### 2.5 Production Industry (SetOS)
| Feature | Status | Where |
|---|---|---|
| On-set operating system: payroll, timecards, transport, RTLS, voice, personas | 🟢 | RatioVita_v2 |
| Sprint KKKK: Multi-Suite Address Engine, Transport Liability Ledger (append-only), MTO Circle Check (pre-flight lockout) | 🟢 | RatioVita_v2 |
| Costume/wardrobe, kit rental, labor logging | 🟢 | RatioVita_v2 |
| Script breakdown, call-sheet ingestion, consultant onboarding | 🟢 | RatioVita_v2 |

### 2.6 Security, Privacy, Sync & Collaboration
| Feature | Status | Where |
|---|---|---|
| Local-first persistence (SwiftData) | 🟢 | RatioVita_v2 |
| CloudKit/Firebase backup & cross-device sync | 🟡 (VitaLogic UI shell; backend mock, network disabled) | VitaLogic |
| Biometric auth (Face/Touch ID) UI | 🟡 (AES-256 `LocalVaultManager` = TODO) | RatioVita_v2 |
| Encryption at rest / audit logging / signatures | 🟡 (V1 security stack; partial V2) | V1 → port |
| Multi-user roles (admin/manager/user/viewer) | 🔴 (enums only) | backlog |
| Compliance (SOC2/GDPR/HIPAA) | 🔴 | backlog |

### 2.7 Professional Services & AI
| Feature | Status | Where |
|---|---|---|
| AI smart categorization / priorities triage | 🟡 (Gemini-backed) | VitaLogic |
| 15-agent roster (@ratiovita.com), Memory Module, Boardroom | 🟢 (local) | VitaLogic |
| Professional-services handoff (appraiser/insurer/advisor/tax/legal) | 🔴 | ⚪️ VitaLogic gateway |
| Document-to-agent vector ingestion | 🔴 | ⚪️ VitaLogic |

---

## 3. New Horizons Technical Mapping (future injection)

**RatioVita_v2 (Operational):**
- Off-Grid Telemetry Ingestion Engine — SwiftData schemas for geothermal/solar/battery/water systems; manual telemetry loggers (flow/PSI/voltage/filter life); maintenance↔receipt↔warranty linking via existing Vision OCR.
- Vertical Farming Logistics — batch yield tracker, consumable supply ledgers (seed/nutrient/medium via QR/barcode), crop lifecycle scheduling (on-device).
- Curated Physical Asset Ledger — high-res asset portfolios, provenance & appraisal timelines.

**VitaLogic (Cognitive):**
- Macro Estate Valuation & Analytics — net-worth aggregate, predictive infrastructure lifecycle analytics, TCO modeler.
- Professional Services Secure Handoff Gateway — granular data exporter, advisor comm module, compliance/audit logger.
- AI Agent Sovereign Governance — Estate Manager persona (@estate.agent), document-to-agent vector ingestion.

**New Horizons Document Central Ledger:** Legal & Land Sovereignty (deeds, Burlington zoning, trusts) · Telemetry & Hardware (geothermal/solar/hydro schematics tied to hardware IDs) · Professional Services Integration (appraiser schedules, structural audits, CRA submissions).

---

## 4. Coverage Confirmation — what these notes ADD beyond the prior V1/V2 audit

1. **Personal-wealth dimension** (artwork provenance, real estate, investment portfolio, net worth) — broader than V1's asset/insurance graph; maps to New Horizons curated/estate ledgers.
2. **Full financial-forecasting suite** (zero-based/envelope/sinking funds, health scoring, cash-flow forecasting, subscriptions) — confirmed as a distinct Phase-5 backlog, partially prototyped (mock) in V1.
3. **New Horizons physical-estate scope** (geothermal, solar, off-grid telemetry, vertical farming) — the future Sovereign layer; no code yet.
4. **Explicit inspiration→feature provenance** (which competitor drove which requirement) — now recorded for design reference.
5. Everything else in the notes was already captured by the V1 forensic audit and live build status.

---

## 5. Consolidated Open Backlog (🔴 priority candidates)
- Asset lifecycle graph (warranty/insurance/maintenance/lending) — **port from V1**
- Hierarchical filing cabinets + multi-page PDF + PDF tools — **port from V1**
- Financial forecasting suite (budgeting, health score, cash flow, subscriptions)
- Double-entry bookkeeping / true accounting ledger
- Network sync + bank feeds + multi-currency (lift `isLocalOnlyMode`)
- AES-256 `LocalVaultManager`, multi-user roles, compliance
- New Horizons: telemetry ingestion, vertical farming, curated/estate/legal ledgers, valuation engine, services gateway, estate agent

---
*Next: map New Horizons data schemas onto these layers (RatioVita_v2 telemetry/farming/asset + VitaLogic valuation/handoff/agent governance).*
