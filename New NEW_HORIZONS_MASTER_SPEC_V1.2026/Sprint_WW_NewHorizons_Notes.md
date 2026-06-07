# Sprint WW — New Horizons (shipped in RatioVita code)

## Site context

- **Venue:** 176 Yonge Street, Toronto (heritage flagship scale)
- **Program:** New Horizons — culinary theatre, media production, CapEx, multi-floor zones

## Code changes

### Expense classification

`ExpenseClassification` enum: Crew Field, CapEx, Culinary Logistics, Media Infrastructure, Commercial Vendor/PO.

Stored on `Receipt.expenseClassificationRaw`.

### Physical zone slicing

`NewHorizonsZoneCatalog` — vault prefix `New-Horizons/176-Yonge` and zone labels (Floor 2 Culinary Theatre, Rooftop Canopy, Speakers Corner, etc.).

Stored on `Receipt.physicalZoneTag`.

### Manuscript ingestion (bypasses receipt OCR)

`ManuscriptVaultImportService` — `.md`, `.markdown`, `.txt` → `HistoricalKnowledgeNode` + manuscript `Receipt` (type **Manuscript**, `documentKind: project_manuscript`).

Wired through **Select files…** in `CameraCaptureView` on iOS and macOS.

### Schema fingerprint

`v2026-05-20-new-horizons-zones-capex-manuscript`

## Not yet built (future sprints)

- Feature-flag cockpit (Sprint XX)
- Bio-insulation telemetry (Sprint YY)
- Sovereign identity graph onboarding (Sprint ZZ)
- Full CapEx PO PDF generator UI
