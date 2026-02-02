# RatioVita – Single‑Paste Diagnostic Request (Strict, Overwrite This File)

Goal: Fix the immediate launch crash (error 163) and ensure the RatioVita design system/theme is applied globally and consistently across all views.

Instructions to Cursor (follow exactly):
1) Gather EVERYTHING requested below.
2) Produce ONE single reply that contains ALL requested content.
3) OVERWRITE this REQUEST.md file with your reply (replace the entire file content).
4) Follow the rules strictly:
   - Paste FULL file contents. If a file doesn’t exist, write “MISSING”.
   - Do NOT summarize. Do NOT truncate. Do NOT say “omitted for brevity”.
   - Do NOT add commentary or analysis outside the requested code/log blocks.
   - Preserve original file paths and names where indicated.
   - Use the exact fenced code blocks below for each file.
   - Maintain section order and include every section (0 through 10).

When finished, this file (REQUEST.md) must contain the complete diagnostic bundle.

---

## 0) Quick Context
Paste plain text only (no code block) answering:
- iOS version + simulator/device model you’re using:
- Xcode version:
- Did the crash start after a recent change? If yes, what changed? (e.g., SwiftData, theme, camera)
- Current issue summary: App crashes immediately on launch (error 163), design system not applied (default iOS styling).

---

## 1) App Entry Points (full files)

### 1.1 RatioVita/RatioVita/RatioVitaApp.swift
- Confirm `.modelContainer(...)` is applied at `WindowGroup` (or equivalent).
- Confirm theme modifier application at the root (either here or in ContentView).

```swift:RatioVita/RatioVita/RatioVitaApp.swift
<PASTE FULL FILE HERE>



1.2 RatioVita/RatioVita/ContentView.swift
• Confirm .ratioVitaTheme() usage and placement (prefer root NavigationStack or applied at WindowGroup).
ContentView.swift

<PASTE FULL FILE HERE>

2) Theme System (full files)

2.1 RatioVita/RatioVita/Utilities/ThemeManager.swift
• Avoid force‑unwraps or heavy work at init; verify dark/light switching.
• If the theme modifier is defined here, include it.

ThemeManager.swift

<Past Entire File here>


2.2 RatioVita/RatioVita/Utilities/DesignSystem.swift
• Colors, typography, spacing, shared component styles. Ensure these components exist if referenced anywhere:
   • StatusBadge
   • SectionHeader
   • CardStyle (modifier)
   • PrimaryButtonStyle
   • Any additional tokens/types used by views
   
   
DesignSystem.swift

<Paste entire file here>


2.3 RatioVita/RatioVita/Utilities/ColorExtensions.swift
• Must include:
   • ratioVitaPrimary, ratioVitaSecondary, ratioVitaAccent
   • ratioVitaAdaptiveBackground, ratioVitaAdaptiveSurface, ratioVitaAdaptiveText
   • ratioVitaTextSecondary, ratioVitaBorder (if used)

ColorExtensions.swift

<Paste entire file here>


2.4 ratioVitaTheme() (if defined separately)
• View extension/modifier that applies the theme.

,PATH TO FILE DEFINING ratioVitaTheme()IF SEPARATE>

<PASTE FULL FILE HERE>

⸻

3) SwiftData Models and Sample Data (full files)

3.1 @Model types
• Receipt
• ReceiptImage
• Item

Receipt.swift

<PASTE FULL FILE HERE>

ReceiptImage.swift

<PASTE FULL FILE HERE>

Item.swift

<PASTE FULL FILE HERE>

3.2 Sample/Preview Data
• SampleData (preview container)
• SampleSeed (debug seeding)

SampleData.swift

<PASTE FULL FILE HERE>

SampleSeed.swift

<PASTE FULL FILE HERE>

⸻

4) Views (full files)

4.1 RatioVita/RatioVita/ReceiptsView.swift
• Re‑paste if updated.


ReceiptsView.swift

<PASTE FULL FILE HERE>



4.2 <PATH>/ReceiptDetailView.swift

RwceiptDetailView.swift

<PASTE FULL FILE HERE>


4.3 <PATH>/SettingsView.swift
SettingsView.swift

<PASTE FULL FILE HERE>

⸻

5) ViewModels (full files)

5.1 <PATH>/ReceiptsViewModel.swift
• Include init, properties, and updateDependencies(scanner:context:).

ReceiptsViewModel.swift

<PASTE FULL FILE HERE>

⸻

6) Scanner Services and Camera UI (full files)

6.1 <PATH>/ScannerService.swift (protocol and shared types if present)
• If ScanResult/ExtractedData/ScannedPage/ProcessingMetadata/DetectedRectangle are declared here, include them fully.
• If they live in other files, paste those files in section 10.


ScannerService.swift


<PASTE FULL FILE HERE>

6.2 <PATH>/PreviewScannerService.swift

PreviewScannerService.swift

<PASTE FULL FILE HERE>

6.3 <PATH>/RealScannerService.swift
• Must not touch camera at app launch outside of user action.
• If it references helper types (CameraPermissions, ImageProcessing, ProcessingOptions, OCRParsing, OCRResult, DetectedRectangle), include those files in section 10.

RealScannerService.swift

<PASTE FULL FILE HERE>

6.4 Camera UI
• iOS camera sheet view
• Non‑iOS scanner view (if applicable)

CameraCaptureView.swift


<PASTE FULL FILE HERE>


ScannerView.swift

<PASTE FULL FILE HERE>


⸻

7) UI Components used by ReceiptsView (full files)

7.1 <PATH>/StatusBadge.swift

StatusBadge.swift

<PASTE FULL FILE HERE>

7.2 <PATH>/SectionHeader.swift

SectionHeader.swift

<PASTE FULL FILE HERE>


7.3 <PATH>/CardStyle.swift (or the file that defines cardStyle modifier)

CardStyle.swift

<PASTE FULL FILE HERE>

7.4 <PATH>/ScanButton.swift

ScanButton.swift

<PASTE FULL FILE HERE>


7.5 Image bridge used by ReceiptsView
• Image(rvImage:) initializer and RVImage typealias

Image+RVImage.swift

<PASTE FULL FILE HERE>

7.6 <PATH>/CurrencyFormatter.swift

CurrencyFormatter.swift


<PASTE FULL FILE HERE>

⸻

8) App configuration (full files)

8.1 RatioVita/RatioVita/Info.plist
• Confirm NSCameraUsageDescription exists (required if any camera API might run).
• Include any other relevant privacy keys in use.

{} Info

<PASTE FULL FILE HERE>


8.2 Package.swift (if present)
• If you manage dependencies or targets that might affect runtime.

Package.swift

<PASTE FULL FILE HERE>

⸻

9) Crash Logs (paste raw output)

1. Get simulator UDID:

{} Code Snippet

<PASTE FULL FILE HERE>

2. Show app logs for last 5 minutes (replace <SIM-UDID>):

{} Code Snippet

<PASTE FULL FILE HERE>

Paste output:

{} Code Snippet

<PASTE FULL FILE HERE>

Optional: Xcode console output from launch to crash:
{} Code Snippet

<PASTE FULL FILE HERE>

Optional: App bundle contents (sanity check):
{} Code Snippet

<PASTE FULL FILE HERE>



⸻

10) Referenced helper modules/types (full files)
If any of the following are referenced by your code (especially RealScannerService), paste their full files. If they do not exist, write “MISSING”.

• CameraPermissions (e.g., handles AVCaptureDevice authorization)

CameraPermissions.swift

<PASTE FULL FILE HERE OR "MISSING">


• ImageProcessing (e.g., filters, enhancement)

ImageProcessing.swift

<PASTE FULL FILE HERE OR "MISSING">

• ProcessingOptions (struct/enum consumed by ImageProcessing)

ProcessingOptions.swift


<PASTE FULL FILE HERE OR "MISSING">

• OCRParsing (parses OCR text into structured ExtractedData)

OCRParsing.swift

<PASTE FULL FILE HERE OR "MISSING">

• Models used in scanning pipeline (if separate from ScannerService.swift):
   • ScanResult
   • ExtractedData
   • ScannedPage
   • ProcessingMetadata
   • ImageProcessingStep
   • DetectedRectangle
   
   ScanResult.swift


<PASTE FULL FILE HERE OR "MISSING">

   ExtractedData.swift


<PASTE FULL FILE HERE OR "MISSING">

   ScannedPage.swift

<PASTE FULL FILE HERE OR "MISSING">


   ProcessingMetadata.swift

<PASTE FULL FILE HERE OR "MISSING">


   ImageProcessingStep.swift

<PASTE FULL FILE HERE OR "MISSING">


   DetectedRectangle.swift

<PASTE FULL FILE HERE OR "MISSING">


• Any global singletons or initializers that run at app launch (e.g., Theme bootstrap, Fonts loader, Analytics, etc.)

AppBootstrap.swift

<PASTE FULL FILE HERE OR "MISSING">


⸻

11) Self‑Check Checklist (tick those verified)
• [ ] .modelContainer(...) applied at WindowGroup with schema: [Receipt.self, ReceiptImage.self, Item.self]
• [ ] Only one ModelContainer in the running app (previews/tests use separate in‑memory containers)
• [ ] .ratioVitaTheme() applied at the root (WindowGroup or top of ContentView)
• [ ] ThemeManager has no force‑unwraps/heavy work during init
• [ ] Scanner services don’t access camera at app launch (only after user taps Scan)
• [ ] Info.plist includes NSCameraUsageDescription
• [ ] Tried a different simulator/device or iOS version (avoid beta OS while debugging)

⸻

12) Success Criteria
• App launches without crashing
• Theme visible globally (green palette), typography consistent
• StatusBadge, SectionHeader, CardStyle, PrimaryButtonStyle render correctly
• Dark/light mode switching functional

⸻

13) Reference (do not change code yet; for context only)

Example: Apply container + theme at root

{} Code Snippet


Example: Apply theme at ContentView root

{} Code Snippet


⸻

When replying in REQUEST.md:
• Paste the complete content for ALL requested sections above in ONE single reply.
• OVERWRITE this REQUEST.md file with your reply (replace entire file content).
• Do NOT include additional commentary outside the code/log blocks.
• Do NOT summarize or truncate any file.


