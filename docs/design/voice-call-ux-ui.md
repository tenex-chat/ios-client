# Voice Call UX/UI Design Specification

**Date:** 2025-12-15
**Feature:** Voice Activity Detection, Call Settings, UI States
**Status:** Design Complete

---

## Table of Contents

1. [Visual States](#1-visual-states)
2. [Animation Specifications](#2-animation-specifications)
3. [Color Palette and Visual Language](#3-color-palette-and-visual-language)
4. [Haptic Feedback Map](#4-haptic-feedback-map)
5. [Tap-to-Hold Interaction](#5-tap-to-hold-interaction)
6. [CallSettingsView Layout](#6-callsettingsview-layout)
7. [VoiceCallSettingsView Layout](#7-voicecallsettingsview-layout)
8. [Accessibility Guidelines](#8-accessibility-guidelines)
9. [SwiftUI Implementation Notes](#9-swiftui-implementation-notes)

---

## 1. Visual States

### 1.1 State Machine Overview

```
                    +------------------+
                    |      Idle        |
                    | (Ready to speak) |
                    +--------+---------+
                             |
            +----------------+----------------+
            |                                 |
            v                                 v
+-------------------+              +--------------------+
|   VAD Listening   |              |  Manual Recording  |
| (Auto-detecting)  |              |   (Tap-to-talk)    |
+--------+----------+              +---------+----------+
         |                                   |
         | Speech detected                   | User tapping
         v                                   v
+-------------------+              +--------------------+
|    Recording      |<----------->|     Tap-Held       |
| (Speech active)   |   Override  | (User holding mic) |
+--------+----------+              +--------------------+
         |
         | Speech ends / User releases
         v
+-------------------+
|  Processing STT   |
| (Transcribing)    |
+--------+----------+
         |
         v
+-------------------+
| Waiting for Agent |
| (Message sent)    |
+--------+----------+
         |
         v
+-------------------+
|   Playing TTS     |
| (Agent speaking)  |
+--------+----------+
         |
         v
      [Idle]
```

### 1.2 Detailed State Descriptions

#### State: Idle (Ready to Speak)

**Purpose:** Default resting state when call is active but no activity is occurring.

**Visual Treatment:**
- Mic button: Project accent color fill, white mic icon
- Orb visualizer: Subtle glow (20% opacity), no pulsing rings
- Status text: "Tap to speak" or "Start speaking" (VAD mode)
- Status indicator: Gray circle (neutral)

**Visual Specs:**
```
Mic Button:
  - Size: 70pt diameter
  - Fill: projectColor (e.g., blue)
  - Icon: SF Symbol "mic.fill", 28pt, white
  - Shadow: projectColor at 30% opacity, 8pt blur, 2pt y-offset

Orb Visualizer:
  - Core: projectColor at 70% brightness
  - Glow: 10pt radius, projectColor at 15% opacity
  - Scale: 1.0 (no scaling)
```

---

#### State: VAD Listening (Auto-Detecting Speech)

**Purpose:** VAD is active and listening for speech onset. User sees the system is "ready" to detect their voice.

**Visual Treatment:**
- Mic button: Subtle green tint ring around base
- Orb visualizer: Slow pulsing glow (breathing effect)
- Status text: "Listening..." with animated ellipsis
- Status indicator: Green pulse dot
- Pulsing ring: Expanding/fading concentric rings

**Visual Specs:**
```
VAD Indicator Ring:
  - Position: Around mic button, 4pt offset
  - Stroke: 2pt, green (systemGreen) at 50% opacity
  - Animation: Slow pulse scale 1.0 -> 1.05, 2s duration

Pulsing Rings (3 rings):
  - Ring 1: size + 30pt offset, 15% opacity
  - Ring 2: size + 60pt offset, 10% opacity
  - Ring 3: size + 90pt offset, 5% opacity
  - Animation: Scale 0.8 -> 1.2, opacity 30% -> 0%, 2s duration, staggered 0.5s

Status Dot:
  - Size: 8pt
  - Color: systemGreen
  - Animation: Opacity 0.6 -> 1.0, 1s ease-in-out, repeat
```

---

#### State: Recording (Speech Detected or Manual)

**Purpose:** Actively capturing user speech. Clear visual feedback that "you're being heard."

**Visual Treatment:**
- Mic button: Red fill with white stop icon (square), audio level ring
- Orb visualizer: Reactive to audio level, bright and scaled up
- Status text: "Recording" with red dot
- Audio level ring: Expanding ring synced to audio amplitude
- Glow intensifies with voice volume

**Visual Specs:**
```
Mic Button (Recording):
  - Fill: systemRed
  - Icon: Rounded square (stop icon), 24pt, white
  - Shadow: red at 50% opacity, 10pt blur

Audio Level Ring:
  - Position: Around mic button
  - Base size: 70pt + (audioLevel * 20pt) // 0.0-1.0 range
  - Stroke: 3pt, red at 30% opacity
  - Animation: 50ms duration (responsive to audio)

Orb Visualizer:
  - Scale: 1.0 + (audioLevel * 0.3)
  - Core brightness: 1.0 + (audioLevel * 0.2)
  - Glow radius: 20pt + (audioLevel * 30pt)
  - Transition: 50ms ease-out (smooth but responsive)

Status Display:
  - Red recording dot: 8pt, pulsing
  - Text: "Recording" in white
```

---

#### State: Tap-Held (User Holding Mic Open)

**Purpose:** User is deliberately keeping mic open (thinking while speaking). VAD auto-stop is disabled.

**Visual Treatment:**
- Mic button: Orange/amber fill (distinct from red recording)
- Hold indicator: Ring with "hold" icon or timer appearance
- Status text: "Hold to continue..." or elapsed time
- Hint overlay: "Release when done" near bottom
- Orb visualizer: Same as recording but with amber tint

**Visual Specs:**
```
Mic Button (Held):
  - Fill: Gradient from systemOrange to projectColor
  - Icon: "mic.fill" with subtle hand/grip overlay indicator
  - Ring: Double-stroke ring (inner solid, outer dashed)

Hold Indicator:
  - Inner ring: 2pt solid, orange
  - Outer ring: 2pt dashed, orange at 50%
  - Animation: Outer ring rotates slowly (10s per rotation)

Hold Hint (appears after 0.5s hold):
  - Position: Below controls, 16pt from bottom safe area
  - Background: Black at 60% opacity, 12pt corner radius
  - Text: "Release when done" in caption size, white
  - Animation: Fade in over 200ms
```

---

#### State: Processing STT

**Purpose:** Audio captured, now transcribing. User knows processing is happening.

**Visual Treatment:**
- Mic button: Disabled appearance (grayed projectColor)
- Processing indicator: Circular progress or pulsing waveform icon
- Status text: "Processing..." with optional transcript preview
- Orb visualizer: Subtle rotation animation (processing metaphor)

**Visual Specs:**
```
Mic Button (Processing):
  - Fill: projectColor at 40% opacity
  - Icon: SF Symbol "waveform" animated, or ProgressView
  - Interaction: Disabled (no tap response)

Processing Animation:
  - Option A: ProgressView(style: .circular), white tint
  - Option B: Waveform bars animating (like Siri)
  - Duration: Indefinite until complete

Transcript Preview:
  - Position: Above controls
  - Background: white at 15% opacity, 12pt radius
  - Text: Partial transcript in body font, white
  - Animation: Text appears word-by-word or fades in
```

---

#### State: Playing TTS (Agent Speaking)

**Purpose:** Agent response is being spoken. User knows to listen and can interrupt.

**Visual Treatment:**
- Mic button: Blue/projectColor with speaker icon
- Orb visualizer: Pulsing in sync with TTS audio
- Status text: "Speaking..." with agent name
- Interrupt hint: "Tap to interrupt" visible
- Agent avatar: Glowing ring to indicate active speaker

**Visual Specs:**
```
Mic Button (TTS Playing):
  - Fill: projectColor (or blue variant)
  - Icon: SF Symbol "speaker.wave.3.fill"
  - Animation: Waves animate left-to-right

Agent Avatar Ring:
  - Position: Around avatar in header
  - Stroke: 3pt, projectColor
  - Animation: Pulse scale 1.0 -> 1.08, 1s ease-in-out

Orb Visualizer:
  - Behavior: React to TTS audio level (if available)
  - Fallback: Gentle pulse animation if no level data
  - Color: projectColor with blue shift

Interrupt Hint:
  - Position: Below mic button
  - Text: "Tap to stop", caption, white at 70%
  - Visibility: After 1s of playback
```

---

#### State: Error

**Purpose:** Something went wrong. Clear communication without being alarming.

**Visual Treatment:**
- Error banner: Slides up from bottom with message
- Mic button: Normal state (allows retry)
- Icon: Warning triangle with brief message
- Auto-dismiss: After 4 seconds or on tap

**Visual Specs:**
```
Error Banner:
  - Position: Above controls, full width with padding
  - Background: systemRed at 30% opacity, 8pt radius
  - Icon: SF Symbol "exclamationmark.triangle.fill", yellow
  - Text: Error message in caption, white
  - Animation: Slide up from bottom, 300ms spring
  - Dismiss: Slide down after 4s or on tap

Haptic: .notificationError on appearance
```

---

## 2. Animation Specifications

### 2.1 Core Animation Parameters

| Animation | Duration | Easing | Notes |
|-----------|----------|--------|-------|
| Audio level response | 50ms | easeOut | Fast response to voice |
| State transitions | 300ms | spring(response: 0.5, dampingFraction: 0.8) | Snappy but not jarring |
| Pulsing rings | 2000ms | easeInOut | Breathing feel |
| Error slide | 300ms | spring(response: 0.5, dampingFraction: 0.7) | Attention-getting |
| Hold hint fade | 200ms | easeIn | Subtle appearance |
| Processing spin | Continuous | linear | Steady progress feel |

### 2.2 Pulsing Ring Animation (VAD Listening)

```swift
// SwiftUI Implementation
struct PulsingRing: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.3
    let delay: Double
    let color: Color

    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 2)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    scale = 1.2
                    opacity = 0
                }
            }
    }
}

// Usage: 3 rings with staggered delays
ZStack {
    PulsingRing(delay: 0.0, color: projectColor)
    PulsingRing(delay: 0.5, color: projectColor)
    PulsingRing(delay: 1.0, color: projectColor)
}
```

### 2.3 Audio Level Visualization

```swift
// Smooth audio level for animations
struct AudioLevelAnimator {
    // Use withAnimation for smooth transitions
    func updateLevel(_ newLevel: Double) {
        withAnimation(.easeOut(duration: 0.05)) {
            audioLevel = newLevel
        }
    }
}

// Orb scaling based on audio
var orbScale: CGFloat {
    1.0 + (audioLevel * 0.3)
}

var glowRadius: CGFloat {
    20 + (audioLevel * 30)
}
```

### 2.4 State Transition Animations

```swift
// Mic button fill transition
.animation(.spring(response: 0.4, dampingFraction: 0.8), value: state)

// Icon transition (crossfade)
.transition(.opacity.combined(with: .scale(scale: 0.8)))

// Status text transition
.transition(.move(edge: .bottom).combined(with: .opacity))
```

---

## 3. Color Palette and Visual Language

### 3.1 Semantic Colors

| Purpose | Light Mode | Dark Mode | SwiftUI |
|---------|------------|-----------|---------|
| Primary Action | Project Color | Project Color | projectColor |
| Recording | #EF4444 | #EF4444 | .systemRed |
| VAD Active | #22C55E | #22C55E | .systemGreen |
| Tap-Held | #F59E0B | #F59E0B | .systemOrange |
| Processing | Project @ 40% | Project @ 40% | projectColor.opacity(0.4) |
| Error | #EF4444 @ 30% | #EF4444 @ 30% | .systemRed.opacity(0.3) |
| TTS Playing | #3B82F6 | #3B82F6 | .systemBlue |
| Neutral | #6B7280 | #9CA3AF | .secondary |

### 3.2 Background Treatment

```swift
// Call view gradient background
LinearGradient(
    colors: [
        Color.black,
        projectColor.opacity(0.3),
        Color.black
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
.ignoresSafeArea()
```

### 3.3 Visual Hierarchy

1. **Primary Focus:** Mic button and orb visualizer (center)
2. **Secondary:** Status text and transcript display
3. **Tertiary:** Header (agent info, end call)
4. **Ambient:** Background gradient, pulsing rings

---

## 4. Haptic Feedback Map

### 4.1 Haptic Events

| Event | Haptic Type | SwiftUI | Notes |
|-------|-------------|---------|-------|
| VAD detects speech start | Light Impact | `.impactOccurred(intensity: 0.5)` | Subtle acknowledgment |
| Manual recording start | Medium Impact | `.impactOccurred()` | Confirm action |
| Manual recording stop | Light Impact | `.impactOccurred(intensity: 0.6)` | Acknowledge |
| Tap-hold begins | Soft Impact | `.impactOccurred(intensity: 0.4)` | Entry feedback |
| Tap-hold release | Light Impact | `.impactOccurred(intensity: 0.5)` | Exit feedback |
| Message sent | Success Notification | `.notificationOccurred(.success)` | Positive confirmation |
| Error occurs | Error Notification | `.notificationOccurred(.error)` | Alert user |
| TTS starts playing | Selection | `.selectionChanged()` | Subtle start cue |
| TTS interrupted | Light Impact | `.impactOccurred(intensity: 0.4)` | Acknowledge interrupt |
| Settings toggle | Selection | `.selectionChanged()` | Standard toggle feel |

### 4.2 Implementation Pattern

```swift
// Haptic generator setup
@MainActor
final class HapticManager {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }

    func vadSpeechDetected() {
        lightImpact.impactOccurred(intensity: 0.5)
    }

    func recordingStarted() {
        mediumImpact.impactOccurred()
    }

    func error() {
        notification.notificationOccurred(.error)
    }

    func messageSent() {
        notification.notificationOccurred(.success)
    }
}
```

---

## 5. Tap-to-Hold Interaction

### 5.1 Gesture Design

**Goal:** Allow users to keep the microphone open while thinking/speaking, overriding VAD auto-stop.

**Trigger:** Long press (0.3s) on mic button or anywhere in main content area.

**Behavior:**
1. User taps and holds -> Immediate recording start (if not already recording)
2. After 0.5s hold, "Release when done" hint appears
3. VAD auto-stop is paused while holding
4. On release:
   - If speech was detected: Process STT
   - If no speech: Return to listening (no error)

### 5.2 Visual Feedback Timeline

```
0.0s  - Touch down
       -> Mic button scales to 0.95 (pressed feel)
       -> Haptic: Light impact

0.3s  - Long press recognized
       -> Start recording (if idle/VAD listening)
       -> Mic button transitions to held state (amber)
       -> Haptic: Soft impact

0.5s  - Hold hint appears
       -> "Release when done" text fades in
       -> Outer dashed ring starts rotating

Hold  - Continued
       -> Audio level visualization active
       -> VAD auto-stop disabled

Release - Touch up
       -> Haptic: Light impact
       -> Hide hold hint
       -> If recording: Stop and process STT
       -> Return to normal state flow
```

### 5.3 SwiftUI Gesture Implementation

```swift
// Combined tap and long press gesture
.simultaneousGesture(
    LongPressGesture(minimumDuration: 0.3)
        .onChanged { _ in
            // Pressed state
            isPressed = true
        }
        .sequenced(before:
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    // Release
                    viewModel.stopHoldingMic()
                    isPressed = false
                }
        )
        .onEnded { _ in
            // Long press recognized
            viewModel.startHoldingMic()
        }
)
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.easeOut(duration: 0.1), value: isPressed)
```

### 5.4 Hold Hint Component

```swift
struct HoldHint: View {
    let isVisible: Bool

    var body: some View {
        Text("Release when done")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .clipShape(Capsule())
            .opacity(isVisible ? 1 : 0)
            .animation(.easeIn(duration: 0.2), value: isVisible)
    }
}
```

---

## 6. CallSettingsView Layout (In-Call Overlay)

### 6.1 Purpose

Quick access to essential settings without leaving the call. Non-modal, overlays bottom of screen.

### 6.2 Layout Specification

```
+------------------------------------------+
|         [Drag handle indicator]          |  <- Pill shape, 36x5pt
+------------------------------------------+
|                                          |
|  Quick Settings                          |  <- Section header
|                                          |
|  +------------------------------------+  |
|  |  VAD Mode                   [Auto] |  |  <- Picker/Segmented
|  +------------------------------------+  |
|  |  Auto-TTS        [Toggle: ON/OFF]  |  |  <- Toggle
|  +------------------------------------+  |
|  |  Mute Mic        [Toggle: ON/OFF]  |  |  <- Toggle
|  +------------------------------------+  |
|                                          |
|  [Advanced Settings >]                   |  <- Link to full settings
|                                          |
+------------------------------------------+
```

### 6.3 Component Specs

```swift
// Sheet presentation
.sheet(isPresented: $showingCallSettings) {
    CallSettingsView(viewModel: callViewModel)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
}
```

**Measurements:**
- Sheet height: 280pt (compact)
- Padding: 20pt horizontal, 16pt vertical
- Row height: 44pt (standard touch target)
- Corner radius: 16pt (top corners only)

### 6.4 CallSettingsView SwiftUI Structure

```swift
struct CallSettingsView: View {
    @Bindable var viewModel: CallViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Settings") {
                    // VAD Mode Picker
                    Picker("Voice Detection", selection: $viewModel.vadMode) {
                        Text("Manual").tag(VADMode.pushToTalk)
                        Text("Auto").tag(VADMode.auto)
                        Text("Auto + Hold").tag(VADMode.autoWithHold)
                    }
                    .pickerStyle(.segmented)

                    // Auto-TTS Toggle
                    Toggle("Auto-speak Responses", isOn: $viewModel.autoTTS)

                    // Mute Toggle (if applicable)
                    Toggle("Mute Microphone", isOn: $viewModel.isMuted)
                }

                Section {
                    NavigationLink("Advanced Settings") {
                        VoiceCallSettingsView()
                    }
                }
            }
            .navigationTitle("Call Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
```

---

## 7. VoiceCallSettingsView Layout (Settings Menu)

### 7.1 Purpose

Comprehensive voice call configuration accessible from main Settings menu.

### 7.2 Information Architecture

```
Voice Call Settings
|
+-- Voice Detection
|   +-- Mode (Disabled / Push-to-Talk / Auto / Auto + Hold)
|   +-- Sensitivity (Slider 0-100%)
|
+-- Audio Processing
|   +-- Noise Suppression (Toggle)
|   +-- Echo Cancellation (Toggle)
|   +-- Auto Gain Control (Toggle)
|
+-- Input Device
|   +-- Device Picker (if multiple available)
|
+-- Call Behavior
|   +-- Auto-speak Responses (Toggle)
|   +-- Record Calls (VOD) (Toggle)
|   +-- Call Recording Retention (Picker: 7/14/30 days)
```

### 7.3 Full Layout

```swift
struct VoiceCallSettingsView: View {
    @State private var settings: VoiceCallSettings

    var body: some View {
        Form {
            // SECTION: Voice Detection
            Section {
                Picker("Detection Mode", selection: $settings.vadMode) {
                    ForEach(VADMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                if settings.vadMode == .auto || settings.vadMode == .autoWithHold {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sensitivity")
                        Slider(value: $settings.vadSensitivity, in: 0...1)
                        HStack {
                            Text("Low").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(settings.vadSensitivity * 100))%")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("High").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Voice Detection")
            } footer: {
                Text("Auto mode detects when you start and stop speaking. Use 'Auto + Hold' to override with tap-and-hold.")
            }

            // SECTION: Audio Processing
            Section("Audio Processing") {
                Toggle("Noise Suppression", isOn: $settings.noiseSuppression)
                Toggle("Echo Cancellation", isOn: $settings.echoCancellation)
                Toggle("Auto Gain Control", isOn: $settings.autoGainControl)
            }

            // SECTION: Input Device (conditional)
            if availableInputDevices.count > 1 {
                Section("Input Device") {
                    Picker("Microphone", selection: $settings.preferredInputDevice) {
                        Text("Default").tag(nil as String?)
                        ForEach(availableInputDevices, id: \.uid) { device in
                            Text(device.name).tag(device.uid as String?)
                        }
                    }
                }
            }

            // SECTION: Call Behavior
            Section {
                Toggle("Auto-speak Responses", isOn: $settings.autoTTS)
                Toggle("Record Calls", isOn: $settings.enableVOD)
            } header: {
                Text("Call Behavior")
            } footer: {
                if settings.enableVOD {
                    Text("Call recordings are stored locally for 30 days.")
                }
            }
        }
        .navigationTitle("Voice Call")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

### 7.4 VADMode Display Names

```swift
extension VADMode {
    var displayName: String {
        switch self {
        case .disabled:
            "Disabled"
        case .pushToTalk:
            "Push-to-Talk"
        case .auto:
            "Auto-Detect"
        case .autoWithHold:
            "Auto + Hold Override"
        }
    }

    var description: String {
        switch self {
        case .disabled:
            "Manually control recording with the mic button"
        case .pushToTalk:
            "Tap to start recording, tap again to stop"
        case .auto:
            "Automatically detects when you speak"
        case .autoWithHold:
            "Auto-detect with tap-and-hold to keep mic open"
        }
    }
}
```

---

## 8. Accessibility Guidelines

### 8.1 VoiceOver Labels

| Element | Label | Hint | Value (if applicable) |
|---------|-------|------|----------------------|
| Mic button (idle) | "Microphone" | "Tap to start recording" | - |
| Mic button (recording) | "Recording" | "Tap to stop recording" | - |
| Mic button (VAD listening) | "Listening for speech" | "Speak to record, or tap to pause" | - |
| Mic button (held) | "Holding microphone open" | "Release to stop recording" | - |
| End call button | "End call" | "Double tap to end the call" | - |
| Auto-TTS toggle | "Auto-speak responses" | - | "On" / "Off" |
| VAD mode picker | "Voice detection mode" | - | Current mode name |
| Orb visualizer | "Audio visualization" | - | - |
| Status text | Dynamic based on state | - | - |

### 8.2 State Announcements

```swift
// Announce state changes to VoiceOver
func announceState(_ state: CallState) {
    let message: String
    switch state {
    case .idle:
        message = "Ready to record"
    case .recording:
        message = "Recording"
    case .processingSTT:
        message = "Processing your speech"
    case .waitingForAgent:
        message = "Waiting for response"
    case .playingResponse:
        message = "Agent is speaking"
    // ...
    }

    UIAccessibility.post(notification: .announcement, argument: message)
}
```

### 8.3 Dynamic Type Support

```swift
// Use system text styles that scale
Text("Recording")
    .font(.body)  // Scales with Dynamic Type

Text("Tap to speak")
    .font(.caption)  // Scales appropriately

// Minimum touch targets
Button { ... }
    .frame(minWidth: 44, minHeight: 44)  // WCAG minimum
```

### 8.4 Reduce Motion Support

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// Conditional animations
var pulsingAnimation: Animation? {
    reduceMotion ? nil : .easeInOut(duration: 2.0).repeatForever()
}

// Alternative for pulsing: use opacity change instead of scale
var vadIndicator: some View {
    Circle()
        .fill(reduceMotion
            ? Color.green.opacity(0.5)  // Static appearance
            : Color.green.opacity(pulseOpacity)  // Animated
        )
}
```

### 8.5 Color Contrast Requirements

| Element | Foreground | Background | Contrast Ratio |
|---------|------------|------------|----------------|
| Status text | White | Black gradient | >7:1 (AAA) |
| Error message | White | Red @ 30% on dark | >4.5:1 (AA) |
| Hint text | White @ 70% | Black @ 60% | >4.5:1 (AA) |
| Recording indicator | Red | Dark background | >3:1 (icons) |

---

## 9. SwiftUI Implementation Notes

### 9.1 State Management Pattern

```swift
// CallView should observe CallViewModel state changes
struct CallView: View {
    @State private var viewModel: CallViewModel

    // Computed state for UI
    private var micButtonState: MicButtonState {
        switch viewModel.state {
        case .idle where viewModel.vadMode == .auto:
            .vadListening
        case .recording where viewModel.isHoldingMic:
            .held
        case .recording:
            .recording
        case .processingSTT:
            .processing
        case .playingResponse:
            .playing
        default:
            .idle
        }
    }

    var body: some View {
        // UI based on micButtonState
    }
}
```

### 9.2 Custom Mic Button Component

```swift
struct MicButton: View {
    let state: MicButtonState
    let audioLevel: Double
    let projectColor: Color
    let onTap: () -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Audio level ring (recording only)
            if state == .recording || state == .held {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 3)
                    .frame(width: 70 + audioLevel * 20)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.05), value: audioLevel)
            }

            // Main button
            Circle()
                .fill(backgroundColor)
                .frame(width: 70, height: 70)
                .shadow(color: shadowColor, radius: 10)

            // Icon
            iconView
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .gesture(combinedGesture)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var backgroundColor: Color {
        switch state {
        case .idle: projectColor
        case .vadListening: projectColor
        case .recording: .red
        case .held: .orange
        case .processing: projectColor.opacity(0.4)
        case .playing: .blue
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch state {
        case .recording, .held:
            RoundedRectangle(cornerRadius: 8)
                .fill(.white)
                .frame(width: 24, height: 24)
        case .processing:
            ProgressView()
                .tint(.white)
        case .playing:
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
        default:
            Image(systemName: "mic.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
        }
    }
}
```

### 9.3 Recommended File Structure

```
Sources/Features/Voice/
    CallView.swift              // Main view (update with VAD states)
    CallViewModel.swift         // Add VAD integration
    CallSettingsView.swift      // NEW: In-call settings overlay
    Components/
        MicButton.swift         // NEW: Extracted mic button
        VoiceStateIndicator.swift  // NEW: Status displays
        HoldHint.swift          // NEW: Tap-hold hint

Sources/Features/Settings/
    VoiceCallSettingsView.swift // NEW: Full settings page
```

### 9.4 Animation Best Practices

1. **Use `withAnimation` for state-driven changes**
```swift
withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
    state = .recording
}
```

2. **Use `.animation()` modifier for value-driven changes**
```swift
.animation(.easeOut(duration: 0.05), value: audioLevel)
```

3. **Respect Reduce Motion**
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

4. **Use matchedGeometryEffect for transitions between states**
```swift
@Namespace private var animation

// In idle state
Image(systemName: "mic.fill")
    .matchedGeometryEffect(id: "micIcon", in: animation)

// In recording state
RoundedRectangle(cornerRadius: 8)
    .matchedGeometryEffect(id: "micIcon", in: animation)
```

---

## Summary

This design specification provides a comprehensive guide for implementing polished, professional voice call features in the iOS client. Key principles:

1. **Clear visual hierarchy** - Users always know the current state
2. **Responsive feedback** - 50ms for audio level, 300ms for state transitions
3. **Tactile confirmation** - Haptics reinforce every meaningful interaction
4. **Accessibility first** - VoiceOver, Dynamic Type, Reduce Motion support
5. **Native feel** - Follow iOS design patterns, use system colors and animations
6. **Graceful degradation** - Works with or without VAD, clear fallbacks

The implementation should feel like a natural extension of iOS, not a web app port.
