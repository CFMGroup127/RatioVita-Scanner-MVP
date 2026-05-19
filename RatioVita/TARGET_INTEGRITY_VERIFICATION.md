# Target Integrity Verification — RatioVita (Sovereign Cleanup)

**Date:** Feb 2, 2026  
**Goal:** Resolve "Multiple commands produce" by removing orphaned/duplicate files and purging DerivedData.

---

## 1. Orphan Removal ✅

**Action:** Remove all files from `Models/` that have duplicates in `Services/` or `Views/`.

**Done (previous Sovereign Cleanup):**
- Removed from `RatioVita/RatioVita/Models/`: PreviewScannerService, RealScannerService, ScannerService, CameraCaptureView, ScannerView, ReceiptDetailView, ReceiptsViewModel, SampleData, SampleSeed, SettingsView, Receipt 2.swift.
- Kept canonical copies in Services/, Views/, Utilities/.

**Additional orphan (this pass):**
- **Removed:** `RatioVita/RatioVita/Item.swift` (root-level duplicate).
- **Kept:** `RatioVita/RatioVita/Models/Item.swift` (single source of truth for `Item`).

**Verification:** No duplicate `.swift` filenames remain under `RatioVita/RatioVita/`. Each type (e.g. Item, Receipt, ScannerService) exists in one place only.

---

## 2. Derived Data Purge ✅

**Action:** Manually delete `~/Library/Developer/Xcode/DerivedData` for RatioVita so no cached "ghost" files remain.

**Done:**
- Removed:
  - `~/Library/Developer/Xcode/DerivedData/RatioVita-cwzkbwelvalfokddxagjimeqnqnt`
  - `~/Library/Developer/Xcode/DerivedData/RatioVita_v2`
  - `~/Library/Developer/Xcode/DerivedData/RatioVita_v2-cvptrgxsoosnbzeheiblpcbtscpv`

**Next build:** Xcode will recreate DerivedData from the current file tree (single source of truth).

---

## 3. Target Re-Verification (Compile Sources)

**Action:** Check Build Phases > Compile Sources so each `.swift` file is listed exactly once.

**Project type:** This project uses **PBXFileSystemSynchronizedRootGroup** for the RatioVita app target. The "RatioVita" group is a *file system synchronized* root: Xcode discovers and compiles all files under `RatioVita/RatioVita/` automatically. There is no manual "Compile Sources" list to edit; the folder on disk is the source of truth.

**Implication:**
- Each `.swift` file under `RatioVita/RatioVita/` is included **exactly once** by the sync.
- Ensuring **no duplicate filenames** in that tree (and no duplicate `Item.swift` at root vs Models/) is sufficient for "each file listed exactly once."

**Manual check (optional):** In Xcode: select the RatioVita target → Build Phases. If you see "Compile Sources", it may be driven by the file system sync; if you see a synchronized group, the folder contents define what compiles. After orphan removal and DerivedData purge, a **Clean Build Folder (Cmd+Shift+K)** then **Build** should succeed.

---

## Summary

| Step | Status |
|------|--------|
| Orphan removal (Models/ + root Item.swift) | ✅ Complete |
| DerivedData purge (RatioVita) | ✅ Complete |
| Single .swift filename per type | ✅ Verified |
| Compile Sources (sync from folder) | ✅ No manual list; folder is source of truth |

**Next:** In Xcode, run **Product > Clean Build Folder (Cmd+Shift+K)**, then **Product > Build**. The 5:00 PM Ledger path (DailyLedgerService) is unblocked once the build passes.
