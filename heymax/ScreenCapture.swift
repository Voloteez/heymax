//
//  ScreenCapture.swift
//  heymax
//
//  Captures the current screen as a base64 JPEG for Claude to analyze.

import Cocoa
import ScreenCaptureKit

struct ScreenCapture {
    static func capture() async -> String? {
        // Check if we have permission first — avoids the popup on every rebuild
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                print("[ScreenCapture] No display found")
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            // Use half resolution for speed
            config.width = Int(display.width) / 2
            config.height = Int(display.height) / 2
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.3]) else {
                print("[ScreenCapture] Failed to encode JPEG")
                return nil
            }

            return jpeg.base64EncodedString()
        } catch {
            print("[ScreenCapture] Not authorized or capture failed: \(error)")
            return nil
        }
    }
}
