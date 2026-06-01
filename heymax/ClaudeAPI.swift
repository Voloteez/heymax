//
//  ClaudeAPI.swift
//  heymax
//
//  Sends voice commands + optional screenshot to Claude for processing.
//  Returns a response with text and optional action to execute.

import Foundation

struct ClaudeResponse {
    let text: String
    let action: AppAction?
}

enum AppAction {
    case openURL(String)
    case openApp(String)
    case runAppleScript(String)
    case playSpotify(String)
    case setVolume(Int)
    case typeText(String)
}

class ClaudeAPI {
    static let shared = ClaudeAPI()

    // TODO: Move to secure storage before shipping
    private let apiKey = "YOUR_CLAUDE_API_KEY"
    private let model = "claude-sonnet-4-20250514"
    private let endpoint = "https://api.anthropic.com/v1/messages"

    private let systemPrompt = """
    You are Max, a helpful AI assistant that lives on the user's Mac. You can see their screen and hear their voice commands.

    When the user asks you to DO something (open an app, play music, etc.), respond with a JSON action block AND a short friendly response.

    Action format — include this JSON at the END of your response, on its own line:
    ###ACTION:{"type":"<type>","value":"<value>"}

    Available action types:
    - "open_url" — opens a URL in the browser. Value: the URL.
    - "open_app" — opens a macOS app. Value: app name (e.g. "Spotify", "Safari").
    - "applescript" — runs an AppleScript. Value: the script code.
    - "play_spotify" — plays a song/artist on Spotify. Value: search query.
    - "set_volume" — sets system volume. Value: 0-100.
    - "type_text" — types text at cursor. Value: the text.

    Examples:
    User: "play only you by keinemusik on spotify"
    Response: On it, playing Only You by Keinemusik.
    ###ACTION:{"type":"play_spotify","value":"Only You Keinemusik"}

    User: "open my revenuecat dashboard"
    Response: Opening RevenueCat for you.
    ###ACTION:{"type":"open_url","value":"https://app.revenuecat.com"}

    User: "what's on my screen right now?"
    Response: [describe what you see in the screenshot]

    User: "set volume to 50"
    Response: Volume set to 50%.
    ###ACTION:{"type":"set_volume","value":"50"}

    Rules:
    - Be concise. 1-2 sentences max.
    - Be casual and friendly, like a buddy.
    - If you can't do something, say so honestly.
    - Only include ###ACTION if the user wants you to DO something.
    - If they're just asking a question, just answer it.
    """

    func process(command: String, screenshot: String?) async -> ClaudeResponse {
        var content: [[String: Any]] = []

        // Add screenshot if available
        if let base64 = screenshot {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }

        content.append([
            "type": "text",
            "text": command
        ])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return ClaudeResponse(text: "Failed to build request.", action: nil)
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArr = json["content"] as? [[String: Any]],
                  let firstBlock = contentArr.first,
                  let responseText = firstBlock["text"] as? String else {
                return ClaudeResponse(text: "Couldn't understand the response.", action: nil)
            }

            // Parse action if present
            let action = parseAction(from: responseText)
            let cleanText = responseText.components(separatedBy: "###ACTION:").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? responseText

            return ClaudeResponse(text: cleanText, action: action)

        } catch {
            print("[ClaudeAPI] Error: \(error)")
            return ClaudeResponse(text: "Something went wrong: \(error.localizedDescription)", action: nil)
        }
    }

    private func parseAction(from text: String) -> AppAction? {
        guard let range = text.range(of: "###ACTION:") else { return nil }
        let jsonStr = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let type = json["type"],
              let value = json["value"] else {
            return nil
        }

        switch type {
        case "open_url": return .openURL(value)
        case "open_app": return .openApp(value)
        case "applescript": return .runAppleScript(value)
        case "play_spotify": return .playSpotify(value)
        case "set_volume": return .setVolume(Int(value) ?? 50)
        case "type_text": return .typeText(value)
        default: return nil
        }
    }
}
