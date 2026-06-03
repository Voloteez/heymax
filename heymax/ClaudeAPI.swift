//
//  ClaudeAPI.swift
//  heymax
//
//  Sends voice commands + optional screenshot to Claude for processing.
//  Supports conversation memory for follow-ups and a teaching mode.

import Foundation

struct ClaudeResponse {
    let text: String
    let action: AppAction?
    let isTeaching: Bool
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

    // Set your Claude API key: https://console.anthropic.com/
    private let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    private let fastModel = "claude-haiku-4-5-20251001"
    private let smartModel = "claude-sonnet-4-20250514"
    private let endpoint = "https://api.anthropic.com/v1/messages"

    // Conversation memory — keeps last 10 exchanges
    private var conversationHistory: [[String: Any]] = []
    private let maxHistory = 20 // 10 user + 10 assistant messages

    private let systemPrompt = """
    You are Max, a helpful AI assistant that lives on the user's Mac. You can see their screen and hear their voice commands.

    You have TWO modes:

    ## ACTION MODE (default)
    When the user asks you to DO something, respond with a short message + action JSON.

    Action format — include at the END, on its own line:
    ###ACTION:{"type":"<type>","value":"<value>"}

    Available actions:
    - "open_url" — opens a URL. Value: full URL.
    - "open_app" — opens an app. Value: app name.
    - "applescript" — runs AppleScript. Value: script code.
    - "play_spotify" — searches Spotify. Value: search query.
    - "search_youtube" — plays on YouTube. Value: search query.
    - "set_volume" — sets volume 0-100. Value: number.
    - "type_text" — types text at cursor. Value: the text.

    In action mode: be concise, 1-2 sentences max.

    ## TEACH MODE
    When the user asks you to teach, explain, learn, help understand, walk through, or asks "how does X work", "what is X", "explain X", "teach me X" — switch to teach mode.

    In teach mode:
    - Give clear, structured explanations
    - Use analogies and real-world examples
    - Break complex topics into digestible steps
    - If you can see their screen, reference what's on it specifically
    - Keep it conversational — like a smart friend explaining over their shoulder
    - Use short paragraphs, not walls of text
    - End with a follow-up prompt like "Want me to go deeper on any part?" or "Try it and ask me if you get stuck"
    - You can be 3-8 sentences in teach mode

    ## CONVERSATION
    You remember recent messages. The user can ask follow-ups like:
    - "wait, explain that again"
    - "what did you mean by that?"
    - "go deeper on the second point"
    - "actually, do the other thing"

    ## RULES
    - Be casual and friendly, like a buddy
    - If you can't do something, say so
    - Only include ###ACTION for actual actions, not teaching
    - For music: "on youtube" → search_youtube, "on spotify" or just "play" → play_spotify
    - For websites: use open_url. You know common dashboards (RevenueCat, Stripe, Vercel, GitHub, Notion, Figma, etc)
    - For Mac automation: use applescript
    """

    // Keywords that trigger teach mode
    private let teachKeywords = [
        "teach", "explain", "learn", "how does", "how do", "what is", "what are",
        "walk me through", "help me understand", "show me how", "tutorial",
        "why does", "why is", "tell me about", "break down", "guide me",
        "what's the difference", "how to", "can you explain", "i don't understand",
        "confused about", "help me with"
    ]

    // Keywords that need screenshot
    private let screenKeywords = [
        "screen", "see", "look", "looking at", "what's this", "what is this",
        "read", "showing", "display", "this code", "this file", "this page",
        "what's wrong", "debug this", "fix this"
    ]

    func isTeachingCommand(_ command: String) -> Bool {
        let lower = command.lowercased()
        return teachKeywords.contains(where: { lower.contains($0) })
    }

    func needsScreenshot(command: String) -> Bool {
        let lower = command.lowercased()
        let isTeaching = isTeachingCommand(command)
        let mentionsScreen = screenKeywords.contains(where: { lower.contains($0) })
        // Always capture screen in teach mode (context helps) or when explicitly asked
        return isTeaching || mentionsScreen
    }

    func process(command: String, screenshot: String?) async -> ClaudeResponse {
        let isTeaching = isTeachingCommand(command)
        let useScreenshot = screenshot != nil
        // Use smart model for teaching or screen analysis, fast model for actions
        let model = (isTeaching || useScreenshot) ? smartModel : fastModel
        let maxTokens = isTeaching ? 1024 : 256

        // Build current message content
        var currentContent: [[String: Any]] = []

        if let base64 = screenshot {
            currentContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }

        currentContent.append([
            "type": "text",
            "text": command
        ])

        // Build messages array with history
        var messages = conversationHistory
        messages.append(["role": "user", "content": currentContent])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": messages
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return ClaudeResponse(text: "Failed to build request.", action: nil, isTeaching: false)
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = isTeaching ? 30 : 15

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArr = json["content"] as? [[String: Any]],
                  let firstBlock = contentArr.first,
                  let responseText = firstBlock["text"] as? String else {
                return ClaudeResponse(text: "Couldn't understand the response.", action: nil, isTeaching: false)
            }

            let action = parseAction(from: responseText)
            let cleanText = responseText.components(separatedBy: "###ACTION:").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? responseText

            // Save to conversation history (without image data to save memory)
            conversationHistory.append(["role": "user", "content": command])
            conversationHistory.append(["role": "assistant", "content": responseText])

            // Trim history if too long
            while conversationHistory.count > maxHistory {
                conversationHistory.removeFirst(2)
            }

            return ClaudeResponse(text: cleanText, action: action, isTeaching: isTeaching)

        } catch {
            print("[ClaudeAPI] Error: \(error)")
            return ClaudeResponse(text: "Something went wrong: \(error.localizedDescription)", action: nil, isTeaching: false)
        }
    }

    func clearHistory() {
        conversationHistory.removeAll()
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
