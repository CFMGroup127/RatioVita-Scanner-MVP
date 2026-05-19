import Foundation
import Observation

/// Coordinates sidebar actions (Import / Samples) with the main library surface.
@Observable
@MainActor
final class LibraryNavigationCoordinator {
    /// Incremented when the user chooses **Import** in the sidebar; `ReceiptsView` opens the import sheet.
    private(set) var importSheetSignal: Int = 0

    /// Last `importSheetSignal` value that has already opened the import UI (survives `ReceiptsView` teardown on tab
    /// switches so the sheet is not re-presented when the library remounts).
    private(set) var lastConsumedImportSheetSignal: Int = 0

    func requestImportFromSidebar() {
        importSheetSignal += 1
    }

    /// True while the **Review → Receipts** handoff is waiting for the library tab to become active.
    private(set) var pendingImportWhenReceiptsTabActive = false

    /// Switches the iPhone tab strip to **Receipts**, then opens import once that surface is active (avoids firing
    /// capture while another tab is visible).
    func queueImportFromReviewFlow() {
        pendingImportWhenReceiptsTabActive = true
        focusReceiptsLibrarySignal += 1
    }

    /// Called from `ReceiptsView` when the receipts library is shown; returns at most once per queued request.
    @discardableResult
    func consumePendingImportWhenReceiptsTabActiveIfNeeded() -> Bool {
        guard pendingImportWhenReceiptsTabActive else { return false }
        pendingImportWhenReceiptsTabActive = false
        return true
    }

    /// Returns `true` once per sidebar import bump, including when `ReceiptsView` appears after the bump.
    /// Ignores stale `0` / unchanged values so tab switches never synthesize a presentation.
    func consumeImportSheetIfNeeded() -> Bool {
        guard importSheetSignal > 0 else { return false }
        guard importSheetSignal > lastConsumedImportSheetSignal else { return false }
        lastConsumedImportSheetSignal = importSheetSignal
        return true
    }

    // MARK: - Library contact filter (CRM → Receipts)

    var receiptsContactFilterContactID: UUID?
    var receiptsContactFilterDisplayName: String?

    private(set) var focusReceiptsLibrarySignal: Int = 0
    private(set) var lastConsumedFocusReceiptsLibrarySignal: Int = 0

    /// Opens the main library scoped to receipts whose **counterparty** is this contact (sidebar selects Receipts).
    func openReceiptsFilteredToContact(_ contact: ProductionContact) {
        receiptsContactFilterContactID = contact.id
        receiptsContactFilterDisplayName = contact.name
        focusReceiptsLibrarySignal += 1
    }

    func clearReceiptsContactFilter() {
        receiptsContactFilterContactID = nil
        receiptsContactFilterDisplayName = nil
    }

    func consumeFocusReceiptsLibraryIfNeeded() -> Bool {
        guard focusReceiptsLibrarySignal > 0 else { return false }
        guard focusReceiptsLibrarySignal > lastConsumedFocusReceiptsLibrarySignal else { return false }
        lastConsumedFocusReceiptsLibrarySignal = focusReceiptsLibrarySignal
        return true
    }

    // MARK: - Home Launchpad

    private(set) var homeNavigationSignal: Int = 0
    private(set) var pendingHomeDestination: HomeModuleDestination?
    private(set) var pendingPresentCorporateRegistry = false
    private(set) var pendingPresentProductionRegistry = false
    private(set) var pendingPresentSovereignAudit = false

    func navigateFromHome(_ destination: HomeModuleDestination) {
        pendingHomeDestination = destination
        homeNavigationSignal += 1
    }

    @discardableResult
    func consumeHomeDestination() -> HomeModuleDestination? {
        let d = pendingHomeDestination
        pendingHomeDestination = nil
        return d
    }

    func requestCorporateRegistryFromHome() {
        pendingPresentCorporateRegistry = true
        homeNavigationSignal += 1
    }

    @discardableResult
    func consumeCorporateRegistryPresentationIfNeeded() -> Bool {
        guard pendingPresentCorporateRegistry else { return false }
        pendingPresentCorporateRegistry = false
        return true
    }

    func requestProductionRegistryFromHome() {
        pendingPresentProductionRegistry = true
        homeNavigationSignal += 1
    }

    @discardableResult
    func consumeProductionRegistryPresentationIfNeeded() -> Bool {
        guard pendingPresentProductionRegistry else { return false }
        pendingPresentProductionRegistry = false
        return true
    }

    func requestSovereignAuditFromHome() {
        pendingPresentSovereignAudit = true
        homeNavigationSignal += 1
    }

    @discardableResult
    func consumeSovereignAuditPresentationIfNeeded() -> Bool {
        guard pendingPresentSovereignAudit else { return false }
        pendingPresentSovereignAudit = false
        return true
    }

    // MARK: - Call sheet → Labor Sentinel

    /// Pending crew-call / set line from **Scan call sheet** (Home). Consumed when opening a matching work day.
    private(set) var pendingCallSheetLaborPrefill: CallSheetLaborPrefillPayload?

    func offerCallSheetLaborPrefill(_ payload: CallSheetLaborPrefillPayload) {
        pendingCallSheetLaborPrefill = payload
    }

    /// Returns and clears the prefill when `workDate` matches the scan’s anchor day.
    @discardableResult
    func consumeCallSheetLaborPrefillIfMatchingWorkDay(_ workDate: Date) -> CallSheetLaborPrefillPayload? {
        guard let p = pendingCallSheetLaborPrefill else { return nil }
        let cal = Calendar.current
        guard cal.isDate(workDate, inSameDayAs: p.anchorDay) else { return nil }
        pendingCallSheetLaborPrefill = nil
        return p
    }
}
