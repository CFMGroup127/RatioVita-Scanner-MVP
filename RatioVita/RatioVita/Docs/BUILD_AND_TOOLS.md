# Build scripts, SwiftLint, and SwiftFormat

## Run Script phase (RatioVita target)

The target runs **SwiftLint** and optionally **SwiftFormat** in **Debug** only. The script:

- **Never fails the build** (`exit 0`) so a lint crash does not block development.
- **Skips** when `CONFIGURATION` is not `Debug`, or when `PLATFORM_NAME` is not an Apple platform.

## Opt out locally (`RV_SKIP_TOOLS`)

If **SwiftLint** or **SourceKit** crashes under **Xcode beta** (e.g. exit 132), you can skip the entire tooling phase:

1. **Xcode:** Edit Scheme → **Run** → **Arguments** → **Environment Variables**  
   - Name: `RV_SKIP_TOOLS`  
   - Value: `1`
2. **Terminal:** `export RV_SKIP_TOOLS=1` before `xcodebuild`.

The build log will show: `Skipping tools: RV_SKIP_TOOLS=1`.

## Spotlight / App Intents donations (`MDB_MAP_FULL`)

Debug runs set **`RV_DISABLE_SYSTEM_INDEXING=1`** on the **RatioVita** scheme and call `SystemIndexingDonationGuard` before Firebase bootstrap. You should see:

`[SECURITY BYPASS] Skipping system indexing donation in development…`

If **`mdb_txn_commit … MDB_MAP_FULL`** or **`CSIndexErrorDomain Code=-1000`** still flood the console after a DerivedData flush, quit RatioVita and clear the local donation cache (Terminal.app):

```bash
killall SetStoreUpdateService 2>/dev/null; true
rm -rf ~/Library/Metadata/CoreSpotlight/NSFileProtectionCompleteUntilFirstUserAuthentication/index.spotlightV3
```

Then relaunch from Xcode (**Debug**). Release / TestFlight builds use production App Shortcuts unless indexing is disabled in Settings.

## Bundled receipt samples (DEBUG QA)

Receipt PDFs/images for stress-testing OCR live in **`Scanned receips PDF format?/`** at the **repository root** (exact folder name). The sandboxed app only reads files **inside the app bundle**, so sync them into the target before building:

```bash
./Scripts/sync_bundled_scanned_receipts.sh
```

That copies flattened `RVArchive2020__*` files into `RatioVita/RatioVita/Resources/`. The script uses **`COPYFILE_DISABLE=1`** and clears **extended attributes** on the copies so **`codesign`** does not fail with “resource fork, Finder information, or similar detritus”. Then use **Receipts → Samples → Import 2020 bundle** in a DEBUG build.

## Recommended follow-up (Phase 1+)

- Pin a **known-good SwiftLint** version (Mint, Homebrew pin, or bundled binary).
- Run lint in **CI** (Xcode Cloud / GitHub Actions) so local Xcode can skip tools entirely.

---

*See `RatioVita.xcodeproj` → RatioVita target → Build Phases → ShellScript for the exact script.*

## App target: User Script Sandboxing (Run Script / AppleScript helpers)

For the **RatioVita app target**, **User Script Sandboxing** should remain **No** (Debug and Release) so Run Script phases (SwiftLint, etc.) do not fail with **Sandbox Error 0**, and so macOS automation to optional helpers (e.g. **Numbers**) is not blocked at the target level. See **`RESOLVING_7_BLOCKED_TASKS.md`** if builds regress.

**Daily ledger:** The app always writes a **CSV** under `Vault/Exports/Ledgers/`; a **.numbers** file is attempted only when **Numbers** is installed. If Numbers is missing or AppleScript save fails, the **CSV** is still the successful output (no user-facing “script failed” for the primary artifact).

