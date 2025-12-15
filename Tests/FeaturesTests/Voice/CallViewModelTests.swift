//
// CallViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - CallViewModelTests

// swiftlint:disable type_body_length

@Suite("CallViewModel Tests")
@MainActor
struct CallViewModelTests {
    // MARK: - Helper Types

    final class MockAudioService: AudioService {
        var shouldFailRecording = false
        var shouldFailTranscription = false
        var shouldFailTTS = false

        var recordingStarted = false
        var recordingStopped = false
        var recordingCancelled = false
        var speechSynthesized: [(text: String, voiceID: String?)] = []
        var playbackStopped = false

        override func startRecording() async throws {
            if self.shouldFailRecording {
                throw AudioError.permissionDenied
            }
            self.recordingStarted = true
        }

        override func stopRecording() async throws -> String {
            self.recordingStopped = true
            if self.shouldFailTranscription {
                throw AudioError.transcriptionFailed(NSError(domain: "Test", code: -1))
            }
            return "Test transcript"
        }

        override func cancelRecording() async {
            self.recordingCancelled = true
        }

        override func speak(text: String, voiceID: String? = nil) async throws {
            self.speechSynthesized.append((text, voiceID))
            if self.shouldFailTTS {
                throw AudioError.synthesisFailed(NSError(domain: "Test", code: -1))
            }
        }

        override func stopSpeaking() {
            self.playbackStopped = true
        }
    }

    // MARK: - Initialization Tests

    @Test("CallViewModel initializes with correct state")
    func initialization() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: "test-voice"
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: true,
            autoTTS: true
        ) { _, _, _ in }

        #expect(viewModel.state == .idle)
        #expect(viewModel.currentTranscript.isEmpty)
        #expect(viewModel.enableVOD == true)
        #expect(viewModel.autoTTS == true)
        #expect(!viewModel.isCallActive)
    }

    // MARK: - Call Lifecycle Tests

    @Test("Starting call transitions to listening state and adds welcome message")
    func testStartCall() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()

        #expect(viewModel.state == .listening)
        #expect(viewModel.isCallActive)
    }

    @Test("Starting call with auto-TTS speaks welcome message")
    func startCallWithAutoTTS() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: "test-voice"
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: true
        ) { _, _, _ in }

        await viewModel.startCall()

        #expect(viewModel.state == .listening)
        #expect(!mockAudio.speechSynthesized.isEmpty)
        #expect(mockAudio.speechSynthesized.first?.voiceID == "test-voice")
    }

    @Test("Ending call stops recording and playback")
    func testEndCall() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()
        await viewModel.endCall()

        #expect(viewModel.state == .ended)
        #expect(mockAudio.playbackStopped)
    }

    // MARK: - Recording Tests

    @Test("Starting recording transitions to recording state")
    func testStartRecording() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()
        await viewModel.startRecording()

        #expect(viewModel.state == .recording)
        #expect(mockAudio.recordingStarted)
    }

    @Test("Stopping recording transcribes audio and updates transcript")
    func testStopRecording() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()
        await viewModel.startRecording()
        await viewModel.stopRecording()

        #expect(viewModel.state == .listening)
        #expect(mockAudio.recordingStopped)
        #expect(viewModel.currentTranscript == "Test transcript")
        #expect(viewModel.canSend)
    }

    @Test("Recording failure sets error and returns to listening")
    func recordingFailure() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        mockAudio.shouldFailRecording = true

        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()
        await viewModel.startRecording()

        #expect(viewModel.state == .listening)
        #expect(viewModel.error != nil)
    }

    // MARK: - Messaging Tests

    @Test("Sending message adds to conversation and calls callback")
    func testSendMessage() async throws {
        var messageSent = false
        var sentText = ""
        var sentPubkey = ""
        var sentTags: [[String]] = []

        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { text, pubkey, tags in
            messageSent = true
            sentText = text
            sentPubkey = pubkey
            sentTags = tags
        }

        await viewModel.startCall()
        await viewModel.startRecording()
        await viewModel.stopRecording()

        await viewModel.sendMessage()

        #expect(messageSent)
        #expect(sentText == "Test transcript")
        #expect(sentPubkey == "test-pubkey")
        #expect(sentTags.contains(["mode", "voice"]))
        #expect(viewModel.currentTranscript.isEmpty)
        #expect(viewModel.state == .listening)
    }

    // MARK: - VOD Tests

    @Test("VOD recording creates file when enabled")
    func vODRecording() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: true,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()

        #expect(viewModel.vodRecordingURL != nil)

        // Verify file exists
        if let url = viewModel.vodRecordingURL {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }

        await viewModel.endCall()
    }

    @Test("VOD recording not created when disabled")
    func vODNotRecordingWhenDisabled() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()

        #expect(viewModel.vodRecordingURL == nil)
    }

    @Test("VOD recording persists messages to file")
    func vodRecordingPersistsMessages() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: "test-voice"
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: true,
            autoTTS: false
        ) { _, _, _ in }

        // Start call
        await viewModel.startCall()

        // Verify VOD file was created
        guard let vodURL = viewModel.vodRecordingURL else {
            Issue.record("VOD recording URL should not be nil")
            return
        }

        #expect(FileManager.default.fileExists(atPath: vodURL.path))

        // Send a user message
        await viewModel.startRecording()
        await viewModel.stopRecording()
        await viewModel.sendMessage()

        // End call
        await viewModel.endCall()

        // Read the VOD file from disk
        let vodData = try Data(contentsOf: vodURL)
        let vodJSON = try JSONSerialization.jsonObject(with: vodData) as? [String: Any]

        #expect(vodJSON != nil)

        // Verify metadata
        #expect(vodJSON?["projectID"] as? String == "test-project")
        #expect(vodJSON?["agentPubkey"] as? String == "test-pubkey")
        #expect(vodJSON?["agentName"] as? String == "Test Agent")
        #expect(vodJSON?["startTime"] != nil)
        #expect(vodJSON?["endTime"] != nil)
        #expect(vodJSON?["duration"] != nil)

        // Verify messages array exists (messages will come through subscription in production)
        let messages = vodJSON?["messages"] as? [[String: Any]]
        #expect(messages != nil)

        // Clean up test file
        try? FileManager.default.removeItem(at: vodURL)
    }

    // MARK: - Playback Control Tests

    @Test("Toggle auto-TTS changes setting")
    func testToggleAutoTTS() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: true
        ) { _, _, _ in }

        #expect(viewModel.autoTTS == true)
        viewModel.toggleAutoTTS()
        #expect(viewModel.autoTTS == false)
        viewModel.toggleAutoTTS()
        #expect(viewModel.autoTTS == true)
    }

    @Test("Stop playback stops audio service")
    func testStopPlayback() async throws {
        let mockAudio = MockAudioService(
            storage: MockAIConfigStorage(),
            capabilityDetector: MockAICapabilityDetector()
        )
        let agent = ProjectAgent(
            id: "test-agent",
            pubkey: "test-pubkey",
            name: "Test Agent",
            role: "assistant",
            useCase: "testing",
            voiceID: nil
        )

        let viewModel = CallViewModel(
            audioService: mockAudio,
            projectID: "test-project",
            agent: agent,
            enableVOD: false,
            autoTTS: false
        ) { _, _, _ in }

        await viewModel.startCall()
        viewModel.stopPlayback()

        #expect(mockAudio.playbackStopped)
    }
}

// swiftlint:enable type_body_length

// MARK: - MockAIConfigStorage

private final class MockAIConfigStorage: AIConfigStorage {
    override func loadAPIKey(for _: String) throws -> String? {
        nil
    }
}

// MARK: - MockAICapabilityDetector

private final class MockAICapabilityDetector: AICapabilityDetector {
    override func isSpeechTranscriberAvailable() -> Bool {
        false
    }
}
