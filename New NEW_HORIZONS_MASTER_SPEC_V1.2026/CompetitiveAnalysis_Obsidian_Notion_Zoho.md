# Competitive intelligence: Obsidian, Notion, Zoho → RatioVita topology

**Purpose:** Map how RatioVita_v2 should absorb the best storage philosophy (Obsidian), structural UI (Notion), and operational atomization (Zoho) without cloud lock-in or data sovereignty loss.

---

## Part A — Obsidian vs Notion

| Vector | Obsidian | Notion | RatioVita stance |
|--------|----------|--------|------------------|
| **Core storage** | Local Markdown files; user owns folders | Proprietary blocks in cloud workspace | **SwiftData + `.rvvault`** local snapshots; optional iCloud *files* only |
| **Linking** | `[[Wiki links]]`, graph view | Relations, rollups, formulas | Receipt reference graph + `HistoricalKnowledgeNode` tags |
| **Offline** | Full | Limited without sync | Full on device |
| **Extensibility** | 1,000+ community plugins | Templates + API | Feature-flag modules (Sprint XX planned) |
| **Security** | Air-gap capable | Tenant cloud | On-device OCR/Gemini optional; no required cloud DB |
| **Best for** | Writers, researchers, PKM | Team wikis, light CRM | **Film payroll + production vault + manuscripts** |

**Design rule:** Obsidian owns the *disk*; Notion owns the *views*; RatioVita owns the *payroll forensic layer*.

---

## Part B — Zoho Corporation ecosystem

Zoho atomizes enterprise software into **single-purpose apps** unified by **Zoho Directory / Zoho One** (IAM + provisioning). Below: each requested product → what it does → RatioVita module mapping.

### Identity, access, security

| Product | What it does | RatioVita mapping |
|---------|--------------|-------------------|
| **Zoho Directory** | Org IAM, SAML/OIDC, RBAC | `SecurityModule` / entitlements registry |
| **Zoho One Administrator** | Provision apps, audit org settings | `SystemVault` admin cockpit |
| **Zoho Kiosk** | Single-app device lock / terminal mode | Device focus mode / kiosk timecard terminal |

### Knowledge & work management

| Product | What it does | RatioVita mapping |
|---------|--------------|-------------------|
| **Zoho Creator Intune** | Low-code apps + MDM deployment (silent install, app catalog, DLP-style governance) | `DynamicFormBuilder` + hardened device profile ([Zoho MDM](https://www.zoho.com/creator/mobile-device-management.html)) |
| **Zoho Notes** | Card-based notes, sketches, audio | `ManuscriptVault` / `HistoricalKnowledgeNode` |
| **Zoho Flow** | Visual integration / webhooks | `AutomatedEventEngine` (local triggers) |
| **Zoho Qntrl** | Enterprise workflow / SLA state machines | `StateOrchestrationEngine` (procurement → on-set) |
| **Zoho Sprints** | Agile scrum | `SprintMatrix` (UU/VV/WW dev tracking) |
| **Zoho To Do** | Lightweight tasks | `DailyActionItemView` |
| **Zoho Apptics** | Mobile analytics / crashes | `TelemetryShield` (local diagnostics only) |

### Financial, procurement, commerce

| Product | What it does | RatioVita mapping |
|---------|--------------|-------------------|
| **Zoho Procurement** | Strategic sourcing, vendor onboarding, PO approvals | `CapExProcurementPipeline` (WW) |
| **Zoho Spend / Zoho Expense** | T&E, corporate cards, travel | `LogisticsExpenseModule` |
| **Zoho Expense Report PDF Generator** | Batch PDF reports from expense DB | `PDFRenderOps` / EP timesheet fill |
| **Zoho purchase order generator** | PO documents from line items | `POMetadataGenerator` |
| **Zoho Inventory** | Multi-warehouse stock, serials | `MasterAssetRegistry` + zone tags |
| **Zoho Asset Explorer** | IT asset lifecycle | `HardwareInventoryNode` |
| **Zoho Commerce** | Online store + inventory sync | `ExternalStorefrontBridge` (future) |
| **Zoho POS** | Retail register | `MobileRegisterTerminal` |
| **Zoho billing management** | Subscriptions / recurring billing | `ContractBillingEngine` |
| **Zoho Daybook** | Double-entry micro-ledger | `CoreLedgerEngine` |

### Human capital

| Product | What it does | RatioVita mapping |
|---------|--------------|-------------------|
| **Zoho People** | HR master records | `StaffDirectoryNode` |
| **Zoho Workerly** | Temp staffing | `SplinterCrewRoster` |
| **Zoho Shifts / Shifts Kiosk** | Shift schedule + tablet clock-in | `TimecardClockTerminal` |
| **Zoho Payroll / Employee portal** | Pay calc from approved time | `PayrollEngine` (Labor Sentinel) |

### Communications

| Product | What it does | RatioVita mapping |
|---------|--------------|-------------------|
| **Zoho Workplace / Mail / Calendar** | Business email suite | `UnifiedCommsInbox` (future) |
| **Zoho Cliq / Arattai** | Team chat | `SecureCommsChannel` |
| **Zoho TeamInbox** | Shared support inbox | `SharedInboundQueue` |
| **Zoho Connect** | Company intranet | `ProductionNoticeBoard` |
| **Zoho Meeting / Meeting Rooms** | Video conferencing | `VirtualReviewRoom` |
| **Zoho Bookings** | Appointment scheduling | `LogisticsScheduler` |
| **Zoho Sign** | eSign | `DigitalNotaryEngine` |

### Specialty operations

| Product | What it does | RatioVita mapping |
|---------|--------------|-------------------|
| **Zoho Business Manager** | Cross-app analytics dashboard | `ExecutiveCockpitView` |
| **Zoho Solo** | Solopreneur CRM + invoice + tasks | `SoloOperatorWorkspace` profile |
| **Zoho IoT** | Sensor telemetry | `FacilityTelemetryNode` / bio-insulation (YY) |
| **Zoho FSM** | Field service dispatch | `FleetLogisticsController` |
| **Zoho Backstage** | Event tickets / stages | `PresentationProductionHub` |
| **Zoho Scanner** | Document scan + OCR | `ReceiptImageRasterOps` + PhotoKit pipeline |
| **Zoho Radar** | Support desk analytics | `OperationalHealthMonitor` |

### Products already adjacent in RatioVita

- **Zoho Vault invoice PDFs** — `ZohoVaultInvoiceCoordinator` / inbox import  
- **Zoho CRM contacts** — `ZohoImportService`  

---

## Part C — RatioVita control panel (planned Sprint XX)

Apple Settings–style **feature radio switches**:

- Manuscript & Project Vault  
- Corporate Procurement & CapEx  
- Staff HR & Roster  
- Fleet & Transport  
- Bio-insulation / IoT telemetry  

When OFF: sidebar prunes related views (memory + cognitive load).

---

## Part D — New Horizons immediate priorities

1. Paste Gemini transcript into `NewHorizons_Blueprint.md`  
2. Import via **Select files…** → Manuscript Vault  
3. Tag CapEx receipts with `ExpenseClassification.capitalExpenditure`  
4. Assign `physicalZoneTag` per floor during Review  
5. Use **Vault transport** to sync iPhone ↔ iPad `.rvvault` packages  

---

*Research compiled for RatioVita_v2 — May 2026. Verify Zoho SKUs against [zoho.com](https://www.zoho.com) before contractual commitments.*
