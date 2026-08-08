# RatioVita Product Roadmap

Last updated: 2026-08-08

This document tracks major product capabilities, implementation status, and planned phases. Use it to measure progress across sessions.

---

## Legend

| Status | Meaning |
|--------|---------|
| ✅ Shipped | Available in current build |
| 🚧 In progress | Partially implemented |
| 📋 Planned | Designed, not yet built |
| 💡 Future | Desired, needs scoping |

---

## 1. Receipt capture & library

| Feature | Status | Notes |
|---------|--------|-------|
| Live multi-page camera capture | ✅ Shipped | `LiveCameraMultiPageCaptureView`, disk-backed batch |
| Receipts dashboard FAB (+) | ✅ Shipped | Opens live camera when available |
| Arctic Vault folder hierarchy | ✅ Shipped | Merchant → year → month drill-down |
| Review queue filing | ✅ Shipped | Save & Accept flow |
| Inline receipt editing (iPhone) | ✅ Shipped | Card-based editor (avoids nested Form collapse) |
| Stable back navigation from detail | ✅ Shipped | System `< Receipts` / `< Review` chevrons |
| Settings gear on receipt detail | ✅ Removed | Settings via **More → Settings** only |

---

## 2. Multi-currency & FX reconciliation

| Feature | Status | Notes |
|---------|--------|-------|
| App-wide default currency (Settings) | ✅ Shipped | `AppCurrencySettings`, More → Settings |
| Per-receipt currency override | ✅ Shipped | Edit receipt → currency picker with ISO labels |
| Currency library filter | ✅ Shipped | Receipts toolbar: All / Default / Foreign / per ISO |
| Bank settlement / wire FX fields | ✅ Shipped | Invoice currency vs actual bank debit + wire fee |
| Automatic FX variance ledger line | 📋 Planned | Auto-compute spread vs spot rate; attach sub-line item |
| Currency sub-ledger exposure view | 📋 Planned | Group/filter foreign totals like vendor accounts |
| Live exchange rate API integration | 💡 Future | Optional daily rate for implied conversion |

### FX workflow (current)

1. Set **default currency** in Settings (e.g. CAD).
2. On receipt edit, set **invoice currency + total** (e.g. USD 1,000).
3. Enable **Paid via wire in a different currency**.
4. Enter **actual bank debit** and optional **wire fee** in settlement currency.
5. Reconcile bank statement using both amounts; variance logging UI is next phase.

---

## 3. Advanced computer vision scanner

| Phase | Feature | Status | Framework |
|-------|---------|--------|-----------|
| **1** | Real-time rectangle detection overlay | 📋 Planned | `VNDetectRectanglesRequest` on video frames |
| **1** | Live green boundary / stability snap | 📋 Planned | Map Vision coords → view overlay |
| **2** | Perspective correction on capture | 🚧 Partial | `LiveMultiPageCaptureImagePrep` normalization exists |
| **2** | `CIPerspectiveCorrection` from corners | 📋 Planned | Core Image warp on shutter |
| **3** | Shadow removal & contrast filters | 📋 Planned | `CIColorControls`, luminance sharpen |
| **3** | B&W / whiteboard document modes | 📋 Planned | User-selectable filter after capture |
| **4** | Parallel batch disk staging | ✅ Shipped | `ReceiptBatchCaptureDiskCache`, thumbnail strip |
| **4** | Auto-capture when document stable | 📋 Planned | Confidence + motion threshold |
| **4** | SureScan multi-frame merge | 💡 Future | TurboScan-style 3-frame sharpness pick |

Reference apps: Genius Scan, TurboScan, Adobe Scan, Easy Expense, Apus.

---

## 4. OCR & structured extraction

| Feature | Status | Notes |
|---------|--------|-------|
| On-device Vision OCR | ✅ Shipped | |
| Heuristic field extraction | ✅ Shipped | Merchant, date, total fallback |
| Gemini JSON extraction | ✅ Shipped | Settings API key + toggle |
| Gemini parse failure fallback | ✅ Shipped | Manual review note + heuristic |
| Edit in text (handwriting) | 💡 Future | |
| Parallel batch OCR backlog | 📋 Planned | Progress UI for large imports |

---

## 5. Invoicing & payment receipts

| Feature | Status | Notes |
|---------|--------|-------|
| Outgoing invoice builder | 💡 Future | Branded PDF, line items, Net 30 terms |
| Payment receipt generation | 💡 Future | PDF when invoice marked paid |
| AR/AP document linking | 📋 Planned | Invoice ↔ payment reference graph |
| Client payment links | 💡 Future | Share / email from app |

---

## 6. Organization, export & security

| Feature | Status | Notes |
|---------|--------|-------|
| PDF export / share | ✅ Shipped | Per-receipt export menu |
| Multi-page explode / merge | ✅ Shipped | |
| Document tagging & smart rename | 📋 Planned | |
| Face ID app lock | 💡 Future | |
| PDF password encryption | 💡 Future | |
| Genius Cloud–style sync | 💡 Future | iCloud / CloudKit receipts already partially wired |

---

## 7. Mileage & tax (competitive parity)

| Feature | Status | Notes |
|---------|--------|-------|
| IRS mileage tracking | 💡 Future | Map / odometer / manual modes |
| Tax category suggestions | 🚧 Partial | `taxCategory` field on receipts |
| Business use % slider | ✅ Shipped | Per receipt when document type allows |

---

## Implementation priorities (suggested)

1. **Phase 1 CV overlay** — live rectangle detection in `LiveCameraMultiPageCaptureView`
2. **FX variance auto-line** — computed spread attached to receipt for bank reconcile
3. **Currency exposure dashboard** — foreign-currency totals in Receipts / Reports
4. **Invoice builder MVP** — self-employed outgoing invoices + payment receipt PDF

---

## Related files

| Area | Primary files |
|------|----------------|
| Capture | `RealScannerService.swift`, `LiveCameraMultiPageCaptureView.swift` |
| Edit / FX | `ReceiptDetailView.swift` (`EditReceiptView`) |
| Currency | `AppCurrencySettings.swift`, `ReceiptCurrency.swift`, `SettingsView.swift` |
| Library filters | `ReceiptsView.swift` |
| Settings hub | `PhoneMoreHubView.swift`, `ContentView.swift` |

---

## Changelog (roadmap-level)

- **2026-08-08**: Inline edit cards, default currency setting, per-receipt FX settlement fields, currency filter, navigation fixes, roadmap doc created.
