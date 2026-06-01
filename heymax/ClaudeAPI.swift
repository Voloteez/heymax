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
    case searchYouTube(String)
    case setVolume(Int)
    case typeText(String)
}

class ClaudeAPI {
    static let shared = ClaudeAPI()

    // TODO: Move to secure storage before shipping
    private let apiKey = "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"
    private let fastModel = "claude-haiku-4-5-20251001"
    private let smartModel = "claude-sonnet-4-20250514"
    private let endpoint = "https://api.anthropic.com/v1/messages"

    private let systemPrompt = """
    You are Max, a helpful AI assistant that lives on the user's Mac. You can see their screen and hear their voice commands.

    When the user asks you to DO something, respond with a JSON action block AND a short friendly response.

    Action format — include this JSON at the END of your response, on its own line:
    ###ACTION:{"type":"<type>","value":"<value>"}

    Available action types:
    - "open_url" — opens a URL in the default browser. Value: the full URL.
    - "open_app" — opens a macOS app by name. Value: app name (e.g. "Spotify", "Safari", "Discord").
    - "applescript" — runs an AppleScript command. Value: the script code. Use this for complex Mac automation.
    - "play_spotify" — searches a song/artist on Spotify. Value: search query.
    - "search_youtube" — plays/searches something on YouTube. Value: search query.
    - "set_volume" — sets system volume 0-100. Value: the number.
    - "type_text" — types text at the current cursor position. Value: the text to type.

    Examples:
    User: "play back in black on youtube"
    Response: Playing Back in Black on YouTube.
    ###ACTION:{"type":"search_youtube","value":"Back in Black AC/DC"}

    User: "play only you by keinemusik on spotify"
    Response: Searching Spotify for Only You by Keinemusik.
    ###ACTION:{"type":"play_spotify","value":"Only You Keinemusik"}

    User: "open my revenuecat dashboard"
    Response: Opening RevenueCat for you.
    ###ACTION:{"type":"open_url","value":"https://app.revenuecat.com"}

    User: "open youtube"
    Response: Opening YouTube.
    ###ACTION:{"type":"open_url","value":"https://youtube.com"}

    User: "open my github"
    Response: Opening GitHub.
    ###ACTION:{"type":"open_url","value":"https://github.com"}

    User: "set volume to 50"
    Response: Volume set to 50%.
    ###ACTION:{"type":"set_volume","value":"50"}

    User: "what's on my screen right now?"
    Response: [describe what you see in the screenshot]

    User: "put my mac to sleep"
    Response: Putting your Mac to sleep.
    ###ACTION:{"type":"applescript","value":"tell application \\"System Events\\" to sleep"}

    User: "toggle dark mode"
    Response: Toggling dark mode.
    ###ACTION:{"type":"applescript","value":"tell application \\"System Events\\" to tell appearance preferences to set dark mode to not dark mode"}

    Rules:
    - Be concise. 1-2 sentences max.
    - Be casual and friendly, like a buddy.
    - If you can't do something, say so honestly.
    - Only include ###ACTION if the user wants you to DO something.
    - If they're just asking a question, just answer it.
    - For music: if they say "on youtube" use search_youtube. If they say "on spotify" or just "play" use play_spotify.
    - For websites: use open_url with the correct URL. You know common dashboards (RevenueCat, Stripe, Vercel, GitHub, Notion, Figma, etc).
    - For complex Mac tasks: use applescript. You can control any app via AppleScript.
    """

    private let screenKeywords = ["screen", "see", "look", "looking at", "what's this", "what is this", "read", "showing", "display"]

    private func needsScreenshot(command: String) -> Bool {
        let lower = command.lowercased()
        return screenKeywords.contains(where: { lower.contains($0) })
    }

    func process(command: String, screenshot: String?) async -> ClaudeResponse {
        let useScreenshot = needsScreenshot(command: command)
        let model = useScreenshot ? smartModel : fastModel

        var content: [[String: Any]] = []

        if useScreenshot, let base64 = screenshot {
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
            "max_tokens": 256,
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
        request.timeoutInterval = 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArr = json["content"] as? [[String: Any]],
                  let firstBlock = contentArr.first,
                  let responseText = firstBlock["text"] as? String else {
                return ClaudeResponse(text: "Couldn't understand the response.", action: nil)
            }

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
        case "search_youtube": return .searchYouTube(value)
        case "set_volume": return .setVolume(Int(value) ?? 50)
        case "type_text": return .typeText(value)
        default: return nil
        }
    }
}
