import Foundation

#if canImport(PDFKit)
import PDFKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Optional saved crew initials image stamped into the EP **CREW** approval box.
enum CrewInitialsStampHelper {
    private static let imageDataKey = "com.ratiovita.crewInitialsImagePNG"
    private static let useImageKey = "com.ratiovita.crewInitialsUseImage"

    static var useImageInitials: Bool {
        get { UserDefaults.standard.bool(forKey: useImageKey) }
        set { UserDefaults.standard.set(newValue, forKey: useImageKey) }
    }

    static var savedImagePNGData: Data? {
        get { UserDefaults.standard.data(forKey: imageDataKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: imageDataKey)
            } else {
                UserDefaults.standard.removeObject(forKey: imageDataKey)
            }
        }
    }

    #if canImport(PDFKit)
    static func stampImageInitialsIfNeeded(on page: PDFPage, fieldName: String) {
        // macOS PDFKit does not expose annotation.image; typed initials cover the CREW field for now.
        // Saved PNG is retained for a future appearance-stream stamp pass.
        guard useImageInitials, savedImagePNGData != nil else { return }
        _ = page.annotations.first(where: { $0.fieldName == fieldName })
    }
    #endif
}
