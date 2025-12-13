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
class MockSpeechRecognizer: SpeechRecognizerProtocol {
    var delegate: SpeechRecognizerDelegate?
    var mockIsRecording = false
    var isRecording: Bool {
        return mockIsRecording
    }

    func requestAuthorization() async -> Bool {
        return true
    }

    func startRecording() async throws {
        mockIsRecording = true
    }

    func stopRecording() {
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

    @Test func testStartListening() async {
        let mockRecognizer = MockSpeechRecognizer()
        let viewModel = VoiceModeViewModel(
            speechRecognizer: mockRecognizer,
            ttsManager: MockTTSManager()
        )

        // Use await to allow Task to complete
        viewModel.toggleListening()

        // Allow brief time for Task to execute
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(mockRecognizer.isRecording == true)
        #expect(viewModel.state == .listening)
    }

    @Test func testStopListening() async {
        let mockRecognizer = MockSpeechRecognizer()
        let viewModel = VoiceModeViewModel(
            speechRecognizer: mockRecognizer,
            ttsManager: MockTTSManager()
        )

        // Start
        viewModel.toggleListening()
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(viewModel.state == .listening)

        // Stop
        viewModel.toggleListening()
        // No async op for stop usually, but let's yield just in case
        try? await Task.sleep(nanoseconds: 10_000_000)

        #expect(mockRecognizer.isRecording == false)
        #expect(viewModel.state == .idle)
    }
}
