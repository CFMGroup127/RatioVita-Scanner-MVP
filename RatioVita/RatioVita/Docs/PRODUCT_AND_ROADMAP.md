# RatioVita — Product Definition, Inventory & Roadmap

**Compiled from:** repo docs (`MONDAY_IGNITION_VERIFICATION.md`, `Config.md`, `POST_REHYDRATION_CHECKLIST.md`, `TARGET_INTEGRITY_VERIFICATION.md`, `RESOLVING_7_BLOCKED_TASKS.md`, `ScannerPipelinePlan.md`), codebase layout, and implementation threads through **May 2026**.

**Vision & inspiration (owner notes):** See **`VISION_AND_INSPIRATION.md`** — expanded definition (receipts plus warranties, insurance, assets, documents), **reference app list** (Wave, Mint, QuickBooks, NeatDesk, Zoho, Categorizr, Scanner Pro, Receipt Canada, Veryfi, QuickReceipts, TurboScan, etc.), and the full **north-star / Bolt-style backlog** (payroll, email scanning, Photos filing, “to be reviewed,” reports, and more).

**Initial V2 “house blueprint” prompt:** See **`INITIAL_V2_BLUEPRINT.md`** — the full post–BoltAi / Cursor fresh-start specification (Latin naming, seven feature pillars, security/sync, phased delivery, lessons learned). Source paste ends at the backup *folder structure* heading; append if you recover the rest.

**Prioritized phased schedule:** See **`PHASED_WORK_SCHEDULE.md`** — work grouped into **Phase 1** (ship hardening) through **Phase 6** (blueprint-scale backlog), with rough week ranges.

**Blueprint vs shipped (traceability matrix):** See **`BLUEPRINT_TRACEABILITY.md`** — maps the full “Next Generation” prompt to **Shipped / Partial / Not started** in this repo so scope is explicit for everyone.

**Bundled real receipt samples (QA):** Put PDFs and receipt images in the repo-root folder **`Scanned receips PDF format?/`** (exact name, including `?`). Run **`./Scripts/sync_bundled_scanned_receipts.sh`** to copy them into `RatioVita/RatioVita/Resources/` as `RVArchive2020__*` (flattened names). The script strips Finder/xattr metadata so **codesign** succeeds. Then build the app. **DEBUG** → Receipts **Samples → Import 2020 bundle** runs `ReceiptScanPipeline` + Vision + **`OCRParsing`**. For public Git remotes, consider Git LFS or omit generated `RVArchive2020__*` from tracking.

---

## 1. Purpose of RatioVita

**Long-term product intent:** Receipt and document management with room to grow into **assets, warranties, insurance policies**, and richer financial workflows; combine ideas from leading apps while prioritizing **clarity, trust, and strong UI** (see `VISION_AND_INSPIRATION.md`).

**Mission (what this codebase delivers today):** A **multi-platform Apple-ecosystem** app for **capturing receipts** (camera or file import), **extracting structured data** (merchant, total, currency, OCR text) with **Vision**, **persisting** records locally with **SwiftData**, and **exporting / reporting** in formats aligned with **Pages, Keynote, Numbers, and PDF** — with a consistent **“Sovereign”** product language (layout rules, audit stamp, vault-style export paths).

**Full blueprint (your expectation is correct):** The **“RatioVita Next Generation”** comprehensive prompt—filing cabinet hierarchy, asset lifecycle, full finance/tax/recurring, production tools, encryption, multi-user, sync, backups, widgets, etc.—is the **same north star** as the long-term intent above. This repository **does not yet implement most of those pillars**; they belong to **later phases** (`PHASED_WORK_SCHEDULE.md`, `VISION_AND_INSPIRATION.md`). Early work prioritized a **clean, shippable receipt + data + export core** and avoided repeating v1’s architectural and build problems. Nothing in that choice removes the blueprint features from the product plan—it defers them until the foundation is stable.

**Primary users:** Individuals or small teams who want **receipt capture → searchable list → export/ledger** without leaving the Apple stack.

**Core attributes**

| Attribute | Description |
|-----------|-------------|
| **Privacy-first local processing** | OCR and image enhancement run on-device (Vision, Core Image). |
| **SwiftData persistence** | `Receipt`, `ReceiptImage`, `Item` models; durable storage in app container. |
| **Multi-platform** | iOS 17+, macOS 14+, visionOS (device/simulator wiring per `ReceiptsView`). |
| **Scanner abstraction** | `ScannerService` protocol; real AVFoundation on **iOS/visionOS device** and **macOS** (`MacAVScannerService`); preview/mock where hardware or policy requires it. |
| **Sovereign UI rule** | **144 pt** top / header treatment via `DesignSystem.Layout` (`topMargin`, `sovereignHeaderHeight`). |
| **Vault paths** | Runtime `Vault/Exports` and `Vault/Exports/Ledgers` under **Documents** (iOS) or **sandbox container** (macOS). |
| **Compliance-oriented exports** | **Sovereign Audit Stamp** text on exports; daily ledger window **00:00–17:00**. |
| **Monday Ignition alignment** | Optional initiative hooks (iWork handshake, ledger, tests, agent-style verification docs). |

---

## 2. Features & Functions (Inventory)

### Data & models
- **SwiftData:** `Receipt`, `ReceiptImage`, `Item`; relationships and JPEG-backed image storage.
- **Scan pipeline types:** `ScanResult`, `ScannedPage`, `ExtractedData`, `ProcessingMetadata`, `ImageProcessingStep`, `DetectedRectangle`, `ProcessingOptions`.

### Capture & OCR
- **`RealScannerService` (iOS + visionOS):** `AVCaptureSession`, photo capture, permission flow, `ImageProcessing`, `VisionReceiptAnalysis`, SwiftData save; session **stopped after each scan** to reduce CMIO pressure.
- **`MacAVScannerService` (macOS):** Same pipeline with **NSImage**; device discovery **built-in + `.external`** (Continuity/USB); **entitlements** in `RatioVita-macos.entitlements`.
- **`PreviewScannerService`:** Deterministic mock scan for simulator / previews / fallbacks.
- **`ReceiptScanPipeline`:** File-import path → enhance → Vision → `OCRParsing` → `ScanResult` (used by macOS file picker and reusable elsewhere).
- **`CameraPermissions`:** Availability + authorization (iOS, visionOS, macOS).
- **`CameraCaptureView`:** iOS/visionOS — shutter via injected scanner; macOS — **camera** + **file importer**.
- **`VisionReceiptAnalysis`:** Shared text + rectangle detection.
- **`OCRParsing`:** Heuristic extraction of merchant/total/currency from OCR text.
- **`ImageProcessing`:** Core Image sharpen + contrast (“Sovereign enhancement”).

### UI
- **`ReceiptsView`:** List, search, delete, scan entry, settings link, DEBUG sample seed; scanner selection by platform (`ReceiptsView` / `onAppear`).
- **`ReceiptDetailView`:** Receipt detail presentation.
- **`ScannerView`:** Auxiliary / placeholder screen (not primary scan path).
- **`ScanButton`**, **`FloatingScanButton`**, **`SettingsView`**, **`ThemeManager`**, **`ratioVitaTheme()`** on app root.
- **`DesignSystem`:** Typography, spacing, colors, **144 pt** layout constants.
- **`ContentView`:** macOS `NavigationSplitView` / iOS `NavigationStack` shell.

### Export & reporting
- **`AppleiWorkService`:** Pages / Keynote (macOS AppleScript where applicable), PDF (iOS/macOS), Sovereign Audit Stamp.
- **`DailyLedgerService`:** Daily ledger 00:00–17:00; **Numbers** (macOS script path) / **CSV** (iOS); output under `Vault/Exports/Ledgers/`.
- **`DailyLedger5PMTrigger`:** Once-per-day at 17:00 while app runs (`RatioVitaApp`).

### Utilities & bootstrap
- **`ImageBridge`:** `RVImage` (`UIImage` / `NSImage`), `Image(rvImage:)`, `rvCGImage`.
- **`CurrencyFormatter`**, **`ColorExtensions`**, **`SampleData`**, **`SampleSeed`** (samples + Sovereign Coffee test receipt helper).
- **`AppBootstrap`:** Placeholder “Sovereign vault” log hook (no real vault yet).

### Tests
- **`RatioVitaTests`:** `OCRParsingTests`, `ImageProcessingTests`, scaffold tests.
- **`RatioVitaUITests`:** Launch / smoke.

### Build / project hygiene
- **File-system synchronized Xcode group** for app sources.
- **Run Script:** SwiftLint + SwiftFormat (non-fatal; SwiftLint may fail on **Xcode-beta** SourceKit).
- **`ENABLE_USER_SCRIPT_SANDBOXING = NO`** on app target; mac **camera + user-selected read-only** entitlements.
- **`.gitignore`:** Generated Vault exports.

### Documentation (in tree)
- `Docs/BLUEPRINT_TRACEABILITY.md`, `Docs/LEGACY_V1_GAP_NOTES.md`, `Docs/Config.md`, `Docs/ScannerPipelinePlan.md`, `Docs/RESOLVING_7_BLOCKED_TASKS.md`, `Docs/VISION_AND_INSPIRATION.md`, `Docs/INITIAL_V2_BLUEPRINT.md`, `Docs/PHASED_WORK_SCHEDULE.md`, `Docs/BUILD_AND_TOOLS.md`, `Docs/PHASE1_QA_CHECKLIST.md`, repo-root `MONDAY_IGNITION_VERIFICATION.md`, `POST_REHYDRATION_CHECKLIST.md`, `TARGET_INTEGRITY_VERIFICATION.md`.

### Optional / external context (not shipped as app logic)
- **`agents_system/`** and boardroom metaphors (Ethan Hayes, Arthur Jensen, etc.) — process and verification narrative around the same product goals.

---

## 3. Checklist — Implemented (added / completed so far)

Use this as “what the codebase already delivers.”

- [x] **User-visible errors:** `UserMessageCenter` alerts for failed save/delete, empty scan result, and **daily ledger** (one attempt per calendar day; avoids alert spam).
- [x] **`Config.md`:** macOS scanner + import section aligned with **`MacAVScannerService`** / **`ReceiptScanPipeline`**.
- [x] **Bundle hygiene:** `Views/REQUEST.md` → **`RatioVita/REQUEST_DIAGNOSTIC_TEMPLATE.md`** (outside file-sync app root).
- [x] **Run Script:** optional **`RV_SKIP_TOOLS=1`** to skip SwiftLint/SwiftFormat (see **`BUILD_AND_TOOLS.md`**).
- [x] **Phase 1 QA matrix:** **`PHASE1_QA_CHECKLIST.md`** (manual runs).
- [x] **UI pass (Phase 1 kickoff):** **`ReceiptDetailView`**, **`CameraCaptureView`**, macOS **`ContentView`** empty state, **`SettingsView`** `NavigationStack`, compression default aligned with list.

- [x] SwiftData schema: **Receipt**, **ReceiptImage**, **Item**
- [x] **ScannerService** + **PreviewScannerService**
- [x] **RealScannerService** (iOS + visionOS): camera, Vision OCR, Core Image pipeline, persistence
- [x] **MacAVScannerService**: macOS camera + same processing path; entitlements; post-scan session stop
- [x] **ReceiptScanPipeline** for **file import** (macOS primary; reusable)
- [x] **CameraCaptureView** wired from **ReceiptsView** (iOS / visionOS / macOS)
- [x] **VisionReceiptAnalysis** (shared Vision logic)
- [x] **ImageProcessing** (Core Image sharpen + contrast)
- [x] **OCRParsing** + **OCRParsingTests**
- [x] **ImageProcessingTests** (incl. CGImage path sanity)
- [x] **ReceiptsView** / **ReceiptDetailView** / **ReceiptsViewModel** (scan, save, delete, search)
- [x] **DesignSystem** **144 pt** ceiling on **ReceiptsView** header and **ScannerView**
- [x] **ThemeManager** + root **`.ratioVitaTheme()`**
- [x] **AppleiWorkService** (Pages / Keynote / PDF + audit stamp)
- [x] **DailyLedgerService** + **5 PM trigger** (foreground timer)
- [x] **SampleSeed** + DEBUG toolbar seed; **Sovereign Coffee** test receipt API (per `POST_REHYDRATION_CHECKLIST.md`)
- [x] Duplicate **model/service** file cleanup; **target integrity** / sync-root discipline
- [x] **Vault/Exports** runtime paths + **.gitignore** for generated exports
- [x] **User Script Sandboxing** relaxed for app target; **RESOLVING_7_BLOCKED_TASKS** doc
- [x] **Mac sandbox** entitlements file for camera + user-selected files
- [x] **Config.md** / **MONDAY_IGNITION** kept aligned with scanner + bridge story

---

## 4. Checklist — Outstanding (current build / “Ignition” phase)

Items that match **documented intent** but are **not done** or **only partial** for the phase you are in (MVP → production-hardening).

- [ ] **End-to-end QA:** work through **`PHASE1_QA_CHECKLIST.md`** on each destination (manual).
- [ ] **SwiftLint / CI:** pin tool version or run lint in CI; **`RV_SKIP_TOOLS`** is a temporary escape hatch only.
- [ ] **SovereignVault / Data Shield:** formal wrapper or policy layer over SwiftData (today: direct SwiftData + print hook in `AppBootstrap`).
- [ ] **The Purge:** production policy for **SampleSeed** (remove DEBUG seed from shipping UX, or archive path only).
- [ ] **Vault/Templates in repo:** `Sovereign_*` template files, placeholders, logo placement per spec.
- [ ] **ReceiptDetailView polish:** further tweaks beyond Phase 1 card layout if desired.
- [ ] **ScannerView:** still **placeholder** if anything navigates there; primary flow is **CameraCaptureView**.
- [ ] **Live camera preview** in scan sheet (aim-before-capture).
- [ ] **Multi-page receipt** capture / merge (single page today).
- [ ] **5 PM ledger in background:** `BGAppRefreshTask` / extension if required when app is not open.
- [ ] **Bundle hygiene:** confirm no other stray `.md` under `RatioVita/RatioVita/` that should not ship.
- [ ] **Permanent “archive vs delete”** product behavior (not in codebase).
- [ ] **Console [VISION] / SOP-01** explicit logging if still a acceptance criterion.

---

## 5. Wishlist — Future additions (post–current phase)

Prioritized themes; order is suggestive, not fixed. For the **full** aspirational list (email receipt scanning, payroll, automatic Photos albums, bill tracking, T4s, banking screenshot workflows, sample-data matrix, etc.), use **`VISION_AND_INSPIRATION.md` §4**.

**Product**
- [ ] **Credentials & compliance vault** (deferred) — per-department certs/licences (Food Handler, WHMIS, DZ, working at heights, CRA assessments, etc.); full package on file, **page 1 / summary only** to production & payroll. See **`CREDENTIALS_COMPLIANCE_VAULT_BACKLOG.md`**.
- [ ] **Photo Library picker** on iOS (import receipt without camera).
- [ ] **iCloud / export sync** of Vault outputs (if allowed by product).
- [ ] **Categories, tags, merchant rules**, smart folders.
- [ ] **Multi-currency** reporting and tax-year summaries.
- [ ] **Widgets** / Shortcuts for “scan now” / “today’s total.”

**Scanner & quality**
- [ ] **Document detection** crop / perspective correction before OCR.
- [ ] **Customizable** Sovereign filter presets; per-device tuning.
- [ ] **Batch scan** session (several receipts in one flow).

**Reporting & Apple suite**
- [ ] **Richer Numbers / Pages AppleScript** (true templates, formulas, charts).
- [ ] **Email / share sheet** export presets.
- [ ] **Audit trail** export (who scanned when — if multi-user later).

**Engineering**
- [ ] **SovereignStorage** / consolidated model count if you expand beyond current schema.
- [ ] **CI** (Xcode Cloud or GitHub Actions): build + tests + lint outside Xcode-beta fragility.
- [ ] **Localization** of strings and OCR languages.
- [ ] **Accessibility** audit (VoiceOver, Dynamic Type).

**Release**
- [ ] **TestFlight** / Mac notarization checklist.
- [ ] **App Store** privacy labels and marketing assets aligned with real permissions.

---

## 6. One-line phase statement

**You are past “empty shell / broken duplicates”** and into **“working capture + persistence + export + ledger + tests”** on **iOS, macOS, and visionOS (device)** — with **governance-style** items (vault abstraction, templates, purge, background ledger, preview UX) still open for the next wave.

---

*Update this file when a major feature lands or a Monday Ignition row changes state.*
