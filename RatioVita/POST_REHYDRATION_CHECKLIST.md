# Post-Rehydration Checklist

Seal the ignition after the RE-HYDRATION task is complete.

---

## 1. Terminal: Permissions ✅

```bash
chmod 755 "/Users/colliemorris/Projects 2/RatioVita_v2/RatioVita/.swiftlint.yml"
chmod 755 "/Users/colliemorris/Projects 2/RatioVita_v2/RatioVita/.swiftformat"
```

**Status:** Run completed; both files are now `755` (rwxr-xr-x).

---

## 2. Clean Build

In Xcode:

- **Product → Clean Build Folder** (Cmd+Shift+K)
- Then **Product → Build** (Cmd+B)

---

## 3. Simulation Injection (Arthur Jensen Test Receipt)

Inject the test receipt into the Vault so the Ledger can tally it:

- **Option A (code):** Call once from a debug path or on first launch:
  ```swift
  SampleSeed.insertSovereignCoffeeTestReceipt(into: modelContext)
  ```
- **Option B (UI):** If your ReceiptsView has a “Seed samples” or similar control, add a one-time “Inject Sovereign Coffee Test” that calls the above.

**Test receipt:**

- Merchant: **Sovereign Coffee Co.**
- Total: **$42.39**
- Date: **Today at 14:45** (so it falls within 00:00–17:00 for the 5 PM Ledger)

After injection, the 5 PM trigger (or a manual run of `DailyLedgerService.shared.generateDailyLedger(for: Date(), modelContext: context)`) will include this receipt in the daily ledger.

---

## 4. Verification

| Check | How to verify |
|-------|----------------|
| **Visibility at Origin Y: 144.0** | ScannerView and ReceiptsView use `DesignSystem.Layout.topMargin` (144.0) and `sovereignHeaderHeight`. No cramped headers. |
| **Ledger tallies test scan** | Run the app, inject the test receipt, then either wait until 17:00 or temporarily trigger the ledger. Open **Vault/Exports/Ledgers/** (iOS: Documents; macOS: home directory) and confirm **YYYY-MM-DD_Daily_Ledger** (.numbers or .csv) contains “Sovereign Coffee Co.” and **42.39**. |

---

## 5. Quick Reference

- **144.0 px ceiling:** `DesignSystem.Layout.topMargin`, `DesignSystem.Layout.sovereignHeaderHeight` (used in ScannerView and ReceiptsView).
- **Test receipt injection:** `SampleSeed.insertSovereignCoffeeTestReceipt(into: modelContext)`.
- **5 PM Ledger:** `DailyLedgerService.shared.generateDailyLedger(for: Date(), modelContext: context)` (or automatic via `DailyLedger5PMTrigger` when app is open at 17:00).
