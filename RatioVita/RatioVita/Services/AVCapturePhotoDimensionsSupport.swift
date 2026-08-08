#if os(iOS) || os(visionOS) || os(macOS)
import AVFoundation

/// Keeps `AVCapturePhotoOutput.maxPhotoDimensions` aligned with the active video format.
enum AVCapturePhotoDimensionsSupport {
    /// Picks a supported still dimension (optionally capped by long edge) and assigns it to the photo output.
    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    @discardableResult
    static func syncPhotoOutputDimensions(
        photoOutput: AVCapturePhotoOutput,
        videoDevice: AVCaptureDevice,
        longEdgeCap: Int32? = nil
    ) -> CMVideoDimensions? {
        let supported = videoDevice.activeFormat.supportedMaxPhotoDimensions
        guard !supported.isEmpty else { return nil }

        let chosen = selectSupportedDimension(from: supported, longEdgeCap: longEdgeCap)
        photoOutput.maxPhotoDimensions = chosen
        return chosen
    }

    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    static func videoDevice(from session: AVCaptureSession) -> AVCaptureDevice? {
        session.inputs.compactMap { ($0 as? AVCaptureDeviceInput)?.device }.first
    }

    @available(iOS 16.0, macOS 13.0, visionOS 1.0, *)
    private static func selectSupportedDimension(
        from supported: [CMVideoDimensions],
        longEdgeCap: Int32?
    ) -> CMVideoDimensions {
        if let cap = longEdgeCap {
            let underCap = supported.filter { max($0.width, $0.height) <= cap }
            if let best = underCap.max(by: { pixelArea($0) < pixelArea($1) }) {
                return best
            }
            if let smallest = supported.min(by: { pixelArea($0) < pixelArea($1) }) {
                return smallest
            }
        }
        return supported.max(by: { pixelArea($0) < pixelArea($1) }) ?? supported[0]
    }

    private static func pixelArea(_ dim: CMVideoDimensions) -> Int {
        Int(dim.width) * Int(dim.height)
    }
}
#endif
