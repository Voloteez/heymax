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
            // Open search in Spotify app
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let proc = Process()
            proc.launchPath = "/usr/bin/open"
            proc.arguments = ["-a", "Spotify", "spotify:search:\(encoded)"]
            try? proc.run()
            print("[Action] Opened Spotify search: \(query)")

        case .searchYouTube(let query):
            Task {
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
                // Fetch YouTube search page and extract first video ID
                if let videoID = await Self.getFirstYouTubeVideoID(query: encoded) {
                    let watchURL = "https://www.youtube.com/watch?v=\(videoID)"
                    if let url = URL(string: watchURL) {
                        NSWorkspace.shared.open(url)
                        print("[Action] Playing YouTube video: \(watchURL)")
                    }
                } else {
                    // Fallback: just open search
                    if let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") {
                        NSWorkspace.shared.open(url)
                        print("[Action] Fallback: YouTube search")
                    }
                }
            }

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

    // MARK: - YouTube Video ID Extraction

    private static func getFirstYouTubeVideoID(query: String) async -> String? {
        guard let url = URL(string: "https://www.youtube.com/results?search_query=\(query)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // YouTube embeds video IDs in the page as "videoId":"XXXXXXXXXXX"
            if let range = html.range(of: "\"videoId\":\"") {
                let after = html[range.upperBound...]
                if let endRange = after.range(of: "\"") {
                    let videoID = String(after[..<endRange.lowerBound])
                    if videoID.count == 11 {
                        print("[YouTube] Found video ID: \(videoID)")
                        return videoID
                    }
                }
            }
        } catch {
            print("[YouTube] Fetch error: \(error)")
        }
        return nil
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
