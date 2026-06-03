//
//  SpeechOutput.swift
//  heymax
//
//  Text-to-speech so Max can talk back. Uses macOS built-in voices.

import AVFoundation
import Combine

class SpeechOutput: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechOutput()

    @Published var isSpeaking = false
    @Published var isEnabled = true

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard isEnabled else { return }

        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9

        // Try to use a premium voice if available
        let preferredVoices = ["com.apple.voice.premium.en-US.Zoe",
                               "com.apple.voice.enhanced.en-US.Zoe",
                               "com.apple.voice.premium.en-US.Ava",
                               "com.apple.voice.enhanced.en-US.Ava",
                               "com.apple.voice.enhanced.en-US.Samantha"]
        for voiceID in preferredVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
                utterance.voice = voice
                break
            }
        }

        isSpeaking = true
        synthesizer.speak(utterance)
        print("[Speech] Speaking: \(text.prefix(50))...")
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    func toggle() {
        isEnabled.toggle()
        if !isEnabled { stop() }
    }

    // MARK: - Delegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
