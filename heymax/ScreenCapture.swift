//
//  ScreenCapture.swift
//  heymax
//
//  Captures the current screen as a base64 JPEG for Claude to analyze.

import Cocoa

struct ScreenCapture {
    static func capture() -> String? {
        // Use CGDisplayCreateImage (still available on macOS)
        let displayID = CGMainDisplayID()
        guard let screenshot = CGDisplayCreateImage(displayID) else {
            print("[ScreenCapture] Failed to capture screen")
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: screenshot)
        guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.4]) else {
            print("[ScreenCapture] Failed to encode JPEG")
            return nil
        }

        return jpeg.base64EncodedString()
    }
}
