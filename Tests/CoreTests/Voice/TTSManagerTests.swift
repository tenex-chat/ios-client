//
//  TTSManagerTests.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import AVFoundation
import Testing
@testable import TENEXCore

@Suite struct TTSManagerTests {
    @Test func testInitialization() {
        let manager = TTSManager()
        #expect(manager.isSpeaking == false)
    }

    // Note: Testing actual audio output or AVSpeechSynthesizer internals is difficult in unit tests
    // without extensive mocking of AVFoundation which is not easily mockable.
    // We can verify the public API contract though.

    @Test func testVoiceConfiguration() {
        let manager = TTSManager()
        manager.setVoice(language: "es-ES")
        // In a real test we might expose the voice property internally to verify,
        // or mock the synthesizer. For now, we ensure no crash.
    }
}
