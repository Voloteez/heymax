//
//  ActionRunner.swift
//  heymax
//
//  Executes actions returned by Claude — open URLs, launch apps,
//  run AppleScript, control Spotify, set volume.

import Cocoa

struct ActionRunner {
    static func run(_ action: AppAction) {
        switch action {
        case .openURL(let url):
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
                print("[Action] Opened URL: \(url)")
            }

        case .openApp(let name):
            let config = NSWorkspace.OpenConfiguration()
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID(for: name)) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                print("[Action] Opened app: \(name)")
            } else {
                NSWorkspace.shared.launchApplication(name)
                print("[Action] Launched app by name: \(name)")
            }

        case .runAppleScript(let script):
            DispatchQueue.global().async {
                let proc = Process()
                proc.launchPath = "/usr/bin/osascript"
                proc.arguments = ["-e", script]
                proc.launch()
                proc.waitUntilExit()
                print("[Action] Ran AppleScript")
            }

        case .playSpotify(let query):
            // Use Spotify URI to open directly in the app
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            if let uri = URL(string: "spotify:search:\(encoded)") {
                NSWorkspace.shared.open(uri)
            }
            // Give Spotify a moment to load, then hit play
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let script = """
                tell application "Spotify"
                    activate
                    play
                end tell
                """
                let proc = Process()
                proc.launchPath = "/usr/bin/osascript"
                proc.arguments = ["-e", script]
                try? proc.run()
            }
            print("[Action] Playing on Spotify: \(query)")

        case .setVolume(let level):
            let clamped = max(0, min(100, level))
            let script = "set volume output volume \(clamped)"
            let proc = Process()
            proc.launchPath = "/usr/bin/osascript"
            proc.arguments = ["-e", script]
            try? proc.run()
            print("[Action] Set volume to \(clamped)%")

        case .typeText(let text):
            let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            tell application "System Events"
                keystroke "\(escaped)"
            end tell
            """
            let proc = Process()
            proc.launchPath = "/usr/bin/osascript"
            proc.arguments = ["-e", script]
            try? proc.run()
            print("[Action] Typed text")
        }
    }

    // MARK: - Bundle ID Lookup

    private static func bundleID(for appName: String) -> String {
        let map: [String: String] = [
            "safari": "com.apple.Safari",
            "spotify": "com.spotify.client",
            "chrome": "com.google.Chrome",
            "slack": "com.tinyspeck.slackmacgap",
            "discord": "com.hnc.Discord",
            "notion": "notion.id",
            "figma": "com.figma.Desktop",
            "terminal": "com.apple.Terminal",
            "xcode": "com.apple.dt.Xcode",
            "finder": "com.apple.finder",
            "messages": "com.apple.MobileSMS",
            "notes": "com.apple.Notes",
            "calendar": "com.apple.iCal",
            "music": "com.apple.Music",
            "mail": "com.apple.mail",
            "vscode": "com.microsoft.VSCode",
        ]
        return map[appName.lowercased()] ?? "com.apple.\(appName)"
    }
}
