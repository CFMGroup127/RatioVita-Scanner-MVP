import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum ImageProcessing {
    static func processImage(_ image: RVImage, with _: ProcessingOptions) async throws -> RVImage {
        // MVP stub: returns the original image without modification
        return image
    }
}
