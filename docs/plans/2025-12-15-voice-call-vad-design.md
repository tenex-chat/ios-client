# Voice Call Features - VAD, Settings, and UI Integration

**Date:** 2025-12-15
**Feature:** Voice Activity Detection, Call Settings, Microphone Button Integration
**Status:** Design Complete - Ready for Implementation

## Overview

Add professional voice call capabilities to the iOS client matching the Svelte reference implementation:

1. **Microphone button** in ChatView toolbar → opens CallView
2. **Standalone CallSettings** view (accessible from CallView + Settings menu)
3. **Voice Activity Detection (VAD)** for hands-free operation with tap-to-hold override

**Design Principle:** Zero technical debt. Professional, maintainable architecture using modern Swift patterns.

---

## Architecture

### Component Organization

```
Sources/Features/Audio/
  ├── STT/ (existing - SpeechTranscriberSTT, WhisperKitSTT)
  ├── VAD/ (NEW - Voice Activity Detection)
  │   ├── VADService.swift (protocol + core interface)
  │   ├── VADController.swift (lifecycle management, Observable)
  │   └── [Implementation based on research - TBD]
  └── AudioService.swift (existing)

Sources/Features/Voice/
  ├── CallView.swift (existing - enhanced with VAD UI states)
  ├── CallViewModel.swift (existing - integrates VADController)
  └── CallSettingsView.swift (NEW - in-call settings overlay)

Sources/Features/Settings/
  ├── AISettingsView.swift (existing)
  └── VoiceCallSettingsView.swift (NEW - Settings > Voice Call entry point)

TENEXCore/Sources/TENEXCore/Config/
  └── VoiceCallSettings.swift (NEW - configuration model)
```

### Key Architectural Decisions

- **VAD is an audio primitive** (like STT), not voice-call-specific
- **Settings views are thin presentation layers** over shared config
- **CallViewModel composes VADController** (loose coupling, dependency injection)
- **Follow existing patterns**: Observable, async/await, MainActor, protocol-oriented design

---

## Component Details

### 1. VAD Implementation

**Research Required:** Evaluate VAD solutions for Swift/iOS with these criteria:

**Must-Have:**
- Native Swift or high-quality Swift bindings
- Supports latest stable iOS/macOS (verify current versions, don't assume)
- Real-time audio stream processing (not file-based)
- Low latency (<100ms detection)
- Actively maintained (commits within last 6 months)
- Production-ready (used in shipped apps)

**Nice-to-Have:**
- On-device processing (privacy, offline support)
- Configurable sensitivity thresholds
- Permissive license (MIT/Apache)
- Good documentation + examples

**Candidates:**
1. Silero VAD - Port via CoreML (if modern Swift wrapper exists)
2. WebRTC VAD - If Swift package available
3. iOS Speech Framework - Native `SFSpeechAudioBufferRecognitionRequest` with audio level monitoring
4. Third-party Swift packages - Search GitHub for recent VAD Swift implementations

**Deliverable:** Recommendation with justification, integration assessment, license verification, code examples.

---

### 2. VAD Service & Controller

**VADService Protocol:**
```swift
protocol VADService {
    func start(audioStream: AudioStream) async throws
    func stop() async
    func updateSensitivity(_ value: Double) // 0.0-1.0

    var onSpeechStart: (() -> Void)? { get set }
    var onSpeechEnd: (() -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
}
```

**VADController (Observable):**
```swift
@MainActor
@Observable
final class VADController {
    // Observable state
    private(set) var isActive: Bool = false
    private(set) var isListening: Bool = false
    private(set) var isHolding: Bool = false // tap-to-hold override
    private(set) var error: String?

    // Dependencies
    private let service: VADService
    private let settings: VoiceCallSettings

    // Lifecycle
    func start() async throws
    func stop() async
    func pause() // Disable auto-stop (tap-to-hold)
    func resume() // Re-enable auto-stop

    // Callbacks
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
}
```

---

### 3. VoiceCallSettings (TENEXCore)

```swift
public struct VoiceCallSettings: Codable, Sendable, Equatable {
    // VAD Configuration
    public var vadMode: VADMode = .pushToTalk
    public var vadSensitivity: Double = 0.5  // 0.0-1.0

    // Audio Processing
    public var noiseSuppression: Bool = true
    public var echoCancellation: Bool = true
    public var autoGainControl: Bool = true

    // Device Selection
    public var preferredInputDevice: String? = nil

    // Call Behavior
    public var autoTTS: Bool = true
    public var enableVOD: Bool = true
}

public enum VADMode: String, Codable, Sendable, CaseIterable {
    case disabled        // Manual recording only
    case pushToTalk      // Tap to record, tap to stop
    case auto            // VAD detects speech automatically
    case autoWithHold    // VAD + tap-and-hold override (RECOMMENDED)
}
```

**Storage:** Extends `AIConfig` with `voiceCallSettings` property, persisted via DataStore.

---

### 4. CallViewModel VAD Integration

**Enhanced CallViewModel:**
```swift
@MainActor
@Observable
final class CallViewModel {
    // NEW: VAD controller (optional dependency)
    private let vadController: VADController?

    // NEW: VAD mode from settings
    private(set) var vadMode: VADMode

    // NEW: Tap-to-hold state
    private(set) var isHoldingMic: Bool = false

    init(
        audioService: AudioService,
        vadController: VADController? = nil,
        settings: VoiceCallSettings,
        // ... existing params
    ) {
        self.vadController = vadController
        self.vadMode = settings.vadMode
        // ... existing init
    }

    func startCall() async {
        // ... existing code ...

        // Start VAD if enabled
        if vadMode == .auto || vadMode == .autoWithHold {
            vadController?.onSpeechStart = { [weak self] in
                Task { @MainActor in
                    await self?.handleVADSpeechStart()
                }
            }
            vadController?.onSpeechEnd = { [weak self] in
                Task { @MainActor in
                    await self?.handleVADSpeechEnd()
                }
            }
            try? await vadController?.start()
        }
    }

    // Tap-to-hold override
    func startHoldingMic() {
        isHoldingMic = true
        vadController?.pause() // Disable auto-stop
    }

    func stopHoldingMic() {
        isHoldingMic = false
        vadController?.resume() // Re-enable auto-stop
    }

    private func handleVADSpeechStart() async {
        guard !isHoldingMic else { return }
        await startRecording()
    }

    private func handleVADSpeechEnd() async {
        guard !isHoldingMic else { return }
        await stopRecording()
    }
}
```

**Key Design:**
- VAD is **optional** - CallView works without it (graceful degradation)
- VAD callbacks reuse existing `startRecording()`/`stopRecording()` - no duplication
- Tap-to-hold pauses VAD auto-stop, resumes on release
- Push-to-talk remains default/fallback

---

### 5. Microphone Button Integration (ChatView)

**Current ChatView Toolbar:**
```swift
.toolbar {
    ToolbarItem(placement: .automatic) {
        Button { isShowingSettings = true }
        label: { Image(systemName: "gear") }
    }
}
```

**Enhanced Toolbar:**
```swift
.toolbar {
    ToolbarItem(placement: .automatic) {
        HStack(spacing: 12) {
            // NEW: Voice call button
            Button {
                isShowingCallView = true
            } label: {
                Image(systemName: "phone.fill")
                    .foregroundStyle(.blue)
            }
            .accessibilityLabel("Start voice call")

            // Existing: Settings
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gear")
            }
        }
    }
}

.sheet(isPresented: $isShowingCallView) {
    if let ndk, let viewModel = createCallViewModel() {
        CallView(
            viewModel: viewModel,
            ndk: ndk,
            projectColor: projectColor,
            onDismiss: { isShowingCallView = false }
        )
    }
}
```

**CallViewModel Creation:**
```swift
private func createCallViewModel() -> CallViewModel? {
    guard let chatViewModel = viewModel else { return nil }

    // Get selected agent or most recent responder
    let agent = chatViewModel.selectedAgent
        ?? chatViewModel.mostRecentAgentResponder
    guard let agent else { return nil }

    // Load settings
    let settings = dataStore.voiceCallSettings

    // Create VAD controller if enabled
    let vadController: VADController? = {
        guard settings.vadMode == .auto || settings.vadMode == .autoWithHold else {
            return nil
        }
        // VADController created with appropriate VADService implementation
        return VADController(
            service: /* VADService instance */,
            settings: settings
        )
    }()

    // Get voice ID from agent voice config storage
    let voiceID = dataStore.getAgentVoiceID(agentPubkey: agent.pubkey)

    return CallViewModel(
        audioService: dataStore.audioService,
        vadController: vadController,
        settings: settings,
        projectID: projectReference,
        agent: agent,
        voiceID: voiceID,
        onSendMessage: { [weak chatViewModel] text, agentPubkey, tags in
            try await chatViewModel?.sendMessage(
                text: text,
                agentPubkey: agentPubkey,
                tags: tags
            )
        }
    )
}
```

---

### 6. Settings Views

**VoiceCallSettingsView (Settings > Voice Call):**
- Full settings page
- NavigationStack presentation
- Comprehensive configuration:
  - VAD mode picker (disabled, push-to-talk, auto, auto-with-hold)
  - VAD sensitivity slider (0.0-1.0)
  - Audio processing toggles (noise suppression, echo cancellation, auto-gain)
  - Input device selection (if available)
  - Auto-TTS toggle
  - Enable VOD toggle

**CallSettingsView (In-call overlay):**
- Sheet from CallView
- Quick toggles:
  - VAD mode switcher
  - Auto-TTS toggle
  - Mute/unmute
- Link to full VoiceCallSettingsView for advanced options
- Non-modal overlay, stays visible during call

**Data Flow:**
```
VoiceCallSettings (TENEXCore)
    ↓
AIConfig.voiceCallSettings
    ↓
DataStore (publishes changes via @Observable)
    ↓
CallViewModel (observes, updates VAD dynamically)
```

---

## UX/UI Design Requirements

**Visual States (to be designed by UX subagent):**
1. Idle (ready to speak)
2. VAD listening (auto-detecting speech)
3. Recording (speech detected or manual)
4. Tap-held (user holding mic open)
5. Processing (STT in progress)
6. Playing (TTS speaking)
7. Error (clear error indication)

**Animations:**
- Smooth state transitions
- Pulsing ring for active listening (VAD)
- Audio level visualization
- Mic button animations (tap, hold, release)

**Haptic Feedback:**
- Light impact: VAD speech detected
- Medium impact: Manual recording start/stop
- Notification: Error occurred
- Selection: Button taps in settings

**Tap-to-Hold Interaction:**
- User taps and holds anywhere on CallView → mic stays open
- Visual: "Hold to keep mic open" hint + different visual state
- Release → VAD resumes or immediately stops if silence
- Solves "thinking while speaking" use case

**Accessibility:**
- VoiceOver support for all states
- Dynamic Type scaling
- Reduce Motion (disable pulsing, use opacity)
- Minimum touch targets: 44x44 points
- Clear state announcements

**Localization Ready:**
- All strings in localizable resources
- Number/date formatters use user's locale

---

## Error Handling & Edge Cases

**Audio Session Conflicts:**
- Handle interruptions (phone calls, Siri)
- Pause VAD during interruption
- Resume when session reactivated
- Clear visual feedback

**VAD Edge Cases:**
- Background noise false positives → Use sensitivity settings
- VAD doesn't detect speech → Tap-to-hold override available
- VAD library fails to load → Graceful fallback to push-to-talk
- Permissions denied → Show error with Settings deep link

**Network Issues:**
- STT fails → Show error, allow retry with cached audio
- Agent timeout → "Waiting..." state, allow cancellation
- Nostr disconnection → Queue message, retry when reconnected

**State Machine:**
- User dismisses CallView mid-recording → Cancel gracefully
- Multiple rapid taps → Debounce, ensure clean transitions
- TTS playing when call ends → Cancel immediately

**Memory Management:**
- VAD buffers cleared after each utterance
- Audio recordings released after transcription
- VOD files written incrementally (not held in memory)

---

## Implementation Plan

### Phase 1: Research & Design (Parallel)

**Subagent 1: VAD Library Research**
- Verify latest stable iOS/macOS SDK versions
- Evaluate VAD libraries against criteria
- Provide recommendation with justification
- License verification
- Integration assessment

**Subagent 2: UX/UI Design (Opus model)**
- Design visual states and transitions
- Define animations and haptic feedback
- Create accessibility guidelines
- Design CallSettingsView and VoiceCallSettingsView layouts
- Provide mockups/descriptions for implementation

### Phase 2: Core Implementation (Parallel)

**Subagent 3: VAD Integration**
- Implement chosen VAD library
- Create VADService protocol + concrete implementation
- Create VADController with Observable state
- Add tap-to-hold override logic
- Error handling and edge cases

**Subagent 4: Settings Implementation**
- Add VoiceCallSettings to TENEXCore
- Extend AIConfig with voiceCallSettings
- Create VoiceCallSettingsView (Settings entry)
- Create CallSettingsView (in-call overlay)
- Wire up to DataStore

**Subagent 5: ChatView Integration**
- Add microphone button to toolbar
- Implement CallViewModel creation logic
- Wire up message callbacks
- Handle agent response routing
- Error handling

### Phase 3: Enhancement & Polish

**Subagent 6: CallViewModel VAD Integration**
- Integrate VADController into CallViewModel
- Implement mode switching
- Add tap-to-hold mechanics
- State machine updates
- Comprehensive error handling

**Subagent 7: UI/UX Implementation**
- Implement designed visual states
- Add animations and haptics
- Accessibility support (VoiceOver, Dynamic Type, Reduce Motion)
- Polish CallView with new states
- Polish settings views

### Phase 4: Code Review & Commit

- Use `superpowers:requesting-code-review` skill
- Address any issues found
- Verify zero technical debt
- Ensure follows existing patterns
- Single clean commit with descriptive message

---

## Success Criteria

✅ Microphone button in ChatView toolbar opens CallView
✅ VAD auto-detects speech start/end (when enabled)
✅ Tap-to-hold override works in VAD mode
✅ CallSettingsView accessible from CallView
✅ VoiceCallSettingsView accessible from Settings
✅ All settings persist correctly
✅ Graceful fallback to push-to-talk if VAD fails
✅ Professional animations and haptics
✅ Full accessibility support
✅ Zero technical debt
✅ Clean, maintainable code following existing patterns
✅ Comprehensive error handling

---

## Future Enhancements (Out of Scope)

- Cloud-based STT options (Whisper API, ElevenLabs)
- Advanced VAD tuning (pre-speech pad, redemption frames)
- Multi-device audio routing
- Call recording playback UI
- Voice activity visualization in chat history

---

**End of Design Document**
