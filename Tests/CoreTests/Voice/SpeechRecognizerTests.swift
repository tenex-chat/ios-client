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
        let recognizer = SFSpeechRecognizerWrapper()
        #expect(recognizer.isRecording == false)
    }

    @Test func testFactory() {
        let recognizer = SpeechRecognizerFactory.make()
        // Should return a valid instance
        #expect(recognizer.isRecording == false)
    }
}
