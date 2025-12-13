//
//  SpeechRecognizerFactory.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import Foundation

public enum SpeechRecognizerFactory {
    public static func make() -> SpeechRecognizerProtocol {
        // "iOS 26" logic (Simulated check)
        // In reality, we check ProcessInfo or #available
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        if majorVersion >= 26 {
             // Return SpeechAnalyzerWrapper() when implemented/available
             return SFSpeechRecognizerWrapper() // Fallback/Simulator
        } else {
             // Use WhisperKit for older devices if configured, or SFSpeechRecognizer
             // The plan said "WhisperKit fallback for older devices"
             // But for now, SFSpeechRecognizer is more stable without model downloads
             return SFSpeechRecognizerWrapper()

             // Uncomment when WhisperKit is fully configured with model bundle
             // return WhisperKitWrapper()
        }
    }
}
