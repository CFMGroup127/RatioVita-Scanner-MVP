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
