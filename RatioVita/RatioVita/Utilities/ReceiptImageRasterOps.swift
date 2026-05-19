import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Axis-aligned crop shared by **Region crop** and **Replace page** flows.
enum ReceiptImageRasterOps {
    /// `rect` is normalized in **top-left** origin (0…1) over the full raster.
    static func cropTopLeftNormalized(_ image: RVImage, rect: CGRect) -> RVImage? {
        guard let cgFull = image.rvCGImage else { return nil }
        guard let cropped = cropCore(cg: cgFull, rect: rect) else { return nil }
        #if canImport(UIKit)
        guard let uiBase = image as? UIImage else { return nil }
        return UIImage(cgImage: cropped, scale: uiBase.scale, orientation: .up) as RVImage
        #elseif canImport(AppKit)
        let sz = NSSize(width: cropped.width, height: cropped.height)
        return NSImage(cgImage: cropped, size: sz) as RVImage
        #else
        return nil
        #endif
    }

    private static func cropCore(cg: CGImage, rect: CGRect) -> CGImage? {
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let r = CGRect(
            x: rect.minX * w,
            y: rect.minY * h,
            width: rect.width * w,
            height: rect.height * h
        ).integral
        guard r.width >= 8, r.height >= 8 else { return nil }
        return cg.cropping(to: r)
    }
}
