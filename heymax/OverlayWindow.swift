//
//  OverlayWindow.swift
//  heymax
//
//  Floating overlay that shows listening/thinking/response states.
//  Expands for teaching mode with scrollable content.

import SwiftUI
import Cocoa
import Combine

enum OverlayState {
    case listening
    case thinking
    case response(String)
}

class OverlayWindow: NSObject {
    static var shared: OverlayWindow?

    private var window: NSWindow?
    private let hostingView: NSHostingController<OverlayView>
    private let viewModel = OverlayViewModel()

    override init() {
        hostingView = NSHostingController(rootView: OverlayView(viewModel: viewModel))
        super.init()
        OverlayWindow.shared = self
        setupWindow()
    }

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        window.contentViewController = hostingView

        self.window = window
    }

    func show(state: OverlayState) {
        DispatchQueue.main.async {
            self.viewModel.state = state

            // Resize based on content
            let isTeaching: Bool
            switch state {
            case .response(let text):
                isTeaching = text.count > 200
            default:
                isTeaching = false
            }

            let width: CGFloat = isTeaching ? 480 : 380
            let height: CGFloat = isTeaching ? 360 : 120

            self.window?.setContentSize(NSSize(width: width, height: height))

            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - width / 2
                let y = screenFrame.maxY - height - 20
                self.window?.setFrameOrigin(NSPoint(x: x, y: y))
            }

            self.window?.orderFront(nil)

            self.window?.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                self.window?.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                self.window?.animator().alphaValue = 0
            }, completionHandler: {
                self.window?.orderOut(nil)
            })
        }
    }
}

// MARK: - View Model

class OverlayViewModel: ObservableObject {
    @Published var state: OverlayState = .listening
}

// MARK: - Overlay View

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    private var isLongResponse: Bool {
        if case .response(let text) = viewModel.state {
            return text.count > 200
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                statusIcon

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    if !isLongResponse {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(3)
                    }
                }

                Spacer()

                if isLongResponse {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, isLongResponse ? 8 : 14)

            // Scrollable body for long responses
            if isLongResponse {
                Divider()
                    .background(Color.white.opacity(0.1))

                ScrollView {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch viewModel.state {
        case .listening:
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 32, height: 32)
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        case .thinking:
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                ProgressView()
                    .scaleEffect(0.5)
                    .tint(.white)
            }
        case .response:
            ZStack {
                Circle()
                    .fill(isLongResponse ? Color.orange : Color.purple)
                    .frame(width: 32, height: 32)
                Image(systemName: isLongResponse ? "brain.head.profile" : "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var title: String {
        switch viewModel.state {
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .response:
            return isLongResponse ? "Max — Teaching" : "Max"
        }
    }

    private var subtitle: String {
        switch viewModel.state {
        case .listening: return "Say your command"
        case .thinking: return "Processing your request"
        case .response(let text): return text
        }
    }
}
