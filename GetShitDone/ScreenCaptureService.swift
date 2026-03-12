import Foundation
import ScreenCaptureKit
import AppKit
import CoreGraphics

enum ScreenCaptureError: Error, LocalizedError {
    case noDisplay
    case captureFailed
    case conversionFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display found"
        case .captureFailed: return "Screenshot capture failed"
        case .conversionFailed: return "Failed to convert screenshot to image data"
        case .permissionDenied: return "Screen recording permission not granted"
        }
    }
}

final class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private init() {}

    /// Check if screen capture permission is granted
    var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request screen capture permission (opens System Settings if needed)
    @discardableResult
    func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Capture the display with the focused window and return JPEG data (no disk writes)
    func captureScreen() async throws -> Data {
        let cgImage: CGImage

        if #available(macOS 14.0, *) {
            cgImage = try await captureWithScreenshotManager()
        } else {
            cgImage = try await captureWithStream()
        }

        guard let jpegData = jpegData(from: cgImage, quality: 0.8) else {
            throw ScreenCaptureError.conversionFailed
        }

        return jpegData
    }

    /// Find the display containing the currently focused window
    private func activeDisplayID() -> CGDirectDisplayID {
        if let screen = NSScreen.main, let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            return id
        }
        return CGMainDisplayID()
    }

    // MARK: - macOS 14+ (SCScreenshotManager)

    @available(macOS 14.0, *)
    private func captureWithScreenshotManager() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let targetID = activeDisplayID()

        guard let display = content.displays.first(where: { $0.displayID == targetID }) ?? content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }

        // Exclude our own app from the screenshot
        let excludedApps = content.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        // Full resolution so the model can read file names, code, and tab titles
        config.width = display.width
        config.height = display.height
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    // MARK: - macOS 12.3-13 (SCStream fallback)

    private func captureWithStream() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let targetID = activeDisplayID()

        guard let display = content.displays.first(where: { $0.displayID == targetID }) ?? content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }

        let excludedApps = content.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.width = display.width
        config.height = display.height
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let capturer = StreamCapturer()
        return try await capturer.capture(filter: filter, configuration: config)
    }

    // MARK: - Image Conversion

    private func jpegData(from cgImage: CGImage, quality: CGFloat) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}

// MARK: - Stream-based Capturer (for macOS < 14)

private final class StreamCapturer: NSObject, SCStreamOutput {
    private var continuation: CheckedContinuation<CGImage, Error>?
    private var stream: SCStream?

    func capture(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            self.stream = stream
            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global())
                Task {
                    do {
                        try await stream.startCapture()
                    } catch {
                        self.continuation?.resume(throwing: error)
                        self.continuation = nil
                    }
                }
            } catch {
                continuation.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        Task { try? await stream.stopCapture() }

        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            continuation?.resume(throwing: ScreenCaptureError.captureFailed)
            continuation = nil
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        let rect = CGRect(
            x: 0, y: 0,
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        guard let cgImage = context.createCGImage(ciImage, from: rect) else {
            continuation?.resume(throwing: ScreenCaptureError.conversionFailed)
            continuation = nil
            return
        }

        continuation?.resume(returning: cgImage)
        continuation = nil
    }
}
