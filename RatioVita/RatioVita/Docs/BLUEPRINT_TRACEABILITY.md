# Blueprint traceability (Next Generation prompt → this repo)

Maps the **RatioVita Next Generation** comprehensive specification to **Shipped**, **Partial**, or **Not started** in **RatioVita_v2** as of **July 2026**. “Shipped” means user-visible or developer-facing behavior exists in the main app target, not a prototype in `ARCHIVED_V1_DO_NOT_USE`.

**Cross-repo VitaLogic items** (OpenRouter/Kimi, SovereignPhysics, GlassBottle3DView, Board Room multi-agent UI) live in the **VitaLogic** app target — see **`FORENSIC_AUDIT_2026-07-23.md`**.

| Area | Prompt expectation | Status | Notes / pointers |
|------|-------------------|--------|------------------|
| **Document filing cabinet** (hierarchy, versioning, smart tags) | Full tree, version control, AI classification | **Partial** | **Shipped:** sidebar placeholders (`DocumentCabinet`, **Cabinets** section, `CabinetPlaceholderView`). **Not started:** real folder tree, versioning, AI routing. |
| **Receipt scanner + OCR** | Camera, enhancement, OCR, extraction | **Shipped** | `RealScannerService`, `MacAVScannerService`, `PreviewScannerService`, `VisionReceiptAnalysis`, `ImageProcessing`, `CameraCaptureView`. |
| **Receipt data extraction** | Merchant, date, amount, items, tax | **Partial** | `OCRParsing` + optional **Gemini** (`ReceiptStructuredExtractor`); extraction quality varies. **Shipped:** persisted **line items** (`ReceiptLineItem` + macOS line editor + `ReceiptPersistence`). |
| **Receipt line items (model + UI)** | Itemized capture & edit | **Shipped** | `ReceiptLineItem`, macOS **Line items** section in `ReceiptMacReviewView`, ingest from OCR/Gemini merge in `ReceiptPersistence`. |
| **Cabinet placeholders (sidebar)** | Vehicles / Equipment / Tools | **Shipped** | `DocumentCabinet`, `ContentView` **Cabinets** section, `CabinetPlaceholderView` (not a full filing engine). |
| **Receipt categorization (AI)** | AI expense categories | **Not started** | No Core ML categorization pipeline. |
| **Receipt search** | Full-text, filters | **Partial** | Search over list fields / persistence; not full OCR index UI. |
| **Asset lifecycle** | Register, value, maintenance, warranty, insurance, lending | **Not started** | See v1 reference in `LEGACY_V1_GAP_NOTES.md`. |
| **Inventory / kits / barcode** | Stock, consumables, kit rental, QR | **Partial** | Large SwiftData library surface (`LibrarySwiftDataSchema`); UI coverage varies by module — see `FEATURE_REGISTRY.md`. |
| **Budgets / tax / recurring / goals** | CRA-style, recurring, goals | **Partial** | Ledger, tax category catalog, operational bookkeeper paths; not full goals/recurring product. |
| **Invoices / PO / expense reports** | Business docs | **Partial** | Finance/comptroller hooks; not full AP/AR suite. |
| **Production / costume / rental** | Industry specialization | **Partial** | `ProductionProject`, payroll/labor hubs, look boards, SetOS views, logistics Firestore coordinators. |
| **Security** (E2E, biometric, roles, audit log) | Encryption, MFA, RBAC | **Partial** | Sovereign backup encryption + restore; `SovereignAuditLogListView`; no enterprise RBAC/StoreKit tiers. |
| **Sync & backup** | Local-first, conflict resolution, cloud | **Partial** | Local SwiftData + **sovereign encrypted backup/restore** (`SovereignMasterBackupService`, `RatioVitaBackupManager`); logistics Firestore sync — not full multi-device conflict engine. |
| **Automated backup / recovery** | Scheduled backup, PITR | **Partial** | Post-write archive hooks + manual sovereign backup flows; not cloud PITR. |
| **Cross-device sync** | Smart sync | **Partial** | `SovereignSharedAuthKeychain` linked UID + Firebase bootstrap; anonymous UID limits remain — see forensic audit. |
| **Themes / dark mode** | Customization | **Shipped** | `ThemeManager`, `ThemePreview`, `ColorExtensions`. |
| **Accessibility** | VoiceOver, Dynamic Type | **Partial** | Some labels; no full audit. |
| **Widgets / Shortcuts** | Quick actions | **Partial** | `RatioVitaAppShortcuts` / SetOS intents — not full widget suite. |
| **Export (PDF / iWork)** | Multi-format | **Shipped** | `AppleiWorkService` (platform limits apply). |
| **Reporting / ledger** | Financial reporting | **Partial** | `DailyLedgerService`, 5 PM trigger; not full analytics. |
| **Bank reconciliation** | Import statements, match receipts | **Partial** | **Shipped:** `BankImportView`, Gemini bank row JSON, `ReconciliationReviewView` with **ranked** matches, **High/Medium/Low** confidence from date anchors + memo↔merchant overlap (`BankReconciliationMatcher`), conservative auto-link in `ReceiptFinanceAgentsService`. **Shipped:** `ProductionProject` + receipt/work session links for canonical show titles. **Not started:** Vision-on-image PDF, OFX, unlink UX. |
| **Email receipt pipeline** | Auto-ingest from mail | **Not started** | |
| **Hybrid / edge agents** | Cloud agent broker | **Partial** | `HybridAgentBrokerService`, `HybridAgentTypes` — local queue + cloud relay stub. |
| **Firebase / Firestore** | Production sync + rules | **Partial** | `RatioVitaFirebaseBootstrap`, collection refs, listener services; **rules in repo**, deploy when ready (`FIRESTORE_RULES_DEPLOY.md`). |
| **SetOS / on-set continuity** | Continuity, proximity, comms | **Partial** | Look boards, first looks, RTLS/proximity **sim/scaffold**, voice overlay — not full continuity breakdown engine. |
| **Unified iWork suite** | Pages/Numbers/Keynote bridge | **Not started** | Backlog: `UNIFIED_DOCUMENT_SUITE_BACKLOG.md`. |
| **Data model** | Core Data in prompt | **Shipped (SwiftData)** | `Receipt`, `ReceiptImage`, `ReceiptLineItem`, `ReceiptReferenceLink`, `WorkSession`, `BankTransaction`, `ProductionProject`, `Item`. **Delete rules on `Receipt`:** **cascade** `images` / `lineItems`; **nullify** `workSessions` / `referenceLinks` / `incomingReferenceLinks` when a receipt is removed. **Bank link:** `@Relationship` on `BankTransaction.matchedReceipt` with inverse `Receipt.matchedBankTransaction` (plain optional on `Receipt` — required pattern to avoid SwiftData macro circular references; both pointers are updated at link time). **Reference link peers:** plain `fromReceipt` / `toReceipt` on `ReceiptReferenceLink`; inverse `@Relationship` on `Receipt`. **`ProductionProject`:** canonical show title; `@Relationship` from project to `receipts` / `workSessions` with plain optionals on child models. |
| **Multi-page receipts** | Multi-page scans | **Partial** | Model supports pages; capture flow often single-page; bundled PDFs use **first page only** for Vision. |
| **Bundled real-world QA corpus** | — | **Shipped (DEBUG)** | Source: repo **`Scanned receips PDF format?/`** → run **`Scripts/sync_bundled_scanned_receipts.sh`** → `Resources/RVArchive2020__*` → **Samples → Import 2020 bundle** (`BundledReceiptArchiveImporter`). |
| **Web / Android** | Future | **Not started** | |

## How to use this file

- **Product / stakeholders:** Scan the **Status** column for expectations vs delivery.
- **Engineering:** Pick a **Not started** row when planning a phase; link new PRs back here when status changes.
- **QA:** Use **`PHASE1_QA_CHECKLIST.md`** plus DEBUG bundle import to stress **OCRParsing** on real scans.
- **Full parity audit (VitaLogic + agents_system):** **`FORENSIC_AUDIT_2026-07-23.md`**.

## Related docs

- `FORENSIC_AUDIT_2026-07-23.md` — cross-repo checklist, doc index, session vs code gaps.
- `PRODUCT_AND_ROADMAP.md` — inventory, outstanding Phase 1 items, wishlist.
- `LEGACY_V1_GAP_NOTES.md` — what exists in v1 on disk vs v2.
- `VISION_AND_INSPIRATION.md` — extended backlog (if present in tree).

*Update this matrix when a feature crosses the Shipped / Partial line.*
