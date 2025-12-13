//
//  VoiceModeViewModelTests.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import Testing
@testable import TENEXFeatures
@testable import TENEXCore

// Mock for TTSManager
class MockTTSManager: TTSManagerProtocol {
    var isSpeaking: Bool = false
    var lastSpokenText: String?

    func speak(_ text: String) {
        isSpeaking = true
        lastSpokenText = text
    }

    func stop() {
        isSpeaking = false
    }

    func setVoice(language: String) {}
}

// Mock for SpeechRecognizer
class MockSpeechRecognizer: SpeechRecognizer {
    var mockIsRecording = false
    override var isRecording: Bool {
        return mockIsRecording
    }

    override func requestAuthorization() async -> Bool {
        return true
    }

    override func startRecording() throws {
        mockIsRecording = true
    }

    override func stopRecording() {
        mockIsRecording = false
    }
}

@Suite struct VoiceModeViewModelTests {

    @Test func testInitialState() {
        let viewModel = VoiceModeViewModel(
            speechRecognizer: MockSpeechRecognizer(),
            ttsManager: MockTTSManager()
        )
        #expect(viewModel.state == .idle)
        #expect(viewModel.transcription.isEmpty)
    }

    @Test func testStartListening() {
        let mockRecognizer = MockSpeechRecognizer()
        let viewModel = VoiceModeViewModel(
            speechRecognizer: mockRecognizer,
            ttsManager: MockTTSManager()
        )

        // We can't easily test the async startSession -> startListening flow in synchronous test without Task handling
        // But we can test toggleListening

        viewModel.toggleListening()

        #expect(mockRecognizer.isRecording == true)
        // State update happens async or directly? In implementation it's inside startListening which is called by toggleListening.
        // But startListening calls recognizer.startRecording() which is mocked.
        // Wait, startListening sets state = .listening
        #expect(viewModel.state == .listening)
    }

    @Test func testStopListening() {
        let mockRecognizer = MockSpeechRecognizer()
        let viewModel = VoiceModeViewModel(
            speechRecognizer: mockRecognizer,
            ttsManager: MockTTSManager()
        )

        // Manually set to recording
        viewModel.toggleListening()
        #expect(viewModel.state == .listening)

        viewModel.toggleListening()
        #expect(mockRecognizer.isRecording == false)
        // State should go to idle if transcription is empty
        #expect(viewModel.state == .idle)
    }
}
