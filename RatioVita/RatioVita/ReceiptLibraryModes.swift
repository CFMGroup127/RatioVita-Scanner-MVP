import Foundation
import SwiftUI

// MARK: - View mode (Finder-style)

enum ReceiptLibraryViewMode: String, CaseIterable, Identifiable, Hashable {
    case icon
    case list
    case column
    case gallery

    var id: String { rawValue }

    var title: String {
        switch self {
            case .icon: "Icons"
            case .list: "List"
            case .column: "Columns"
            case .gallery: "Gallery"
        }
    }

    var systemImage: String {
        switch self {
            case .icon: "square.grid.2x2"
            case .list: "list.bullet"
            case .column: "rectangle.split.3x1"
            case .gallery: "rectangle.on.rectangle.angled"
        }
    }
}

// MARK: - Sorting

enum ReceiptLibrarySort: String, CaseIterable, Identifiable, Hashable {
    case dateAddedNewest
    case merchantAZ
    case totalHighToLow
    case projectTitleAZ

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
            case .dateAddedNewest: "Date added (newest)"
            case .merchantAZ: "Merchant (A–Z)"
            case .totalHighToLow: "Total (high to low)"
            case .projectTitleAZ: "Project title (A–Z)"
        }
    }
}

// MARK: - Bulk selection (trash vs export)

enum ReceiptLibraryBulkMode: Equatable {
    case off
    case trash
    case export
}

// MARK: - Business / personal library scope

/// Filters the filed library by **business-use** context: production project link and/or `Receipt.businessUsePercent`.
enum ReceiptLibraryTaxUseFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case business
    case personal

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
            case .all: "All"
            case .business: "Business"
            case .personal: "Personal"
        }
    }
}
