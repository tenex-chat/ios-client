//
//  TTSManager.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import AVFoundation
import Foundation

public protocol TTSManagerProtocol: AnyObject {
    var isSpeaking: Bool { get }
    func speak(_ text: String)
    func stop()
    func setVoice(language: String)
}

public final class TTSManager: NSObject, TTSManagerProtocol {
    private let synthesizer: AVSpeechSynthesizer
    private var voice: AVSpeechSynthesisVoice?

    public var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    public override init() {
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        self.synthesizer.delegate = self
        // Default voice
        self.voice = AVSpeechSynthesisVoice(language: "en-US")
    }

    public func speak(_ text: String) {
        // Stop any current speech immediately
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        // Ensure audio session is active
        configureAudioSession()

        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    public func setVoice(language: String) {
        self.voice = AVSpeechSynthesisVoice(language: language)
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session for TTS: \(error)")
        }
    }
}

extension TTSManager: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Handle completion if needed
        // For now, we can deactivate the audio session if we want to be good citizens,
        // but often in voice mode we want to keep it active.
    }
}
