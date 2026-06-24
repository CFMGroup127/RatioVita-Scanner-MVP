import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(CryptoKit)
import CryptoKit
#endif

/// Strips GPS/device EXIF from set photos before anonymous proxy delivery.
enum SovereignAssetPrivacySanitizer {
    static func stripTrackingMetadata(from sourceURL: URL, destinationURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw SanitizeError.unreadableSource
        }
        guard let type = CGImageSourceGetType(source) else { throw SanitizeError.unreadableSource }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else { throw SanitizeError.emptySource }

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            type,
            count,
            nil
        ) else {
            throw SanitizeError.writeFailed
        }

        let stripKeys: [CFString] = [
            kCGImagePropertyGPSDictionary,
            kCGImagePropertyExifDictionary,
            kCGImagePropertyTIFFDictionary,
            kCGImagePropertyMakerAppleDictionary,
        ]

        for index in 0..<count {
            var props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
            for key in stripKeys {
                props.removeValue(forKey: key)
            }
            props[kCGImagePropertyOrientation] = 1
            CGImageDestinationAddImageFromSource(destination, source, index, props as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw SanitizeError.writeFailed
        }
    }

    static func anonymousProxyLink(for assetID: UUID, ownerSPID: String) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data("\(ownerSPID)|\(assetID.uuidString)".utf8))
        let token = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "https://share.ratiovita.local/v/\(token)"
        #else
        return "https://share.ratiovita.local/v/\(assetID.uuidString.lowercased())"
        #endif
    }

    enum SanitizeError: LocalizedError {
        case unreadableSource
        case emptySource
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .unreadableSource: return "Could not read the photo for privacy sanitization."
            case .emptySource: return "Photo contained no image data."
            case .writeFailed: return "Could not write sanitized photo."
            }
        }
    }
}
