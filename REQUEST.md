
# RatioVita Complete Diagnostic Bundle
# Generated: $(date)
# Purpose: Fix immediate launch crash (error 163) and ensure theme is applied globally

## 🚨 CRITICAL ISSUE IDENTIFIED - ThemeModifier StateObject Problem

**ROOT CAUSE**: The `@StateObject private var themeManager = ThemeManager.shared` in ThemeModifier creates multiple StateObject instances, causing crashes.

**IMMEDIATE FIX REQUIRED**:
```swift
struct ThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.theme, ThemeManager.shared)
            .preferredColorScheme(ThemeManager.shared.isDarkMode ? .dark : .light)
            .accentColor(ThemeManager.shared.accentColor)
    }
}
```

**LOCATION**: RatioVita/RatioVita/Utilities/ThemeManager.swift line 134
**IMPACT**: This is causing the immediate launch crash (error 163)

Instructions to Cursor (follow exactly):
1. Gather EVERYTHING requested below.
2. Produce ONE single reply that contains ALL requested content.
3. OVERWRITE this REQUEST.md􀰓 file with your reply (replace the entire file content).
4. Follow the rules strictly:
• Paste FULL file contents. If a file doesn’t exist, write “MISSING”.
• Do NOT summarize. Do NOT truncate. Do NOT say “omitted for brevity”.
• Do NOT add commentary or analysis outside the requested code/log blocks.
• Preserve original file paths and names where indicated.
• Use the exact fenced code blocks below for each file.
• Maintain section order and include every section (0 through 10).

When finished, this file (REQUEST.md) must contain the complete diagnostic bundle.

⸻

0) Quick Context
iOS version + simulator/device model you’re using: iOS 18.5 (iPhone 15 Pro Max - 0A52D615-E9DC-42A6-99F3-6F603E11DE8E) and iOS 26.0 beta
Xcode version: Xcode 26.0 beta (17A5305k)
Did the crash start after a recent change? If yes, what changed? (e.g., SwiftData, theme, camera): Yes, after implementing the design system and theme manager
Current issue summary: App crashes immediately on launch (error 163), design system not applied (default iOS styling).

## 4) Scanner Data Models (full files)

### 4.1 RatioVita/RatioVita/Models/ScanResult.swift
```swift
//
//  ScanResult.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Represents the result of a scanning operation
struct ScanResult {
    let id: UUID
    let scannedPages: [ScannedPage]
    let extractedData: ExtractedData
    let processingMetadata: ProcessingMetadata
    let createdAt: Date
    
    init(
        scannedPages: [ScannedPage],
        extractedData: ExtractedData,
        processingMetadata: ProcessingMetadata
    ) {
        self.id = UUID()
        self.scannedPages = scannedPages
        self.extractedData = extractedData
        self.processingMetadata = processingMetadata
        self.createdAt = Date()
    }
    
    // Computed properties
    var hasMultiplePages: Bool {
        scannedPages.count > 1
    }
    
    var totalPages: Int {
        scannedPages.count
    }
    
    var primaryPage: ScannedPage? {
        scannedPages.first
    }
    
    var allImages: [RVImage] {
        scannedPages.compactMap { $0.image }
    }
    
    var allOCRText: [String] {
        scannedPages.compactMap { $0.ocrText }
    }
    
    var combinedOCRText: String {
        allOCRText.joined(separator: "\n\n")
    }
    
    var averageConfidence: Double {
        let confidences = scannedPages.compactMap { $0.confidence }
        guard !confidences.isEmpty else { return 0.0 }
        return confidences.reduce(0, +) / Double(confidences.count)
    }
}

/// Represents a single scanned page
struct ScannedPage {
    let id: UUID
    let image: RVImage
    let originalImage: RVImage
    let pageNumber: Int
    let ocrText: String?
    let confidence: Double?
    let detectedRectangles: [DetectedRectangle]?
    let processingNotes: String?
    
    init(
        image: RVImage,
        originalImage: RVImage,
        pageNumber: Int = 1,
        ocrText: String? = nil,
        confidence: Double? = nil,
        detectedRectangles: [DetectedRectangle]? = nil,
        processingNotes: String? = nil
    ) {
        self.id = UUID()
        self.image = image
        self.originalImage = originalImage
        self.pageNumber = pageNumber
        self.ocrText = ocrText
        self.confidence = confidence
        self.detectedRectangles = detectedRectangles
        self.processingNotes = processingNotes
    }
    
    // Computed properties
    var hasOCRResults: Bool {
        ocrText != nil && confidence != nil
    }
    
    var hasDetectedRectangles: Bool {
        detectedRectangles != nil && !detectedRectangles!.isEmpty
    }
    
    var primaryRectangle: DetectedRectangle? {
        detectedRectangles?.first
    }
}

/// Represents detected document rectangles from Vision framework
struct DetectedRectangle {
    let boundingBox: CGRect
    let confidence: Double
    let corners: [CGPoint]
    
    init(boundingBox: CGRect, confidence: Double, corners: [CGPoint]) {
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.corners = corners
    }
    
    // Computed properties
    var area: CGFloat {
        boundingBox.width * boundingBox.height
    }
    
    var aspectRatio: CGFloat {
        boundingBox.width / boundingBox.height
    }
    
    var isReasonableSize: Bool {
        area > 1000 && aspectRatio > 0.5 && aspectRatio < 2.0
    }
}

/// Extracted structured data from OCR text
struct ExtractedData {
    let merchant: String?
    let total: Decimal?
    let currency: String?
    let date: Date?
    let lineItems: [LineItem]?
    let taxAmount: Decimal?
    let subtotal: Decimal?
    
    // Confidence scores for extracted data
    let merchantConfidence: Double?
    let totalConfidence: Double?
    let dateConfidence: Double?
    
    init(
        merchant: String? = nil,
        total: Decimal? = nil,
        currency: String? = nil,
        date: Date? = nil,
        lineItems: [LineItem]? = nil,
        taxAmount: Decimal? = nil,
        subtotal: Decimal? = nil,
        merchantConfidence: Double? = nil,
        totalConfidence: Double? = nil,
        dateConfidence: Double? = nil
    ) {
        self.merchant = merchant
        self.total = total
        self.currency = currency
        self.date = date
        self.lineItems = lineItems
        self.taxAmount = taxAmount
        self.subtotal = subtotal
        self.merchantConfidence = merchantConfidence
        self.totalConfidence = totalConfidence
        self.dateConfidence = dateConfidence
    }
    
    // Computed properties
    var hasValidData: Bool {
        merchant != nil || total != nil || date != nil
    }
    
    var overallConfidence: Double {
        let confidences = [merchantConfidence, totalConfidence, dateConfidence].compactMap { $0 }
        guard !confidences.isEmpty else { return 0.0 }
        return confidences.reduce(0, +) / Double(confidences.count)
    }
    
    var formattedTotal: String? {
        guard let total = total else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        return formatter.string(from: total as NSDecimalNumber)
    }
}

/// Represents a line item from a receipt
struct LineItem {
    let description: String
    let quantity: Int?
    let unitPrice: Decimal?
    let totalPrice: Decimal?
    let confidence: Double?
    
    init(
        description: String,
        quantity: Int? = nil,
        unitPrice: Decimal? = nil,
        totalPrice: Decimal? = nil,
        confidence: Double? = nil
    ) {
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.confidence = confidence
    }
}

/// Metadata about the processing operation
struct ProcessingMetadata {
    let processingTime: TimeInterval
    let ocrEnabled: Bool
    let compressionEnabled: Bool
    let compressionQuality: Double
    let imageProcessingSteps: [ImageProcessingStep]
    let errors: [ProcessingError]?
    
    init(
        processingTime: TimeInterval,
        ocrEnabled: Bool,
        compressionEnabled: Bool,
        compressionQuality: Double,
        imageProcessingSteps: [ImageProcessingStep],
        errors: [ProcessingError]? = nil
    ) {
        self.processingTime = processingTime
        self.ocrEnabled = ocrEnabled
        self.compressionEnabled = compressionEnabled
        self.compressionQuality = compressionQuality
        self.imageProcessingSteps = imageProcessingSteps
        self.errors = errors
    }
    
    // Computed properties
    var hasErrors: Bool {
        errors != nil && !errors!.isEmpty
    }
    
    var processingStepsDescription: String {
        imageProcessingSteps.map { $0.description }.joined(separator: ", ")
    }
}

/// Represents a step in the image processing pipeline
struct ImageProcessingStep {
    let name: String
    let description: String
    let duration: TimeInterval
    let success: Bool
    
    init(name: String, description: String, duration: TimeInterval, success: Bool = true) {
        self.name = name
        self.description = description
        self.duration = duration
        self.success = success
    }
}

/// Represents an error during processing
struct ProcessingError {
    let code: String
    let message: String
    let step: String
    let recoverable: Bool
    
    init(code: String, message: String, step: String, recoverable: Bool = true) {
        self.code = code
        self.message = message
        self.step = step
        self.recoverable = recoverable
    }
}
```

### 4.2 RatioVita/RatioVita/Utilities/OCRParsing.swift
```swift
import Foundation

struct OCRParsing {
    static func extractData(from text: String) -> ExtractedData {
        // Very naive placeholder parser
        let lines = text.components(separatedBy: .newlines)
        
        var merchant: String?
        var total: Decimal?
        let currency = "USD"
        var date: Date?
        
        // Look for merchant (first non-empty line)
        merchant = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Look for total (line containing currency symbols or numbers)
        for line in lines {
            if line.contains("$") || line.contains("Total") {
                let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Double($0) }
                if let lastNumber = numbers.last {
                    total = Decimal(lastNumber)
                }
            }
        }
        
        // Look for date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        for line in lines {
            if let parsedDate = dateFormatter.date(from: line) {
                date = parsedDate
                break
            }
        }
        
        return ExtractedData(
            merchant: merchant,
            total: total,
            currency: currency,
            date: date,
            merchantConfidence: merchant != nil ? 0.8 : nil,
            totalConfidence: total != nil ? 0.9 : nil,
            dateConfidence: date != nil ? 0.7 : nil
        )
    }
}
```

### 4.3 RatioVita/RatioVita/Utilities/ImageProcessing.swift
```swift
import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum ProcessingOptions {
    case receiptDefault
}

enum ImageProcessing {
    static func processImage(_ image: RVImage, with _: ProcessingOptions) async throws -> RVImage {
        // MVP stub: returns the original image without modification
        return image
    }
}
```

⸻

1) App Entry Points (full files)

1.1 RatioVita/RatioVita/RatioVitaApp.swift
• Confirm .modelContainer(...) is applied at WindowGroup (or equivalent).
• Confirm theme modifier application at the root (either here or in ContentView).


RatioVitaApp.swift

//
//  RatioVitaApp.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftData
import SwiftUI

@main
struct RatioVitaApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Receipt.self,
            ReceiptImage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .ratioVitaTheme()
        }
        .modelContainer(sharedModelContainer)
    }
}




1.2 RatioVita/RatioVita/ContentView.swift
• Confirm .ratioVitaTheme() usage and placement (prefer root NavigationStack or applied at WindowGroup).
ContentView.swift

//
//  ContentView.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            ReceiptsView()
        } detail: {
            Text("Select a receipt")
        }
        .navigationTitle("Receipts")
        // .ratioVitaTheme() // Temporarily disabled for testing
        #else
        NavigationStack {
            ReceiptsView()
                .navigationTitle("Receipts")
        }
        // .ratioVitaTheme() // Temporarily disabled for testing
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer)
}



2. Theme System (full files)

2.1 RatioVita/RatioVita/Utilities/ThemeManager.swift
• Avoid force‑unwraps or heavy work at init; verify dark/light switching.
• If the theme modifier is defined here, include it.

ThemeManager.swift

import SwiftUI
import Combine

// MARK: - Theme Manager

/// Manages app-wide theming and color schemes
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode: Bool = false
    @Published var accentColor: Color = .ratioVitaPrimary
    @Published var customTheme: RatioVitaTheme = .default
    
    private init() {
        // Load saved preferences
        loadTheme()
    }
    
    // MARK: - Theme Management
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        saveTheme()
    }
    
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveTheme()
    }
    
    func setCustomTheme(_ theme: RatioVitaTheme) {
        customTheme = theme
        saveTheme()
    }
    
    // MARK: - Persistence
    
    private func saveTheme() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(accentColor.toHex(), forKey: "accentColor")
        UserDefaults.standard.set(customTheme.rawValue, forKey: "customTheme")
    }
    
    private func loadTheme() {
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        if let accentHex = UserDefaults.standard.string(forKey: "accentColor") {
            accentColor = Color(hex: accentHex)
        }
        
        if let themeRawValue = UserDefaults.standard.string(forKey: "customTheme"),
           let theme = RatioVitaTheme(rawValue: themeRawValue) {
            customTheme = theme
        }
    }
}

// MARK: - RatioVita Themes

enum RatioVitaTheme: String, CaseIterable {
    case `default` = "Default"
    case forest = "Forest"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case monochrome = "Monochrome"
    
    var displayName: String {
        rawValue
    }
    
    var primaryColor: Color {
        switch self {
        case .default:
            return .ratioVitaPrimary
        case .forest:
            return Color(hex: "#2E7D32")
        case .ocean:
            return Color(hex: "#1976D2")
        case .sunset:
            return Color(hex: "#FF5722")
        case .monochrome:
            return Color(hex: "#424242")
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .default:
            return .ratioVitaSecondary
        case .forest:
            return Color(hex: "#4CAF50")
        case .ocean:
            return Color(hex: "#03A9F4")
        case .sunset:
            return Color(hex: "#FF9800")
        case .monochrome:
            return Color(hex: "#757575")
        }
    }
    
    var accentColor: Color {
        switch self {
        case .default:
            return .ratioVitaAccent
        case .forest:
            return Color(hex: "#8BC34A")
        case .ocean:
            return Color(hex: "#00BCD4")
        case .sunset:
            return Color(hex: "#FFC107")
        case .monochrome:
            return Color(hex: "#9E9E9E")
        }
    }
}

// MARK: - Theme Environment

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme View Modifier

struct ThemeModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .accentColor(themeManager.accentColor)
    }
}

extension View {
    /// Apply RatioVita theme to the view
    func ratioVitaTheme() -> some View {
        self.modifier(ThemeModifier())
    }
}

// MARK: - Theme Preview

struct ThemePreview: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
                        .onChange(of: themeManager.isDarkMode) { _ in
                            themeManager.toggleDarkMode()
                        }
                }
                
                Section("Theme") {
                    ForEach(RatioVitaTheme.allCases, id: \.self) { theme in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(theme.displayName)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 12, height: 12)
                                    
                                    Circle()
                                        .fill(theme.secondaryColor)
                                        .frame(width: 12, height: 12)
                                    
                                    Circle()
                                        .fill(theme.accentColor)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            Spacer()
                            
                            if themeManager.customTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            themeManager.setCustomTheme(theme)
                        }
                    }
                }
                
                Section("Accent Color") {
                    HStack {
                        Text("Accent Color")
                        
                        Spacer()
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(Color.tagColors.prefix(8), id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.ratioVitaAdaptiveText, lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        themeManager.setAccentColor(color)
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Theme Settings")
        }
        .ratioVitaTheme()
    }
}

#Preview("Theme Preview") {
    ThemePreview()
}



import SwiftUI
import Combine

// MARK: - Theme Manager

/// Manages app-wide theming and color schemes
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode: Bool = false
    @Published var accentColor: Color = .ratioVitaPrimary
    @Published var customTheme: RatioVitaTheme = .default
    
    private init() {
        // Load saved preferences
        loadTheme()
    }
    
    // MARK: - Theme Management
    
    func toggleDarkMode() {
        isDarkMode.toggle()
        saveTheme()
    }
    
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveTheme()
    }
    
    func setCustomTheme(_ theme: RatioVitaTheme) {
        customTheme = theme
        saveTheme()
    }
    
    // MARK: - Persistence
    
    private func saveTheme() {
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        UserDefaults.standard.set(accentColor.toHex(), forKey: "accentColor")
        UserDefaults.standard.set(customTheme.rawValue, forKey: "customTheme")
    }
    
    private func loadTheme() {
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        if let accentHex = UserDefaults.standard.string(forKey: "accentColor") {
            accentColor = Color(hex: accentHex)
        }
        
        if let themeRawValue = UserDefaults.standard.string(forKey: "customTheme"),
           let theme = RatioVitaTheme(rawValue: themeRawValue) {
            customTheme = theme
        }
    }
}

// MARK: - RatioVita Themes

enum RatioVitaTheme: String, CaseIterable {
    case `default` = "Default"
    case forest = "Forest"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case monochrome = "Monochrome"
    
    var displayName: String {
        rawValue
    }
    
    var primaryColor: Color {
        switch self {
        case .default:
            return .ratioVitaPrimary
        case .forest:
            return Color(hex: "#2E7D32")
        case .ocean:
            return Color(hex: "#1976D2")
        case .sunset:
            return Color(hex: "#FF5722")
        case .monochrome:
            return Color(hex: "#424242")
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .default:
            return .ratioVitaSecondary
        case .forest:
            return Color(hex: "#4CAF50")
        case .ocean:
            return Color(hex: "#03A9F4")
        case .sunset:
            return Color(hex: "#FF9800")
        case .monochrome:
            return Color(hex: "#757575")
        }
    }
    
    var accentColor: Color {
        switch self {
        case .default:
            return .ratioVitaAccent
        case .forest:
            return Color(hex: "#8BC34A")
        case .ocean:
            return Color(hex: "#00BCD4")
        case .sunset:
            return Color(hex: "#FFC107")
        case .monochrome:
            return Color(hex: "#9E9E9E")
        }
    }
}

// MARK: - Theme Environment

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var theme: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme View Modifier

struct ThemeModifier: ViewModifier {
    @StateObject private var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager)
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .accentColor(themeManager.accentColor)
    }
}

extension View {
    /// Apply RatioVita theme to the view
    func ratioVitaTheme() -> some View {
        self.modifier(ThemeModifier())
    }
}

// MARK: - Theme Preview

struct ThemePreview: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
                        .onChange(of: themeManager.isDarkMode) { _ in
                            themeManager.toggleDarkMode()
                        }
                }
                
                Section("Theme") {
                    ForEach(RatioVitaTheme.allCases, id: \.self) { theme in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(theme.displayName)
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 12, height: 12)
                                    
                                    Circle()
                                        .fill(theme.secondaryColor)
                                        .frame(width: 12, height: 12)
                                    
                                    Circle()
                                        .fill(theme.accentColor)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            Spacer()
                            
                            if themeManager.customTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            themeManager.setCustomTheme(theme)
                        }
                    }
                }
                
                Section("Accent Color") {
                    HStack {
                        Text("Accent Color")
                        
                        Spacer()
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(Color.tagColors.prefix(8), id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.ratioVitaAdaptiveText, lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        themeManager.setAccentColor(color)
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Theme Settings")
        }
        .ratioVitaTheme()
    }
}

#Preview("Theme Preview") {
    ThemePreview()
}






2.2 RatioVita/RatioVita/Utilities/DesignSystem.swift
• Colors, typography, spacing, shared component styles. Ensure these components exist if referenced anywhere:
• StatusBadge
• SectionHeader
• CardStyle (modifier)
• PrimaryButtonStyle
• Any additional tokens/types used by views


DesignSystem.swift

import SwiftUI

// MARK: - RatioVita Design System

/// Comprehensive design system for RatioVita_v2
struct DesignSystem {
    
    // MARK: - Typography
    
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let bodyEmphasized = Font.body.weight(.medium)
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let round: CGFloat = 50
    }
    
    // MARK: - Shadows
    
    struct Shadow {
        static let small = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let large = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    /// Apply a shadow style
    func shadow(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

// MARK: - Card Style

struct CardStyle: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadow: ShadowStyle
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.ratioVitaAdaptiveSurface,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.md,
        shadow: ShadowStyle = DesignSystem.Shadow.small,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.md,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.md,
            trailing: DesignSystem.Spacing.md
        )
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(shadow)
    }
}

extension View {
    /// Apply card styling
    func cardStyle(
        backgroundColor: Color = Color.ratioVitaAdaptiveSurface,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.md,
        shadow: ShadowStyle = DesignSystem.Shadow.small,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.md,
            leading: DesignSystem.Spacing.md,
            bottom: DesignSystem.Spacing.md,
            trailing: DesignSystem.Spacing.md
        )
    ) -> some View {
        self.modifier(CardStyle(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadow: shadow,
            padding: padding
        ))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.ratioVitaPrimary,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.sm,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.sm,
            leading: DesignSystem.Spacing.lg,
            bottom: DesignSystem.Spacing.sm,
            trailing: DesignSystem.Spacing.lg
        )
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyEmphasized)
            .foregroundColor(foregroundColor)
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.clear,
        foregroundColor: Color = Color.ratioVitaPrimary,
        borderColor: Color = Color.ratioVitaPrimary,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.sm,
        padding: EdgeInsets = EdgeInsets(
            top: DesignSystem.Spacing.sm,
            leading: DesignSystem.Spacing.lg,
            bottom: DesignSystem.Spacing.sm,
            trailing: DesignSystem.Spacing.lg
        )
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyEmphasized)
            .foregroundColor(foregroundColor)
            .padding(padding)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let text: String
    let color: Color
    let backgroundColor: Color
    
    init(
        text: String,
        color: Color = .white,
        backgroundColor: Color = Color.ratioVitaInfo
    ) {
        self.text = text
        self.color = color
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.caption)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.xs)
    }
}

// MARK: - Predefined Status Badges

extension StatusBadge {
    static func success(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaSuccess)
    }
    
    static func warning(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaWarning)
    }
    
    static func error(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaError)
    }
    
    static func info(_ text: String) -> StatusBadge {
        StatusBadge(text: text, backgroundColor: Color.ratioVitaInfo)
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    let color: Color
    let backgroundColor: Color
    let onTap: (() -> Void)?
    
    init(
        text: String,
        color: Color = Color.ratioVitaAdaptiveText,
        backgroundColor: Color = Color.ratioVitaBorder,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.color = color
        self.backgroundColor = backgroundColor
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            Text(text)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(backgroundColor)
                .cornerRadius(DesignSystem.CornerRadius.xs)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionText: String?
    
    init(
        title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        actionText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionText = actionText
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.ratioVitaAdaptiveText)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(Color.ratioVitaTextSecondary)
                }
            }
            
            Spacer()
            
            if let action = action, let actionText = actionText {
                Button(action: action) {
                    Text(actionText)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(Color.ratioVitaPrimary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}




2.3 RatioVita/RatioVita/Utilities/ColorExtensions.swift
• Must include:
• ratioVitaPrimary, ratioVitaSecondary, ratioVitaAccent
• ratioVitaAdaptiveBackground, ratioVitaAdaptiveSurface, ratioVitaAdaptiveText
• ratioVitaTextSecondary, ratioVitaBorder (if used)

ColorExtensions.swift

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Color Extensions for RatioVita Design System

extension Color {
    /// Initialize Color from hex string
    /// - Parameter hex: Hex color string (e.g., "#FF0000" or "FF0000")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        var int: UInt64 = 0
        Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 8: // ARGB
            (a, r, g, b) = ((int & 0xFF000000) >> 24, (int & 0x00FF0000) >> 16, (int & 0x0000FF00) >> 8, int & 0x0000FF)
        case 6: // RGB
            (a, r, g, b) = (255, (int & 0xFF0000) >> 16, (int & 0x00FF00) >> 8, int & 0x0000FF)
        default:
            (a, r, g, b) = (255, 136, 136, 136)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
    
    /// Convert Color to hex string
    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
        #endif
    }
}

// MARK: - RatioVita Design System Colors

extension Color {
    /// Primary brand colors
    static let ratioVitaPrimary = Color(hex: "#2E7D32") // Forest Green
    static let ratioVitaSecondary = Color(hex: "#4CAF50") // Light Green
    static let ratioVitaAccent = Color(hex: "#FF9800") // Orange
    
    /// Status colors
    static let ratioVitaSuccess = Color(hex: "#4CAF50") // Green
    static let ratioVitaWarning = Color(hex: "#FF9800") // Orange
    static let ratioVitaError = Color(hex: "#F44336") // Red
    static let ratioVitaInfo = Color(hex: "#2196F3") // Blue
    
    /// Neutral colors
    static let ratioVitaBackground = Color(hex: "#FAFAFA") // Light Gray
    static let ratioVitaSurface = Color(hex: "#FFFFFF") // White
    static let ratioVitaBorder = Color(hex: "#E0E0E0") // Light Gray
    
    /// Text colors
    static let ratioVitaTextPrimary = Color(hex: "#212121") // Dark Gray
    static let ratioVitaTextSecondary = Color(hex: "#757575") // Medium Gray
    static let ratioVitaTextDisabled = Color(hex: "#BDBDBD") // Light Gray
}

// MARK: - Dark Mode Support

extension Color {
    /// Adaptive color that changes based on color scheme
    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #elseif canImport(AppKit)
        // Dynamic NSColor that adapts to appearance (darkAqua vs aqua)
        let dynamic = NSColor(name: NSColor.Name("Adaptive-\(UUID().uuidString)")) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        }
        return Color(dynamic)
        #endif
    }
    
    /// RatioVita adaptive colors
    static let ratioVitaAdaptiveBackground = adaptive(
        light: Color(hex: "#FAFAFA"),
        dark: Color(hex: "#121212")
    )
    
    static let ratioVitaAdaptiveSurface = adaptive(
        light: Color(hex: "#FFFFFF"),
        dark: Color(hex: "#1E1E1E")
    )
    
    static let ratioVitaAdaptiveText = adaptive(
        light: Color(hex: "#212121"),
        dark: Color(hex: "#FFFFFF")
    )
}

// MARK: - Tag Colors (from older project)

extension Color {
    /// Predefined tag colors for categorization
    static let tagColors: [Color] = [
        Color(hex: "#F44336"), // Red
        Color(hex: "#E91E63"), // Pink
        Color(hex: "#9C27B0"), // Purple
        Color(hex: "#673AB7"), // Deep Purple
        Color(hex: "#3F51B5"), // Indigo
        Color(hex: "#2196F3"), // Blue
        Color(hex: "#03A9F4"), // Light Blue
        Color(hex: "#00BCD4"), // Cyan
        Color(hex: "#009688"), // Teal
        Color(hex: "#4CAF50"), // Green
        Color(hex: "#8BC34A"), // Light Green
        Color(hex: "#CDDC39"), // Lime
        Color(hex: "#FFEB3B"), // Yellow
        Color(hex: "#FFC107"), // Amber
        Color(hex: "#FF9800"), // Orange
        Color(hex: "#FF5722"), // Deep Orange
        Color(hex: "#795548"), // Brown
        Color(hex: "#607D8B"), // Blue Grey
        Color(hex: "#9E9E9E"), // Grey
    ]
    
    /// Get a tag color by index
    static func tagColor(at index: Int) -> Color {
        tagColors[index % tagColors.count]
    }
}





2.4 ratioVitaTheme() (if defined separately)
• View extension/modifier that applies the theme.

,PATH TO FILE DEFINING ratioVitaTheme()IF SEPARATE>

MISSING.swift

⸻

3. SwiftData Models and Sample Data (full files)

3.1 @Model types
• Receipt
• ReceiptImage
• Item

Receipt.swift

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Model
final class Receipt {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var merchant: String
    var total: Decimal
    var currencyCode: String
    var notes: String?
    
    @Relationship(deleteRule: .cascade, inverse: \ReceiptImage.receipt) var images: [ReceiptImage]
    
    // MARK: - Computed Properties
    
    /// Cached first image for performance in list views
    var firstImage: RVImage? {
        images.sorted(by: { $0.pageIndex < $1.pageIndex }).first?.platformImage
    }
    
    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        merchant: String,
        total: Decimal,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        notes: String? = nil,
        images: [ReceiptImage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.merchant = merchant
        self.total = total
        self.currencyCode = currencyCode
        self.notes = notes
        self.images = images
    }
}




ReceiptImage.swift

import Foundation
import SwiftData
import CoreGraphics

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@Model
final class ReceiptImage {
    @Attribute(.unique) var id: UUID
    var pageIndex: Int
    var ocrText: String?
    var createdAt: Date
    
    // Stored as JPEG-encoded data for portability across platforms
    var imageData: Data
    
    // Parent relationship
    @Relationship var receipt: Receipt?
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        pageIndex: Int,
        image: RVImage,
        ocrText: String? = nil,
        createdAt: Date = .now,
        receipt: Receipt? = nil,
        compressionQuality: CGFloat = 0.9
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.ocrText = ocrText
        self.createdAt = createdAt
        imageData = ReceiptImage.encodeJPEG(image: image, quality: compressionQuality)
        self.receipt = receipt
    }
    
    // MARK: - Platform helpers
    
    var platformImage: RVImage? {
        ReceiptImage.decodeImage(from: imageData)
    }
    
    // MARK: - Encoding/Decoding
    
    private static func encodeJPEG(image: RVImage, quality: CGFloat) -> Data {
        #if canImport(UIKit)
        return image.jpegData(compressionQuality: quality) ?? Data()
        #elseif canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]) else
        {
            return Data()
        }
        return jpeg
        #endif
    }
    
    private static func decodeImage(from data: Data) -> RVImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #endif
    }
}






Item.swift

//
//  Item.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}





3.2 Sample/Preview Data
• SampleData (preview container)
• SampleSeed (debug seeding)

SampleData.swift

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SampleData {
    static var previewContainer: ModelContainer {
        let schema = Schema([
            Item.self,
            Receipt.self,
            ReceiptImage.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])

        let context = container.mainContext

        let r1 = Receipt(merchant: "Sample Mart", total: 19.99, currencyCode: "USD")
        let r2 = Receipt(merchant: "Coffee Corner", total: 4.75, currencyCode: "USD", notes: "Latte + croissant")

        let img = placeholderThumb()
        let i1 = ReceiptImage(pageIndex: 0, image: img, ocrText: "Sample Mart\nTotal 19.99")
        let i2 = ReceiptImage(pageIndex: 0, image: img, ocrText: "Coffee Corner\nTotal 4.75")

        r1.images = [i1]
        r2.images = [i2]

        context.insert(r1)
        context.insert(r2)

        return container
    }

    // MARK: - Cross-platform placeholder image

    static func placeholderThumb() -> RVImage {
        #if canImport(UIKit)
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.secondarySystemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let text = "Thumb"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
                .foregroundColor: UIColor.tertiaryLabel,
                .paragraphStyle: paragraph,
            ]
            let rect = CGRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
            text.draw(in: rect, withAttributes: attrs)
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 400, height: 600)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let text = "Thumb" as NSString
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let rect = NSRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
        text.draw(in: rect, withAttributes: attrs)

        return image
        #endif
    }
}




SampleSeed.swift

import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum SampleSeed {
    struct Options {
        var count: Int = 6
        var randomizeDates: Bool = true
        var randomizeTotals: Bool = true
        var includeNotes: Bool = true
        var ocrEnabled: Bool = true
        var compressionQuality: CGFloat = 0.9
        public init() {}
    }

    static func insertSamples(into context: ModelContext, options: Options = .init()) {
        let merchants = [
            "ACME Market",
            "Coffee Corner",
            "Tech Depot",
            "Fresh Farm Grocery",
            "City Fuel",
            "Bella Pizza",
            "Green Leaf Cafe",
            "Book Nook",
        ]

        let notesPool = [
            "Business lunch with client",
            "Office supplies restock",
            "Team coffee run",
            "Fuel for site visit",
            "Weekly grocery",
            "Promo applied at checkout",
        ]

        let calendar = Calendar.current
        let now = Date()

        for i in 0..<options.count {
            _ = i
            let merchant = merchants.randomElement() ?? "Sample Merchant"
            let base = Decimal(Int.random(in: 10...99))
            let cents = Decimal(Double.random(in: 0..<1))
            let total = options.randomizeTotals ? (base + cents) : Decimal(19.99)

            let dayOffset = Int.random(in: 0...20)
            let createdAt = options.randomizeDates ? (calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now) : now

            let currency = Locale.current.currency?.identifier ?? "USD"
            let notes = options.includeNotes ? notesPool.randomElement() : nil

            let receipt = Receipt(
                createdAt: createdAt,
                merchant: merchant,
                total: total,
                currencyCode: currency,
                notes: notes
            )

            let pageCount = [1, 1, 1, 2].randomElement() ?? 1
            var images: [ReceiptImage] = []

            for page in 0..<pageCount {
                let rv = placeholderReceiptImage(width: 900, height: 1400, title: merchant, page: page + 1)
                let ocrText = options.ocrEnabled ? makeOCRText(merchant: merchant, total: total, date: createdAt, page: page + 1) : nil

                let img = ReceiptImage(
                    pageIndex: page,
                    image: rv,
                    ocrText: ocrText,
                    createdAt: createdAt,
                    receipt: receipt,
                    compressionQuality: options.compressionQuality
                )
                images.append(img)
            }

            receipt.images = images
            context.insert(receipt)
        }

        try? context.save()
    }

    private static func makeOCRText(merchant: String, total: Decimal, date: Date, page: Int) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let dateString = df.string(from: date)

        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = Locale.current.currency?.identifier ?? "USD"
        let totalString = nf.string(from: total as NSDecimalNumber) ?? "\(total)"

        return """
        \(merchant.uppercased())
        Date: \(dateString)
        Page: \(page)
        Subtotal: \(totalString)
        Tax: \(nf.string(from: 1.23) ?? "1.23")
        Total: \(totalString)
        Items:
          - Coffee x1 3.50
          - Sandwich x1 7.20
        Thank you!
        """
    }

    private static func placeholderReceiptImage(width: Int, height: Int, title: String, page: Int) -> RVImage {
        #if canImport(UIKit)
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .bold),
                .foregroundColor: UIColor.label,
            ]
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel,
            ]

            NSString(string: title).draw(
                in: CGRect(x: 40, y: 60, width: size.width - 80, height: 80),
                withAttributes: titleAttrs
            )

            NSString(string: "Page \(page)").draw(
                in: CGRect(x: 40, y: 140, width: size.width - 80, height: 40),
                withAttributes: subtitleAttrs
            )

            let lineAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.tertiaryLabel,
            ]
            for i in 0..<20 {
                NSString(string: "Item \(i + 1)   1 x 3.99     3.99")
                    .draw(in: CGRect(x: 40, y: 220 + i * 28, width: Int(size.width - 80), height: 24), withAttributes: lineAttrs)
            }
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 56, weight: .bold),
            .foregroundColor: NSColor.labelColor,
        ]
        NSString(string: title).draw(in: NSRect(x: 40, y: size.height - 140, width: size.width - 80, height: 80), withAttributes: titleAttrs)

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        NSString(string: "Page \(page)").draw(in: NSRect(x: 40, y: size.height - 180, width: size.width - 80, height: 40), withAttributes: subtitleAttrs)

        let lineAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        for i in 0..<20 {
            NSString(string: "Item \(i + 1)   1 x 3.99     3.99")
                .draw(in: NSRect(x: 40, y: size.height - 260 - CGFloat(i * 28), width: size.width - 80, height: 24), withAttributes: lineAttrs)
        }

        return image
        #endif
    }
}



⸻

4. Views (full files)

4.1 RatioVita/RatioVita/ReceiptsView.swift
• Re‑paste if updated.


ReceiptsView.swift

import SwiftUI
import SwiftData

struct ReceiptsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Receipt.createdAt, order: .reverse, animation: .default)
    private var receipts: [Receipt]

    @StateObject private var viewModel: ReceiptsViewModel

    @AppStorage("ocrEnabled") private var ocrEnabled: Bool = true
    @AppStorage("compressionEnabled") private var compressionEnabled: Bool = false

    @State private var searchText: String = ""

    init() {
        // Create a temporary in-memory context only to satisfy @StateObject initialization.
        // We will update the dependencies safely in .onAppear without reassigning the StateObject.
        let schema = Schema([Item.self, Receipt.self, ReceiptImage.self])
        let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        _viewModel = StateObject(wrappedValue: ReceiptsViewModel(scanner: PreviewScannerService(), context: ModelContext(container)))
    }

    var body: some View {
        let filtered = filteredReceipts()

        VStack(spacing: 0) {
            // Enhanced header with search
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    SectionHeader(
                        title: "Receipts",
                        subtitle: "\(filtered.count) receipt\(filtered.count == 1 ? "" : "s")"
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .background(Color.ratioVitaAdaptiveBackground)
            
            // Enhanced list with new design system
            List {
                ForEach(filtered) { receipt in
                    NavigationLink {
                        ReceiptDetailView(receipt: receipt)
                    } label: {
                        ReceiptRowView(receipt: receipt)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: DesignSystem.Spacing.xs,
                        leading: DesignSystem.Spacing.md,
                        bottom: DesignSystem.Spacing.xs,
                        trailing: DesignSystem.Spacing.md
                    ))
                }
                .onDelete { offsets in
                    delete(at: offsets, from: filtered)
                }
            }
            .listStyle(PlainListStyle())
            .background(Color.ratioVitaAdaptiveBackground)
            .searchable(text: $searchText, placement: .automatic)
            .overlay {
                if receipts.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 64))
                            .foregroundColor(Color.ratioVitaTextSecondary)
                        
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("No Receipts")
                                .font(DesignSystem.Typography.title2)
                                .foregroundColor(Color.ratioVitaAdaptiveText)
                            
                            Text("Tap Scan to add your first receipt.")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(Color.ratioVitaTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(DesignSystem.Spacing.xl)
                }
            }
            .toolbar {
                // Settings + Scan
                #if os(iOS)
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    ScanButton(isScanning: viewModel.isScanning) {
                        viewModel.showScannerUI()
                    }
                }
                #else
                ToolbarItemGroup(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    ScanButton(isScanning: viewModel.isScanning) {
                        viewModel.showScannerUI()
                    }
                }
                #endif

                // Seed button (DEBUG only), platform-appropriate placement
                #if DEBUG
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        SampleSeed.insertSamples(into: modelContext)
                    } label: {
                        Label("Seed", systemImage: "tray.and.arrow.down.fill")
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        SampleSeed.insertSamples(into: modelContext)
                    } label: {
                        Label("Seed", systemImage: "tray.and.arrow.down.fill")
                    }
                }
                #endif
                #endif
            }
        }
        .onAppear {
            // IMPORTANT: Do NOT reassign the @StateObject.
            // Update its dependencies instead so we avoid "invalid reuse after initialization failure".
            #if os(iOS)
            #if targetEnvironment(simulator)
            let scanner: ScannerService = PreviewScannerService()
            #else
            let scanner: ScannerService = RealScannerService()
            #endif
            #else
            let scanner: ScannerService = PreviewScannerService()
            #endif

            viewModel.updateDependencies(scanner: scanner, context: modelContext)
        }
        .sheet(isPresented: $viewModel.showScanner) {
            #if os(iOS)
            CameraCaptureView { scanResult in
                // Wrap in Task so this compiles whether the closure is sync or async.
                Task {
                    await viewModel.handleScanResult(scanResult)
                }
            }
            #else
            ScannerView()
            #endif
        }
    }

    private func delete(at offsets: IndexSet, from filtered: [Receipt]) {
        let toDelete = offsets.map { filtered[$0] }
        viewModel.delete(toDelete)
    }

    private func filteredReceipts() -> [Receipt] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return receipts
        }
        let term = searchText.lowercased()
        return receipts.filter { r in
            if r.merchant.lowercased().contains(term) { return true }
            if r.notes?.lowercased().contains(term) == true { return true }
            if r.images.contains(where: { ($0.ocrText?.lowercased().contains(term) ?? false) }) { return true }
            return false
        }
    }

    private func formattedTotal(_ receipt: Receipt) -> String {
        let formatter = CurrencyFormatter.shared
        return formatter.format(receipt.total, currencyCode: receipt.currencyCode)
    }
}

// MARK: - Receipt Row View

struct ReceiptRowView: View {
    let receipt: Receipt
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Receipt thumbnail
            Group {
                if let firstImage = receipt.firstImage {
                    Image(rvImage: firstImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 80)
                        .clipped()
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                } else {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(Color.ratioVitaBorder)
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: "doc.text.image")
                                .font(.title2)
                                .foregroundColor(Color.ratioVitaTextSecondary)
                        )
                }
            }
            .shadow(DesignSystem.Shadow.small)
            
            // Receipt details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(receipt.merchant)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.ratioVitaAdaptiveText)
                    .lineLimit(1)
                
                Text(receipt.createdAt, style: .date)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(Color.ratioVitaTextSecondary)
                
                if let notes = receipt.notes, !notes.isEmpty {
                    Text(notes)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(Color.ratioVitaTextSecondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status badges
                HStack(spacing: DesignSystem.Spacing.xs) {
                    if receipt.images.count > 1 {
                        StatusBadge.info("\(receipt.images.count) pages")
                    }
                    
                    // Show OCR badge if any image has OCR text
                    if receipt.images.contains(where: { $0.ocrText?.isEmpty == false }) {
                        StatusBadge.success("OCR")
                    }
                }
            }
            
            Spacer()
            
            // Total amount
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                Text(formattedTotal(receipt))
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(Color.ratioVitaPrimary)
                    .fontWeight(.semibold)
                
                Text(receipt.currencyCode)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(Color.ratioVitaTextSecondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .cardStyle(
            backgroundColor: Color.ratioVitaAdaptiveSurface,
            cornerRadius: DesignSystem.CornerRadius.md,
            shadow: DesignSystem.Shadow.small
        )
    }

    private func formattedTotal(_ receipt: Receipt) -> String {
        let formatter = CurrencyFormatter.shared
        return formatter.format(receipt.total, currencyCode: receipt.currencyCode)
    }
}

#Preview("ReceiptsView") {
    NavigationStack {
        ReceiptsView()
    }
    .modelContainer(SampleData.previewContainer)
}




4.2 <PATH>/ReceiptDetailView.swift

RwceiptDetailView.swift


import SwiftData
import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(receipt.merchant)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(receipt.createdAt, style: .date)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(receipt.total, format: .currency(code: receipt.currencyCode))
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal)
                
                // Images
                if !receipt.images.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Receipt Images")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(receipt.images.enumerated()), id: \.element.id) { _, image in
                                    VStack {
                                        if let platformImage = image.platformImage {
                                            Image(rvImage: platformImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 400)
                                                .cornerRadius(12)
                                        } else {
                                            placeholderImage()
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 400)
                                                .cornerRadius(12)
                                        }
                                        
                                        if let _ = image.ocrText {
                                            Text("Page \(image.pageIndex + 1)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Notes
                if let notes = receipt.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // OCR Text
                if let firstImage = receipt.images.first, let ocrText = firstImage.ocrText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Text")
                            .font(.headline)
                        Text(ocrText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding()
                            .background(
                                Group {
                                    #if os(iOS)
                                    Color(.systemGray6)
                                    #else
                                    Color.secondary.opacity(0.1)
                                    #endif
                                }
                            )
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Receipt Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
            #endif
        }
        .sheet(isPresented: $showingEditSheet) {
            EditReceiptView(receipt: receipt)
        }
    }
    
    // Return Image explicitly so Image modifiers like .resizable() are available
    private func placeholderImage() -> Image {
        #if canImport(UIKit)
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemGray5.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let text = "Image Unavailable"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.systemGray,
            ]
            let rect = CGRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
            text.draw(in: rect, withAttributes: attrs)
        }
        return Image(rvImage: image)
        #elseif canImport(AppKit)
        let size = NSSize(width: 300, height: 400)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        NSColor.systemGray.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        let text = "Image Unavailable" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.systemGray,
        ]
        let rect = NSRect(x: 0, y: size.height / 2 - 20, width: size.width, height: 40)
        text.draw(in: rect, withAttributes: attrs)
        
        return Image(nsImage: image)
        #endif
    }
}

struct EditReceiptView: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss
    @State private var merchant: String
    @State private var total: String
    @State private var notes: String
    
    init(receipt: Receipt) {
        self.receipt = receipt
        _merchant = State(initialValue: receipt.merchant)
        _total = State(initialValue: receipt.total.formatted(.currency(code: receipt.currencyCode)))
        _notes = State(initialValue: receipt.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Receipt Details") {
                    TextField("Merchant", text: $merchant)
                    TextField("Total", text: $total)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Receipt")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
    
    private func saveChanges() {
        receipt.merchant = merchant
        
        // Try to parse a currency-formatted string gracefully
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = receipt.currencyCode
        
        if let number = nf.number(from: total) {
            receipt.total = number.decimalValue
        } else if let plain = Decimal(string: total.filter { "0123456789.,".contains($0) }) {
            receipt.total = plain
        }
        
        receipt.notes = notes.isEmpty ? nil : notes
    }
}




4.3 <PATH>/SettingsView.swift
SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @AppStorage("ocrEnabled") private var ocrEnabled = true
    @AppStorage("compressionEnabled") private var compressionEnabled = true
    @AppStorage("compressionQuality") private var compressionQuality = 0.8
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // Scanner Settings Section
                Section {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Enable OCR")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Extract text from receipts automatically")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $ocrEnabled)
                                .labelsHidden()
                        }
                        
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Enable Compression")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Reduce file size for storage")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $compressionEnabled)
                                .labelsHidden()
                        }
                    
                    if compressionEnabled {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack {
                                    Text("Compression Quality")
                                        .font(DesignSystem.Typography.bodyEmphasized)
                                    
                                    Spacer()
                                    
                                    StatusBadge.info("\(Int(compressionQuality * 100))%")
                                }
                                
                            Slider(value: $compressionQuality, in: 0.1...1.0, step: 0.1)
                                    .accentColor(Color.ratioVitaPrimary)
                        }
                    }
                }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "Scanner Settings",
                        subtitle: "Configure receipt scanning behavior"
                    )
                }
                
                // Theme Settings Section
                Section {
                    NavigationLink {
                        ThemePreview()
                    } label: {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Appearance")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("Customize colors and themes")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Circle()
                                    .fill(themeManager.customTheme.primaryColor)
                                    .frame(width: 12, height: 12)
                                
                                Circle()
                                    .fill(themeManager.customTheme.secondaryColor)
                                    .frame(width: 12, height: 12)
                                
                                Circle()
                                    .fill(themeManager.customTheme.accentColor)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        title: "Appearance",
                        subtitle: "Customize the look and feel"
                    )
                }
                
                // About Section
                Section {
                    VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Version")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("1.0.0")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(Color.ratioVitaPrimary)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text("Build")
                                    .font(DesignSystem.Typography.bodyEmphasized)
                                Text("RatioVita v2")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(Color.ratioVitaTextSecondary)
                            }
                            
                        Spacer()
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                } header: {
                    SectionHeader(
                        title: "About",
                        subtitle: "App information and version"
                    )
                }
            }
            .navigationTitle("Settings")
            .ratioVitaTheme()
        }
    }
}




⸻

5. ViewModels (full files)

5.1 <PATH>/ReceiptsViewModel.swift
• Include init, properties, and updateDependencies(scanner:context:).

ReceiptsViewModel.swift


import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class ReceiptsViewModel: ObservableObject {
    @Published var isScanning = false
    @Published var searchText: String = ""
    @Published var showScanner = false

    // Mutable so dependencies can be updated without replacing the StateObject.
    private(set) var scanner: ScannerService
    private(set) var context: ModelContext

    @AppStorage("ocrEnabled") private var ocrEnabled: Bool = true
    @AppStorage("compressionEnabled") private var compressionEnabled: Bool = false

    init(scanner: ScannerService, context: ModelContext) {
        self.scanner = scanner
        self.context = context
    }

    // Update dependencies safely (avoid reassigning the @StateObject in the view).
    func updateDependencies(scanner: ScannerService, context: ModelContext) {
        self.scanner = scanner
        self.context = context
    }

    func scanAndSave() async {
        isScanning = true
        defer { isScanning = false }

        do {
            let result = try await scanner.scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)

            let receipt = Receipt(
                merchant: result.extractedData.merchant ?? "Unknown Merchant",
                total: result.extractedData.total ?? 0,
                currencyCode: result.extractedData.currency ?? (Locale.current.currency?.identifier ?? "USD")
            )

            var images: [ReceiptImage] = []
            for (idx, page) in result.scannedPages.enumerated() {
                let img = ReceiptImage(
                    pageIndex: idx,
                    image: page.image,
                    ocrText: page.ocrText,
                    receipt: receipt,
                    compressionQuality: compressionEnabled ? 0.6 : 0.9
                )
                images.append(img)
            }
            receipt.images = images

            context.insert(receipt)
            try context.save()
        } catch {
            print("Scan failed: \(error)")
        }
    }

    func delete(_ receipts: [Receipt]) {
        for r in receipts {
            context.delete(r)
        }
        try? context.save()
    }
    
    // MARK: - Scanner Presentation
    
    func showScannerUI() {
        showScanner = true
    }
    
    func handleScanResult(_ result: ScanResult) async {
        isScanning = true
        defer { 
            isScanning = false
            showScanner = false
        }
        
        do {
            let receipt = Receipt(
                merchant: result.extractedData.merchant ?? "Unknown Merchant",
                total: result.extractedData.total ?? 0,
                currencyCode: result.extractedData.currency ?? (Locale.current.currency?.identifier ?? "USD")
            )

            var images: [ReceiptImage] = []
            for (idx, page) in result.scannedPages.enumerated() {
                let img = ReceiptImage(
                    pageIndex: idx,
                    image: page.image,
                    ocrText: page.ocrText,
                    receipt: receipt,
                    compressionQuality: compressionEnabled ? 0.6 : 0.9
                )
                images.append(img)
            }
            receipt.images = images

            context.insert(receipt)
            try context.save()
        } catch {
            print("Scan result processing failed: \(error)")
        }
    }
}




⸻

6. Scanner Services and Camera UI (full files)

6.1 <PATH>/ScannerService.swift (protocol and shared types if present)
• If ScanResult/ExtractedData/ScannedPage/ProcessingMetadata/DetectedRectangle are declared here, include them fully.
• If they live in other files, paste those files in section 10.


ScannerService.swift􀰓



import Foundation
import SwiftUI
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Camera permission status
enum CameraPermissionStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unavailable
    
    var displayName: String {
        switch self {
            case .notDetermined: "Not Determined"
            case .denied: "Denied"
            case .restricted: "Restricted"
            case .authorized: "Authorized"
            case .unavailable: "Unavailable"
        }
    }
    
    var canUseCamera: Bool {
        self == .authorized
    }
    
    var requiresPermissionRequest: Bool {
        self == .notDetermined
    }
    
    var requiresSettingsAccess: Bool {
        self == .denied || self == .restricted
    }
}

/// Errors that can occur during scanning operations
enum ScannerError: LocalizedError {
    case cameraPermissionDenied
    case cameraUnavailable
    case captureFailed
    case imageProcessingFailed
    case ocrFailed
    case compressionFailed
    case invalidImage
    case processingTimeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
            case .cameraPermissionDenied:
                "Camera permission is required to scan receipts"
            case .cameraUnavailable:
                "Camera is not available on this device"
            case .captureFailed:
                "Failed to capture image from camera"
            case .imageProcessingFailed:
                "Failed to process the captured image"
            case .ocrFailed:
                "Failed to extract text from the image"
            case .compressionFailed:
                "The image will be saved without compression"
            case .invalidImage:
                "The captured image is invalid or corrupted"
            case .processingTimeout:
                "Please try again with a smaller image or disable compression"
            case let .unknown(error):
                "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
            case .cameraPermissionDenied:
                "Please enable camera access in Settings > Privacy & Security > Camera"
            case .cameraUnavailable:
                "Please use a device with a camera or try importing an image from your photo library"
            case .captureFailed:
                "Please try again or check if the camera is being used by another app"
            case .imageProcessingFailed:
                "Please try again with a clearer image"
            case .ocrFailed:
                "Please try again with a clearer image or manually enter the receipt details"
            case .compressionFailed:
                "The image will be saved without compression"
            case .invalidImage:
                "Please try capturing the image again"
            case .processingTimeout:
                "Please try again with a smaller image or disable compression"
            case .unknown:
                "Please try again or contact support if the problem persists"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
            case .cameraPermissionDenied, .cameraUnavailable:
                false
            case .captureFailed, .imageProcessingFailed, .ocrFailed, .compressionFailed, .invalidImage,
                 .processingTimeout:
                true
            case .unknown:
                false
        }
    }
}

/// Configuration options for scanning operations
struct ScannerConfiguration {
    let ocrEnabled: Bool
    let compressionEnabled: Bool
    let compressionQuality: Double
    let maxImageSize: CGSize?
    let ocrRecognitionLevel: OCRRecognitionLevel
    let autoCaptureEnabled: Bool
    let documentDetectionEnabled: Bool
    
    init(
        ocrEnabled: Bool = true,
        compressionEnabled: Bool = true,
        compressionQuality: Double = 0.8,
        maxImageSize: CGSize? = nil,
        ocrRecognitionLevel: OCRRecognitionLevel = .accurate,
        autoCaptureEnabled: Bool = true,
        documentDetectionEnabled: Bool = true
    ) {
        self.ocrEnabled = ocrEnabled
        self.compressionEnabled = compressionEnabled
        self.compressionQuality = max(0.1, min(1.0, compressionQuality))
        self.maxImageSize = maxImageSize
        self.ocrRecognitionLevel = ocrRecognitionLevel
        self.autoCaptureEnabled = autoCaptureEnabled
        self.documentDetectionEnabled = documentDetectionEnabled
    }
}

/// OCR recognition level options
enum OCRRecognitionLevel {
    case fast
    case accurate
    
    var visionLevel: String {
        switch self {
            case .fast: "fast"
            case .accurate: "accurate"
        }
    }
    
    var description: String {
        switch self {
            case .fast: "Fast (lower accuracy)"
            case .accurate: "Accurate (slower processing)"
        }
    }
}

/// Protocol defining the interface for receipt scanning services
protocol ScannerService {
    /// Scans a receipt and returns structured data
    /// - Parameters:
    ///   - ocrEnabled: Whether to perform OCR text recognition
    ///   - compressionEnabled: Whether to compress the captured images
    /// - Returns: A ScanResult containing the scanned pages and extracted data
    /// - Throws: ScannerError if scanning fails
    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult
    
    // MARK: - Phase 2: Camera control abstractions (optional to implement)
    
    /// Requests camera permission (iOS)
    func requestCameraPermission() async -> Bool
    
    /// Returns whether a camera is available on this device
    func isCameraAvailable() -> Bool
    
    /// Returns current camera permission status
    func getCameraPermissionStatus() -> CameraPermissionStatus
    
    /// Type-erased preview layer for camera preview.
    /// On iOS, this returns AVCaptureVideoPreviewLayer; on other platforms it may be nil.
    func getVideoPreviewLayer() -> Any?
    
    /// Switches between front and back cameras if supported
    func switchCamera()
    
    /// Focuses the camera at a given point in view coordinates if supported
    func focusCamera(at point: CGPoint)
}

/// Default no-op implementations so conformers don’t need to implement optional hooks
extension ScannerService {
    func requestCameraPermission() async -> Bool { false }
    func isCameraAvailable() -> Bool { false }
    func getCameraPermissionStatus() -> CameraPermissionStatus { .unavailable }
    func getVideoPreviewLayer() -> Any? { nil }
    func switchCamera() {}
    func focusCamera(at _: CGPoint) {}
}




6.2 <PATH>/PreviewScannerService.swift􀰓

PreviewScannerService.swift􀰓

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PreviewScannerError: Error {
    case failed
}

final class PreviewScannerService: ScannerService {
    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // Simulate a short delay like a real scan
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let demoImage = Self.placeholderImage()
        let ocr = ocrEnabled ? "ACME MARKET\nDate: \(Date())\nTotal: 42.39\nItems: Apples, Bread, Milk" : nil
        
        // Create extracted data
        let extractedData = ExtractedData(
            merchant: "ACME Market",
            total: Decimal(string: "42.39") ?? 42.39,
            currency: Locale.current.currency?.identifier ?? "USD",
            date: Date(),
            merchantConfidence: 0.95,
            totalConfidence: 0.98,
            dateConfidence: 0.90
        )
        
        // Create processing metadata
        let processingSteps = [
            ImageProcessingStep(name: "Capture", description: "Image captured", duration: 0.1),
            ImageProcessingStep(name: "OCR", description: "Text recognition", duration: 0.5),
            ImageProcessingStep(name: "Parsing", description: "Data extraction", duration: 0.2)
        ]
        
        let metadata = ProcessingMetadata(
            processingTime: 0.8,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: compressionEnabled ? 0.6 : 0.9,
            imageProcessingSteps: processingSteps
        )
        
        // Create scanned page
        let page = ScannedPage(
            image: demoImage,
            originalImage: demoImage,
            pageNumber: 1,
            ocrText: ocr,
            confidence: ocrEnabled ? 0.85 : nil
        )
        
        return ScanResult(
            scannedPages: [page],
            extractedData: extractedData,
            processingMetadata: metadata
        )
    }
    
    // MARK: - Phase 2 optional hooks (no-ops for preview)
    func requestCameraPermission() async -> Bool { true }
    func isCameraAvailable() -> Bool { true }
    func getCameraPermissionStatus() -> CameraPermissionStatus { .authorized }
    func getVideoPreviewLayer() -> Any? { nil }
    func switchCamera() {}
    func focusCamera(at _: CGPoint) {}
    
    // MARK: - Cross-platform placeholder
    
    private static func placeholderImage() -> RVImage {
        #if canImport(UIKit)
        let size = CGSize(width: 800, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            let text = "Receipt Preview"
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph,
            ]
            let rect = CGRect(x: 0, y: size.height / 2 - 30, width: size.width, height: 60)
            text.draw(in: rect, withAttributes: attrs)
        }
        #elseif canImport(AppKit)
        let size = NSSize(width: 800, height: 1200)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        let text = "Receipt Preview" as NSString
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 42, weight: .bold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let rect = NSRect(x: 0, y: size.height / 2 - 30, width: size.width, height: 60)
        text.draw(in: rect, withAttributes: attrs)
        
        return image
        #endif
    }
}




6.3 <PATH>/RealScannerService.swift􀰓
• Must not touch camera at app launch outside of user action.
• If it references helper types (CameraPermissions, ImageProcessing, ProcessingOptions, OCRParsing, OCRResult, DetectedRectangle), include those files in section 10.

RealScannerService.swift􀰓


#if os(iOS)
//
//  RealScannerService.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import AVFoundation
import Foundation
import UIKit
import Vision

/// Production scanner service using AVFoundation and Vision frameworks
class RealScannerService: NSObject, ScannerService {
    // MARK: - Properties

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    // Camera configuration
    private var cameraPosition: AVCaptureDevice.Position = .back
    private var isSessionRunning = false
    
    // Processing state
    private var isProcessing = false
    private var processingQueue = DispatchQueue(label: "com.ratiovita.scanner.processing", qos: .userInitiated)
    
    // Retain the delegate during capture to avoid early deallocation
    private var currentPhotoDelegate: PhotoCaptureDelegate?
    
    // Configuration
    private let configuration: ScannerConfiguration
    
    // MARK: - Initialization

    override init() {
        configuration = ScannerConfiguration()
        super.init()
        setupCaptureSession()
    }
    
    init(configuration: ScannerConfiguration) {
        self.configuration = configuration
        super.init()
        setupCaptureSession()
    }
    
    // MARK: - ScannerService Implementation
    
    func scanReceipt(ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // 1) Camera availability
        guard isCameraAvailable() else {
            throw ScannerError.cameraUnavailable
        }
        
        // 2) Permission flow (avoid guard else that doesn't exit)
        let status = getCameraPermissionStatus()
        switch status {
        case .authorized:
            break
        case .notDetermined:
            let granted = await requestCameraPermission()
            guard granted else {
                throw ScannerError.cameraPermissionDenied
            }
        case .denied, .restricted, .unavailable:
            throw ScannerError.cameraPermissionDenied
        }
        
        // 3) Start capture session if not running
        await startCaptureSessionIfNeeded()
        
        // 4) Capture image
        let capturedImage = try await captureImage()
        
        // 5) Process image
        let processedImage = try await processImage(capturedImage, compressionEnabled: compressionEnabled)
        
        // 6) Perform OCR if enabled
        var ocrText: String?
        var confidence: Double?
        var detectedRectangles: [DetectedRectangle]?
        
        if ocrEnabled {
            let ocrResult = try await performOCR(on: processedImage)
            ocrText = ocrResult.text
            confidence = ocrResult.confidence
            detectedRectangles = ocrResult.detectedRectangles
        }
        
        // 7) Create scanned page
        let scannedPage = ScannedPage(
            image: processedImage,
            originalImage: capturedImage,
            pageNumber: 1,
            ocrText: ocrText,
            confidence: confidence,
            detectedRectangles: detectedRectangles
        )
        
        // 8) Extract structured data from OCR
        let extractedData = ocrEnabled && ocrText != nil
            ? OCRParsing.extractData(from: ocrText!)
            : ExtractedData()
        
        // 9) Create processing metadata
        let processingSteps = [
            ImageProcessingStep(name: "Image Capture", description: "Captured image from camera", duration: 0.5),
            ImageProcessingStep(name: "Image Processing", description: "Applied enhancement filters", duration: 0.8),
            ImageProcessingStep(
                name: "OCR Processing",
                description: "Extracted text using Vision framework",
                duration: ocrEnabled ? 1.2 : 0.0
            ),
        ]
        
        let processingMetadata = ProcessingMetadata(
            processingTime: 2.0,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: configuration.compressionQuality,
            imageProcessingSteps: processingSteps
        )
        
        return ScanResult(
            scannedPages: [scannedPage],
            extractedData: extractedData,
            processingMetadata: processingMetadata
        )
    }
    
    func requestCameraPermission() async -> Bool {
        await CameraPermissions.requestCameraPermission()
    }
    
    func isCameraAvailable() -> Bool {
        CameraPermissions.isCameraAvailable()
    }
    
    func getCameraPermissionStatus() -> CameraPermissionStatus {
        CameraPermissions.getCameraPermissionStatus()
    }
    
    func scanMultiPageReceipt(maxPages _: Int, ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // For MVP, return single page result
        try await scanReceipt(ocrEnabled: ocrEnabled, compressionEnabled: compressionEnabled)
    }
    
    func processExistingImage(_ image: UIImage, ocrEnabled: Bool, compressionEnabled: Bool) async throws -> ScanResult {
        // Process existing image (e.g., from photo library)
        let processedImage = try await processImage(image, compressionEnabled: compressionEnabled)
        
        // Perform OCR if enabled
        var ocrText: String?
        var confidence: Double?
        var detectedRectangles: [DetectedRectangle]?
        
        if ocrEnabled {
            let ocrResult = try await performOCR(on: processedImage)
            ocrText = ocrResult.text
            confidence = ocrResult.confidence
            detectedRectangles = ocrResult.detectedRectangles
        }
        
        // Create scanned page
        let scannedPage = ScannedPage(
            image: processedImage,
            originalImage: image,
            pageNumber: 1,
            ocrText: ocrText,
            confidence: confidence,
            detectedRectangles: detectedRectangles
        )
        
        // Extract structured data from OCR
        let extractedData = ocrEnabled && ocrText != nil
            ? OCRParsing.extractData(from: ocrText!)
            : ExtractedData()
        
        // Create processing metadata
        let processingSteps = [
            ImageProcessingStep(name: "Image Import", description: "Imported image from library", duration: 0.2),
            ImageProcessingStep(name: "Image Processing", description: "Applied enhancement filters", duration: 0.8),
            ImageProcessingStep(
                name: "OCR Processing",
                description: "Extracted text using Vision framework",
                duration: ocrEnabled ? 1.0 : 0.0
            ),
        ]
        
        let processingMetadata = ProcessingMetadata(
            processingTime: 1.5,
            ocrEnabled: ocrEnabled,
            compressionEnabled: compressionEnabled,
            compressionQuality: configuration.compressionQuality,
            imageProcessingSteps: processingSteps
        )
        
        return ScanResult(
            scannedPages: [scannedPage],
            extractedData: extractedData,
            processingMetadata: processingMetadata
        )
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        // Configure camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            print("Failed to get camera device")
            return
        }
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            if captureSession?.canAddInput(cameraInput) == true {
                captureSession?.addInput(cameraInput)
            }
        } catch {
            print("Failed to create camera input: \(error)")
            return
        }
        
        // Configure photo output
        let output = AVCapturePhotoOutput()
        if captureSession?.canAddOutput(output) == true {
            captureSession?.addOutput(output)
            photoOutput = output
        } else {
            photoOutput = nil
        }
        
        // Configure video preview layer
        if let session = captureSession {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            videoPreviewLayer = layer
        } else {
            videoPreviewLayer = nil
        }
    }
    
    private func startCaptureSessionIfNeeded() async {
        guard let captureSession, !isSessionRunning else { return }
        
        await MainActor.run {
            captureSession.startRunning()
            isSessionRunning = true
        }
    }
    
    private func stopCaptureSession() async {
        guard let captureSession, isSessionRunning else { return }
        
        await MainActor.run {
            captureSession.stopRunning()
            isSessionRunning = false
        }
    }
    
    private func captureImage() async throws -> UIImage {
        guard let photoOutput else {
            throw ScannerError.captureFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            
            // Retain the delegate until we resume the continuation
            self.currentPhotoDelegate = PhotoCaptureDelegate { image in
                self.currentPhotoDelegate = nil
                continuation.resume(returning: image)
            } onError: { error in
                self.currentPhotoDelegate = nil
                continuation.resume(throwing: error)
            }
            
            if let delegate = self.currentPhotoDelegate {
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            } else {
                continuation.resume(throwing: ScannerError.captureFailed)
            }
        }
    }
    
    private func processImage(_ image: UIImage, compressionEnabled _: Bool) async throws -> UIImage {
        // Apply image processing
        let processingOptions = ProcessingOptions.receiptDefault
        let processedImage = try await ImageProcessing.processImage(image, with: processingOptions)
        return processedImage
    }
    
    private func performOCR(on image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw ScannerError.ocrFailed
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = configuration.ocrRecognitionLevel == .fast ? .fast : .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let results = request.results else {
            throw ScannerError.ocrFailed
        }
        
        // Extract text and confidence
        let recognizedStrings = results.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        
        let ocrText = recognizedStrings.joined(separator: "\n")
        let confidences = results.compactMap { observation in
            observation.topCandidates(1).first?.confidence
        }
        let averageConfidence = confidences.isEmpty ? 0.0 : Double(confidences.reduce(0.0, +)) / Double(confidences.count)
        
        // Detect document rectangles
        let detectedRectangles = try await detectDocumentRectangles(in: image)
        
        return OCRResult(
            text: ocrText,
            confidence: Double(averageConfidence),
            detectedRectangles: detectedRectangles
        )
    }
    
    private func detectDocumentRectangles(in image: UIImage) async throws -> [DetectedRectangle] {
        guard let cgImage = image.cgImage else {
            return []
        }
        
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.1
        request.maximumObservations = 5
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        
        guard let results = request.results else {
            return []
        }
        
        return results.map { observation in
            DetectedRectangle(
                boundingBox: observation.boundingBox,
                confidence: Double(observation.confidence),
                corners: [
                    observation.topLeft,
                    observation.topRight,
                    observation.bottomRight,
                    observation.bottomLeft,
                ]
            )
        }.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Public Methods for UI Integration
    
    func getVideoPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        videoPreviewLayer
    }
    
    func switchCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
        setupCaptureSession()
    }
    
    func focusCamera(at point: CGPoint) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to configure camera focus: \(error)")
        }
    }
}

// MARK: - Photo Capture Delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onSuccess: (UIImage) -> Void
    private let onError: (Error) -> Void
    
    init(onSuccess: @escaping (UIImage) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            onError(error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            onError(ScannerError.invalidImage)
            return
        }
        
        onSuccess(image)
    }
}

// MARK: - OCR Result

private struct OCRResult {
    let text: String
    let confidence: Double
    let detectedRectangles: [DetectedRectangle]
}
#endif



6.4 Camera UI
• iOS camera sheet view
• Non‑iOS scanner view (if applicable)

CameraCaptureView.swift􀰓


//
//  CameraCaptureView.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

#if os(iOS)
/// SwiftUI wrapper for camera capture interface (iOS)
struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let onScanComplete: (ScanResult) async -> Void

    init(onScanComplete: @escaping (ScanResult) async -> Void) {
        self.onScanComplete = onScanComplete
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Camera Capture")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Camera functionality coming soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Close") {
                    Task {
                        // Create a mock ScanResult for now
                        let mockResult = ScanResult(
                            scannedPages: [],
                            extractedData: ExtractedData(),
                            processingMetadata: ProcessingMetadata(
                                processingTime: 0.0,
                                ocrEnabled: false,
                                compressionEnabled: false,
                                compressionQuality: 0.8,
                                imageProcessingSteps: []
                            )
                        )
                        await onScanComplete(mockResult)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // iOS-only placement
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("CameraCaptureView (iOS)") {
    CameraCaptureView { scanResult in
        print("Scan completed: \(scanResult)")
    }
}
#else
/// macOS stub to keep references compiling if accidentally used.
/// You can replace this with a real macOS implementation later if desired.
struct CameraCaptureView: View {
    let onScanComplete: (ScanResult) async -> Void

    init(onScanComplete: @escaping (ScanResult) async -> Void) {
        self.onScanComplete = onScanComplete
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Camera is not available on macOS")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview("CameraCaptureView (macOS)") {
    CameraCaptureView { _ in }
}
#endif




scannerview.swift

import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Receipt Scanner")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Scanner functionality coming soon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Scanner")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

#Preview {
    ScannerView()
}





⸻

7. UI Components used by ReceiptsView (full files)

7.1 <PATH>/StatusBadge.swift

StatusBadge.swift


MISSING


7.2 <PATH>/SectionHeader.swift

SectionHeader.swift

MISSING


7.3 <PATH>/CardStyle.swift (or the file that defines cardStyle modifier)

CardStyle.swift

MISSING


7.4 <PATH>/ScanButton.swift

ScanButton.swift􀰓

import SwiftUI

struct ScanButton: View {
    let isScanning: Bool
    let action: () -> Void
    
    init(isScanning: Bool, action: @escaping () -> Void) {
        self.isScanning = isScanning
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
            if isScanning {
                ProgressView()
                    .scaleEffect(0.8)
                        .tint(.white)
            } else {
                Image(systemName: "camera.fill")
                        .font(DesignSystem.Typography.title3)
            }
                
                Text(isScanning ? "Scanning..." : "Scan")
                    .font(DesignSystem.Typography.bodyEmphasized)
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [Color.ratioVitaPrimary, Color.ratioVitaSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadow(DesignSystem.Shadow.medium)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isScanning)
        .scaleEffect(isScanning ? 0.95 : 1.0)
        .animation(DesignSystem.Animation.spring, value: isScanning)
    }
}

// MARK: - Floating Scan Button

struct FloatingScanButton: View {
    let isScanning: Bool
    let action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button {
                    action()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.ratioVitaPrimary, Color.ratioVitaSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(DesignSystem.Shadow.large)
                        
                        if isScanning {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isScanning)
                .scaleEffect(isScanning ? 0.9 : 1.0)
                .animation(DesignSystem.Animation.spring, value: isScanning)
                
                Spacer()
            }
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }
}




7.5 Image bridge used by ReceiptsView
• Image(rvImage:) initializer and RVImage typealias

Image+RVImage.swift

import SwiftUI

#if canImport(UIKit)
import UIKit

typealias RVImage = UIImage
extension Image {
    init(rvImage: RVImage) { self.init(uiImage: rvImage) }
}

#elseif canImport(AppKit)
import AppKit

typealias RVImage = NSImage
extension Image {
    init(rvImage: RVImage) { self.init(nsImage: rvImage) }
}
#endif





7.6 <PATH>/CurrencyFormatter.swift

CurrencyFormatter.swift􀰓

import Foundation

/// Lightweight currency formatter utility for performance
final class CurrencyFormatter {
    static let shared = CurrencyFormatter()
    
    private var formatters: [String: NumberFormatter] = [:]
    private let queue = DispatchQueue(label: "com.ratiovita.currencyformatter", attributes: .concurrent)
    
    private init() {}
    
    func format(_ amount: Decimal, currencyCode: String) -> String {
        return queue.sync {
            if let formatter = formatters[currencyCode] {
                return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
            }
            
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currencyCode
            formatters[currencyCode] = formatter
            
            return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        }
    }
}




⸻

8. App configuration (full files)

8.1 RatioVita/RatioVita/Info.plist
• Confirm NSCameraUsageDescription exists (required if any camera API might run).
• Include any other relevant privacy keys in use.

{} Info


<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>RatioVita</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>RatioVita needs camera access to scan receipts and extract text from them.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>RatioVita needs photo library access to import receipt images from your photos.</string>
    <key>UIApplicationSupportsIndirectInputEvents</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>armv7</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
</dict>
</plist>





8.2 Package.swift􀰓 (if present)
• If you manage dependencies or targets that might affect runtime.

Package.swift􀰓


MISSING


⸻

9. Crash Logs (paste raw output)

1. Get simulator UDID:

{} Code Snippet

xcrun simctl list | grep -i "iPhone 15 Pro Max"


2. Show app logs for last 5 minutes (replace <SIM-UDID>):

{} Code Snippet


log show --style syslog --predicate 'process == "RatioVita"' --last 5m --info --debug --backtrace --signpost --color always --source



Paste output:

{} Code Snippet

iPhone 15 Pro Max (com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro-Max)
    iPhone 15 Pro Max iOS 18.5 (0A52D615-E9DC-42A6-99F3-6F603E11DE8E) (Booted) 
    iPhone 15 Pro Max (AC6E5B0E-01CA-486A-A8C0-F9331C6309CE) (Shutdown) 
    iPhone 15 Pro Max (9D971092-B47C-4CBE-8300-98C557D583E5) (Shutdown) 

getpwuid_r did not find a match for uid 501
Timestamp                       Thread     Type        Activity             PID    TTL


Optional: Xcode console output from launch to crash:
{} Code Snippet

MISSING


Optional: App bundle contents (sanity check):
{} Code Snippet


MISSING


⸻

10. Referenced helper modules/types (full files)
If any of the following are referenced by your code (especially RealScannerService), paste their full files.


