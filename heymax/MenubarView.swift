//
//  MenubarView.swift
//  heymax
//
//  Popover UI shown when clicking the menubar icon.

import SwiftUI

struct MenubarView: View {
    @ObservedObject var voice = VoiceEngine.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hey Max")
                        .font(.system(size: 16, weight: .bold))
                    Text(voice.isListening ? "Listening for wake word..." : "Not listening")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Circle()
                    .fill(voice.isListening ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            .padding(16)

            Divider()

            // Toggle
            VStack(spacing: 12) {
                Button(action: {
                    if voice.isListening {
                        voice.stopListening()
                    } else {
                        voice.requestPermissions { granted in
                            if granted { voice.startListening() }
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: voice.isListening ? "mic.fill" : "mic.slash")
                        Text(voice.isListening ? "Stop Listening" : "Start Listening")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(voice.isListening ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.15))
                    .foregroundColor(voice.isListening ? .red : .accentColor)
                    .cornerRadius(8)
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)

                // Last command
                if !voice.lastTranscript.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LAST COMMAND")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(voice.lastTranscript)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                }

                // Status
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("Say \"Hey Max\" followed by your command")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)

            Divider()

            // Quit
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Hey Max")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 320)
    }
}
