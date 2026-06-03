# Hey Max 👋

**A voice-controlled AI assistant that lives in your Mac's menubar.**

Say "Hey Max" followed by any command — open apps, play music, control your Mac, ask questions, and more. Powered by Claude.

![macOS](https://img.shields.io/badge/macOS-15.0+-black?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?logo=swift&logoColor=white)
![Claude](https://img.shields.io/badge/Powered%20by-Claude-blueviolet)

---

## How it works

1. **Launch the app** — a waveform icon appears in your menubar
2. **Click it** and hit **Start Listening**
3. **Say "Hey Max"** — a floating overlay appears
4. **Say your command** — pause for 2 seconds
5. **Max responds** — executes the action and shows the result

No dock icon. No window. Just a menubar icon that's always ready.

---

## What can Max do?

### Open apps
> "Hey Max, open Spotify"
> "Hey Max, open Discord"
> "Hey Max, open Xcode"

### Open websites & dashboards
> "Hey Max, open YouTube"
> "Hey Max, open my RevenueCat dashboard"
> "Hey Max, open GitHub"
> "Hey Max, open Stripe"

### Play music
> "Hey Max, play Back in Black on YouTube"
> "Hey Max, search Thunderstruck on Spotify"

### Control your Mac
> "Hey Max, set volume to 40"
> "Hey Max, toggle dark mode"
> "Hey Max, put my Mac to sleep"

### Ask questions
> "Hey Max, what's 15% of 249?"
> "Hey Max, how do I center a div?"

### Analyze your screen
> "Hey Max, what's on my screen?"
> "Hey Max, read what's showing"

### Run AppleScript (anything)
Max can run any AppleScript command, which means it can control virtually any app on your Mac.

---

## Architecture

```
heymaxApp.swift       → Menubar-only app, no dock icon
VoiceEngine.swift     → Always-on mic, wake word detection, silence-based command capture
ClaudeAPI.swift       → Sends commands to Claude (Haiku for actions, Sonnet for vision)
ScreenCapture.swift   → ScreenCaptureKit-based screen capture (only when needed)
ActionRunner.swift    → Executes actions: open URLs, launch apps, AppleScript, volume, etc.
OverlayWindow.swift   → Floating overlay UI (listening → thinking → response)
MenubarView.swift     → Popover UI with start/stop and last command display
```

### Smart routing
- **Simple commands** (open app, play music, set volume) → Claude Haiku (fast)
- **Screen analysis** (what's on my screen?) → Claude Sonnet + screenshot (smart)
- **No screenshot** is captured unless you ask about your screen

---

## Setup

### 1. Clone
```bash
git clone https://github.com/Voloteez/heymax.git
cd heymax
```

### 2. Add your Claude API key
Get one at [console.anthropic.com](https://console.anthropic.com/)

In Xcode: **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**

Add: `ANTHROPIC_API_KEY` = `your-key-here`

### 3. Build & Run
Open `heymax.xcodeproj` in Xcode, hit **Cmd+R**.

### 4. Grant permissions
macOS will ask for:
- **Microphone** — for voice capture
- **Speech Recognition** — for speech-to-text
- **Screen Recording** — only needed for "what's on my screen" commands

---

## Tech Stack

- **SwiftUI** — menubar UI and floating overlay
- **Speech framework** — on-device speech recognition
- **ScreenCaptureKit** — screen capture for visual analysis
- **Claude API** — Haiku for speed, Sonnet for vision
- **AppleScript** — system automation (volume, dark mode, app control)

---

## Roadmap

- [ ] Conversation memory (remember context across commands)
- [ ] Custom wake word
- [ ] Keyboard shortcut trigger (in addition to voice)
- [ ] Plugin system for custom actions
- [ ] Spotify direct playback (via Spotify Web API)
- [ ] Persistent settings (auto-start, always listening)
- [ ] Menu bar animation while processing

---

## License

MIT — do whatever you want with it.

---

Built by [@maxim_drd](https://x.com/maxim_drd)
