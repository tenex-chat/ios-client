//
//  SpeechRecognizerTests.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import Speech
import Testing
@testable import TENEXCore

@Suite struct SpeechRecognizerTests {

    @Test func testInitialization() {
        let recognizer = SpeechRecognizer()
        #expect(recognizer.isRecording == false)
    }

    // Similar to TTS, SFSpeechRecognizer is hard to test in unit tests without extensive mocking.
    // We would need to mock SFSpeechRecognizer, SFSpeechAudioBufferRecognitionRequest, and AVAudioEngine.
    // Given the constraints and the goal to implement the feature, I will focus on the logic structure.

}
