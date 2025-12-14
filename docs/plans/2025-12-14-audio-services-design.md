# Audio Services Infrastructure Design

**Date:** 2025-12-14
**Status:** Approved
**Scope:** Audio Infrastructure First (Option B)

## Overview

Implement audio service layer for TENEX iOS client with:
- **TTS:** ElevenLabs (primary) + System/AVSpeechSynthesizer (fallback)
- **STT:** SpeechTranscriber iOS 18+ (primary) + WhisperKit (fallback)
- **Audio:** Recording and playback infrastructure
- **No UI:** CallView deferred, use from ChatInputView mic button

## Architecture: Protocol-First with Composition

### File Structure
```
Sources/Features/Audio/
├── Core/
│   ├── AudioService.swift          # Main coordinator
│   ├── AudioRecorder.swift         # Recording manager
│   └── AudioPlayer.swift           # Playback manager
├── TTS/
│   ├── TTSService.swift            # Protocol
│   ├── ElevenLabsTTSService.swift  # Primary (uses official SDK)
│   └── SystemTTSService.swift      # Fallback
└── STT/
    ├── STTService.swift            # Protocol
    ├── SpeechTranscriberSTT.swift  # Primary (iOS 18+)
    └── WhisperKitSTT.swift         # Fallback
```

## Component Design

### AudioService (Coordinator)

Main service that orchestrates all audio operations:

```swift
@Observable
@MainActor
final class AudioService {
    private let ttsService: TTSService
    private let ttsFallback: TTSService
    private let sttService: STTService
    private let sttFallback: STTService
    private let recorder: AudioRecorder
    private let player: AudioPlayer
    private let storage: AIConfigStorage

    init(storage: AIConfigStorage, capabilityDetector: AICapabilityDetector)

    // Recording & Transcription
    func startRecording() async throws
    func stopRecording() async throws -> String

    // Synthesis & Playback
    func speak(text: String, voiceID: String?) async throws
}
```

**Responsibilities:**
- Service selection based on AIConfig
- Fallback chain management
- Audio session coordination
- Error recovery

**Service Selection Logic:**
```swift
// TTS: ElevenLabs if API key exists, else System
if let apiKey = storage.loadAPIKey(for: "elevenlabs"), !apiKey.isEmpty {
    ttsService = ElevenLabsTTSService(apiKey: apiKey)
} else {
    ttsService = SystemTTSService()
}
ttsFallback = SystemTTSService()

// STT: SpeechTranscriber if iOS 18+, else WhisperKit
if #available(iOS 18.0, *), capabilityDetector.isSpeechTranscriberAvailable() {
    sttService = SpeechTranscriberSTT()
} else {
    sttService = WhisperKitSTT()
}
sttFallback = WhisperKitSTT()
```

### TTSService Protocol

```swift
protocol TTSService: Sendable {
    func synthesize(text: String, voiceID: String?) async throws -> Data
    func synthesize(text: String, voiceID: String?, streaming: Bool) async throws -> AsyncThrowingStream<Data, Error>
    var supportedVoices: [VoiceConfig] { get }
    var isAvailable: Bool { get async }
}
```

### ElevenLabsTTSService

**Primary TTS provider using official ElevenLabs Swift SDK:**

```swift
final class ElevenLabsTTSService: TTSService {
    private let apiKey: String
    private let client: ElevenLabsClient

    init(apiKey: String) {
        self.apiKey = apiKey
        self.client = ElevenLabsClient(apiKey: apiKey)
    }

    func synthesize(text: String, voiceID: String?) async throws -> Data {
        let voice = voiceID ?? "21m00Tcm4TlvDq8ikWAM" // Rachel default
        return try await client.textToSpeech.convert(
            text: text,
            voiceId: voice
        )
    }
}
```

**Features:**
- Uses official ElevenLabs Swift SDK
- Supports streaming for low-latency playback
- MP3 audio output
- Voice settings from VoiceConfig.metadata

**Error Handling:**
- No API key → Unavailable, trigger fallback
- Network failure → Throw error, trigger fallback
- Invalid voice → Use default (Rachel)
- Rate limit → Throw with retry info

### SystemTTSService

**Fallback TTS using AVSpeechSynthesizer:**

```swift
final class SystemTTSService: TTSService {
    private let synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()

    func synthesize(text: String, voiceID: String?) async throws -> Data {
        // 1. Set up audio engine to capture output
        // 2. Configure AVSpeechUtterance
        // 3. Speak while recording to buffer
        // 4. Convert buffer to Data (PCM/WAV)
        // 5. Return audio data
    }
}
```

**Implementation Notes:**
- AVSpeechSynthesizer doesn't directly produce audio data
- Capture output via AVAudioEngine recording
- Maps VoiceConfig IDs to AVSpeechSynthesisVoice identifiers
- Always available (no API key required)
- Basic quality but reliable

### STTService Protocol

```swift
protocol STTService: Sendable {
    func transcribe(audioData: Data) async throws -> String
    func transcribe(audioURL: URL) async throws -> String
    var isAvailable: Bool { get async }
    var requiresNetwork: Bool { get }
}
```

### SpeechTranscriberSTT

**Primary STT for iOS 18+ using on-device transcription:**

```swift
@available(iOS 18.0, *)
final class SpeechTranscriberSTT: STTService {
    private let recognizer: SFSpeechRecognizer

    func transcribe(audioURL: URL) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw STTError.permissionDenied
        }

        let transcription = try await recognizer.transcription(from: audioURL)
        return transcription.formattedString
    }

    var requiresNetwork: Bool { false }
}
```

**Features:**
- Completely on-device, no network required
- Fast, low-latency transcription
- Supports multiple languages
- Requires speech recognition permission

**Error Cases:**
- iOS < 18 → Service unavailable, use fallback
- Permission denied → Throw error, prompt user
- Unsupported audio format → Convert first

### WhisperKitSTT

**Fallback STT using on-device Whisper model:**

```swift
final class WhisperKitSTT: STTService {
    private var whisperKit: WhisperKit?

    func transcribe(audioURL: URL) async throws -> String {
        if whisperKit == nil {
            // Download model on first use (~100MB for tiny)
            whisperKit = try await WhisperKit(model: "tiny")
        }

        let result = try await whisperKit!.transcribe(audioPath: audioURL.path)
        return result.text
    }

    var requiresNetwork: Bool { false }
}
```

**Features:**
- Works on iOS 14+
- Offline transcription
- Multiple model sizes (tiny, base, small)
- Model cached after first download
- Slower than SpeechTranscriber but more compatible

### AudioRecorder

**Manages microphone recording with real-time monitoring:**

```swift
@Observable
@MainActor
final class AudioRecorder {
    private(set) var isRecording: Bool = false
    private(set) var audioLevel: Double = 0.0  // 0.0 to 1.0
    private(set) var recordingDuration: TimeInterval = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var meteringTimer: Timer?

    func startRecording() async throws -> URL
    func stopRecording() async throws -> URL
    func cancelRecording() async
}
```

**Configuration:**
- Format: Linear PCM, 16kHz, mono (optimized for speech)
- Location: Documents/Recordings/temp_recording.wav
- Auto-cleanup: Delete files older than 24h
- Metering: Update level every 50ms

**Audio Session:**
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.record, mode: .default)
try session.setActive(true)
```

**Real-time Level Monitoring:**
```swift
meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
    audioRecorder.updateMeters()
    let power = audioRecorder.averagePower(forChannel: 0)
    audioLevel = normalizedPower(power) // Convert dB to 0.0-1.0
}
```

**Permission Handling:**
- Check before recording: `AVAudioSession.recordPermission`
- Request if needed: `AVAudioSession.requestRecordPermission()`
- Throw `AudioError.permissionDenied` if not authorized

**Interruption Handling:**
- Save partial recording on interruption
- Restore session when interruption ends
- Notify caller of interruption state

### AudioPlayer

**Manages audio playback with progress tracking:**

```swift
@Observable
@MainActor
final class AudioPlayer {
    private(set) var isPlaying: Bool = false
    private(set) var playbackProgress: Double = 0.0  // 0.0 to 1.0

    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    func play(audioData: Data) async throws
    func play(url: URL) async throws
    func pause()
    func stop()
}
```

**Configuration:**
- Audio session: `.playback` mode
- Progress updates: Every 100ms
- Completion callback for queue management

**Session Management:**
```swift
// For playback only
try AVAudioSession.sharedInstance().setCategory(.playback)

// For simultaneous record + playback
try AVAudioSession.sharedInstance().setCategory(.playAndRecord)
```

## Error Handling

### Error Types

```swift
enum AudioError: LocalizedError {
    case permissionDenied
    case recordingFailed(Error)
    case transcriptionFailed(Error)
    case synthesisFailed(Error)
    case playbackFailed(Error)
    case noAPIKey(provider: String)
    case networkError(Error)
    case unsupportedFormat
    case interrupted

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access required"
        case .noAPIKey(let provider):
            return "API key required for \(provider)"
        // ... etc
        }
    }
}
```

### Fallback Chain Strategy

**TTS Fallback:**
```swift
func speak(text: String, voiceID: String?) async throws {
    do {
        let audio = try await ttsService.synthesize(text: text, voiceID: voiceID)
        try await player.play(audioData: audio)
    } catch {
        // Fallback to system TTS
        let audio = try await ttsFallback.synthesize(text: text, voiceID: nil)
        try await player.play(audioData: audio)
    }
}
```

**STT Fallback:**
```swift
func stopRecording() async throws -> String {
    let url = try await recorder.stopRecording()

    do {
        return try await sttService.transcribe(audioURL: url)
    } catch {
        // Fallback to WhisperKit
        return try await sttFallback.transcribe(audioURL: url)
    }
}
```

## Integration with Existing Code

### ChatInputView Integration

```swift
struct ChatInputView: View {
    @State private var audioService: AudioService
    @State private var isRecording = false

    var body: some View {
        HStack {
            // Mic button
            Button(action: toggleRecording) {
                Image(systemName: isRecording ? "mic.fill" : "mic")
            }
        }
    }

    func toggleRecording() {
        Task {
            if isRecording {
                let transcript = try await audioService.stopRecording()
                inputText = transcript
            } else {
                try await audioService.startRecording()
            }
            isRecording.toggle()
        }
    }
}
```

### Dependency Injection

```swift
// In app initialization
let storage = UserDefaultsAIConfigStorage()
let capabilityDetector = RuntimeAICapabilityDetector()
let audioService = AudioService(
    storage: storage,
    capabilityDetector: capabilityDetector
)

// Pass to views via environment
.environment(\.audioService, audioService)
```

## Testing Strategy

### Unit Tests

**Mock Services:**
```swift
final class MockTTSService: TTSService {
    var synthesizeCallCount = 0
    var shouldFail = false

    func synthesize(text: String, voiceID: String?) async throws -> Data {
        synthesizeCallCount += 1
        if shouldFail { throw AudioError.synthesisFailed(NSError()) }
        return Data() // Empty audio data for testing
    }
}
```

**Test Fallback Chain:**
```swift
func testTTSFallback() async throws {
    let primary = MockTTSService()
    primary.shouldFail = true
    let fallback = MockTTSService()

    let service = AudioService(
        ttsService: primary,
        ttsFallback: fallback
    )

    try await service.speak(text: "test", voiceID: nil)

    XCTAssertEqual(primary.synthesizeCallCount, 1)
    XCTAssertEqual(fallback.synthesizeCallCount, 1)
}
```

**Test Permission Handling:**
```swift
func testRecordingPermissionDenied() async {
    // Mock AVAudioSession to return denied permission
    // Verify AudioRecorder throws AudioError.permissionDenied
}
```

### Integration Tests

**System TTS (Always Available):**
```swift
func testSystemTTS() async throws {
    let service = SystemTTSService()
    let audio = try await service.synthesize(text: "Hello", voiceID: nil)
    XCTAssertGreaterThan(audio.count, 0)
}
```

**Audio Recording → File:**
```swift
func testRecordingCreatesFile() async throws {
    let recorder = AudioRecorder()
    let url = try await recorder.startRecording()
    try await Task.sleep(for: .seconds(1))
    let finalURL = try await recorder.stopRecording()

    XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
}
```

**Playback Known Audio:**
```swift
func testPlaybackKnownFile() async throws {
    let player = AudioPlayer()
    let testAudioURL = Bundle.main.url(forResource: "test", withExtension: "wav")!
    try await player.play(url: testAudioURL)
    XCTAssertTrue(player.isPlaying)
}
```

### Manual Testing Requirements

**Real Device Required:**
- Microphone and speaker access
- Test recording → transcription flow
- Test TTS playback quality
- Test interruption scenarios (phone calls, alarms)

**Test Cases:**
1. **With ElevenLabs API key:** Verify primary TTS works
2. **Without ElevenLabs API key:** Verify fallback to System TTS
3. **iOS 18 device:** Verify SpeechTranscriber works
4. **iOS 17 device:** Verify WhisperKit fallback works
5. **Interruptions:** Call arrives during recording/playback

## Dependencies

### Package Dependencies

Add to Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/elevenlabs/elevenlabs-swift", from: "1.0.0"),
    .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.5.0")
]
```

### System Frameworks

- AVFoundation (recording, playback)
- Speech (iOS 18+ transcription)
- Foundation (async/await, URLSession)

## Implementation Phases

### Phase 1: Core Infrastructure ✓
- AudioRecorder with metering
- AudioPlayer with progress
- AudioService coordinator
- Basic error types

### Phase 2: TTS Services ✓
- TTSService protocol
- SystemTTSService (fallback)
- ElevenLabsTTSService (primary)
- TTS fallback chain

### Phase 3: STT Services ✓
- STTService protocol
- WhisperKitSTT (fallback)
- SpeechTranscriberSTT (primary, iOS 18+)
- STT fallback chain

### Phase 4: Integration ✓
- ChatInputView mic button
- Environment injection
- Permission prompts
- Error UI

### Phase 5: Testing ✓
- Unit tests with mocks
- Integration tests
- Manual device testing
- Fallback chain validation

## Future Enhancements (Out of Scope)

- CallView UI (full voice conversation interface)
- Voice Activity Detection (VAD) for hands-free mode
- Real-time streaming transcription
- Audio message attachments in chat
- Voice message playback in message bubbles
- Multi-language support
- Custom Whisper model selection
- Audio quality settings (bitrate, sample rate)

## Success Criteria

- ✅ User can tap mic button to record voice
- ✅ Recording shows real-time audio level
- ✅ Transcription appears in text input
- ✅ TTS fallback works when ElevenLabs unavailable
- ✅ STT fallback works on iOS < 18
- ✅ All permissions handled gracefully
- ✅ No crashes on interruptions
- ✅ Clean audio session management

## References

- Svelte CallView reference: `/Users/pablofernandez/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/components/call/`
- Existing iOS AI config: `/Sources/Core/AI/`
- Apple Speech framework: https://developer.apple.com/documentation/speech
- ElevenLabs Swift SDK: https://github.com/elevenlabs/elevenlabs-swift
- WhisperKit: https://github.com/argmaxinc/WhisperKit
