# CallView Feature - Voice Calls with Auto-TTS, STT, and VOD

## Overview

The CallView feature provides a comprehensive voice call experience for interacting with TENEX agents. It enhances the existing VoiceModeView with auto-TTS (Text-to-Speech), STT (Speech-to-Text), and VOD (Voice on Demand) recording capabilities.

## Features

### 1. **Real-time Voice Calls**
- Full-duplex conversation with agents
- Visual call state indicators
- Real-time audio level visualization
- Push-to-talk or voice-activated recording

### 2. **Auto-TTS (Text-to-Speech)**
- Automatic speech synthesis for agent responses
- Support for custom voice IDs per agent
- Toggle auto-TTS on/off during calls
- Fallback to system TTS if primary service fails
- Manual replay of any message

### 3. **STT (Speech-to-Text)**
- On-device speech recognition (SpeechTranscriber on iOS 18+)
- WhisperKit fallback for older devices
- Real-time transcription with visual feedback
- Edit transcript before sending

### 4. **VOD (Voice on Demand) Recording**
- Optional call recording in JSON format
- Playback interface for reviewing past calls
- Message-by-message replay with TTS
- Adjustable playback speed (0.5x - 2.0x)
- Automatic metadata capture (timestamp, duration, participants)

## Architecture

### Components

```
Sources/Features/Voice/
├── CallViewModel.swift          # Call state management and orchestration
├── CallView.swift              # Main call UI with controls and conversation
├── VODPlaybackView.swift       # Playback interface for recorded calls
├── VoiceVisualizerView.swift   # Audio level visualization (shared)
├── VoiceStatusView.swift       # Status indicators (shared)
└── VoiceControlsView.swift     # Control buttons (shared)
```

### State Machine

The CallViewModel implements a robust state machine:

```swift
enum CallState {
    case idle              // Call not started
    case connecting        // Establishing connection
    case listening         // Waiting for user input
    case recording         // Recording user speech
    case processingSTT     // Transcribing speech to text
    case waitingForAgent   // Waiting for agent response
    case playingResponse   // Playing agent's TTS response
    case ended            // Call completed
}
```

### Data Models

**CallMessage**: Represents a single message in the conversation
```swift
struct CallMessage {
    let id: String
    let sender: CallParticipant
    let content: String
    let timestamp: Date
    var audioURL: URL?
}
```

**CallParticipant**: User or agent participant
```swift
enum CallParticipant {
    case user
    case agent(pubkey: String, name: String, voiceID: String?)
}
```

**VODRecording**: Recorded call with metadata
```swift
struct VODRecording {
    let projectID: String
    let agentPubkey: String
    let agentName: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let messages: [CallMessage]
    let fileURL: URL
}
```

## Usage

### Starting a Call

```swift
let callViewModel = CallViewModel(
    audioService: audioService,
    projectID: "project-123",
    agent: agent,
    enableVOD: true,        // Enable call recording
    autoTTS: true,          // Auto-play agent responses
    onSendMessage: { text, agentPubkey, tags in
        // Send message to agent via Nostr
        try await sendNostrMessage(text, to: agentPubkey, tags: tags)
    }
)

let callView = CallView(
    viewModel: callViewModel,
    ndk: ndk,
    projectColor: .blue,
    onDismiss: {
        // Handle call dismissal
    }
)

// Present as full-screen modal
.fullScreenCover(isPresented: $showingCall) {
    callView
}
```

### Handling Agent Responses

```swift
// When agent response arrives via Nostr
Task { @MainActor in
    await callViewModel.handleAgentResponse(responseText)
}
```

### Playing Back Recorded Calls

```swift
// Load VOD recording
let recording = try VODRecording.load(from: recordingURL)

let playbackViewModel = VODPlaybackViewModel(
    recording: recording,
    audioService: audioService
)

let playbackView = VODPlaybackView(
    viewModel: playbackViewModel,
    projectColor: .blue,
    onDismiss: { }
)

// Present as sheet
.sheet(isPresented: $showingPlayback) {
    playbackView
}
```

## VOD Recording Format

Recordings are stored as JSON files with the following structure:

```json
{
  "projectID": "project-123",
  "agentPubkey": "npub1...",
  "agentName": "Agent Name",
  "startTime": "2025-01-15T10:30:00Z",
  "endTime": "2025-01-15T10:35:30Z",
  "duration": 330.0,
  "messages": [
    {
      "id": "msg-1",
      "sender": "agent",
      "content": "How can I help you?",
      "timestamp": "2025-01-15T10:30:00Z"
    },
    {
      "id": "msg-2",
      "sender": "user",
      "content": "I need help with my project",
      "timestamp": "2025-01-15T10:30:15Z"
    }
  ]
}
```

## UI Components

### CallView

Main call interface featuring:
- **Header**: Agent info, status indicator, end call button
- **Conversation Area**: Scrollable message history with user/agent bubbles
- **Audio Visualizer**: Real-time audio level indicator during recording
- **Controls**:
  - Auto-TTS toggle
  - Record/Stop button (push-to-talk)
  - Send message button
- **Transcript Display**: Shows current STT result before sending
- **VOD Indicator**: Shows when call is being recorded

### VODPlaybackView

Playback interface featuring:
- **Recording Info**: Agent name, date, duration
- **Progress Bar**: Visual progress through the conversation
- **Message List**: All messages with current position highlighted
- **Playback Controls**:
  - Play/Pause button
  - Stop button
  - Speed control (0.5x - 2.0x)
- **Message Replay**: Tap any message to replay its audio

### MessageBubble

Reusable message component:
- User messages: Right-aligned, accent color background
- Agent messages: Left-aligned, subtle background, replay button
- Timestamp and sender name display
- Smooth animations

## Audio Services Integration

The CallView leverages the existing audio infrastructure:

- **AudioService**: Main coordinator with TTS/STT fallbacks
- **AudioRecorder**: Handles microphone recording with level metering
- **AudioPlayer**: Manages playback with progress tracking
- **TTSService**: ElevenLabs (primary) + System TTS (fallback)
- **STTService**: SpeechTranscriber (iOS 18+) + WhisperKit (fallback)

## Testing

Comprehensive test coverage includes:

### CallViewModelTests
- Initialization and configuration
- Call lifecycle (start, end)
- Recording state transitions
- Message sending and receiving
- Auto-TTS behavior
- VOD recording creation and storage
- Error handling and recovery
- Playback controls

### Running Tests

```bash
# All tests
tuist test

# Specific suite
tuist test --filter CallViewModelTests
```

## Accessibility

- VoiceOver support for all controls
- Dynamic Type support for text
- High contrast mode support
- Haptic feedback for state changes
- Clear visual and audio state indicators

## Performance Considerations

1. **Audio Buffering**: Optimized for low-latency playback
2. **Memory Management**: Automatic cleanup of temporary files
3. **Background Support**: Call state preserved during app backgrounding
4. **Network Efficiency**: Local STT when available
5. **Storage**: VOD recordings stored in temp directory, cleaned periodically

## Future Enhancements

- [ ] Multi-agent conference calls
- [ ] Video support for agent avatars
- [ ] Real-time transcription display during playback
- [ ] Cloud storage for VOD recordings
- [ ] Advanced audio processing (noise cancellation, echo reduction)
- [ ] Custom wake words for hands-free activation
- [ ] Offline message queuing
- [ ] Voice activity detection improvements

## Related Documentation

- [Audio Services Architecture](./AUDIO_SERVICES.md)
- [Voice Mode Guide](./VOICE_MODE.md)
- [NDKSwift Integration](./NDK_INTEGRATION.md)

## Credits

Built on top of the existing TENEX voice infrastructure and NDKSwift for Nostr integration.
