//
//  SpeechRecognizerProtocol.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import Foundation

public enum SpeechRecognizerError: Error {
    case permissionDenied
    case deviceNotSupported
    case recognitionFailed
    case audioSessionFailed
}

public protocol SpeechRecognizerProtocol: AnyObject {
    var delegate: SpeechRecognizerDelegate? { get set }
    var isRecording: Bool { get }

    func requestAuthorization() async -> Bool
    func startRecording() async throws
    func stopRecording()
}

// Re-export delegate for compatibility
public protocol SpeechRecognizerDelegate: AnyObject {
    func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didRecognizeText text: String, isFinal: Bool)
    func speechRecognizer(_ recognizer: SpeechRecognizerProtocol, didFailWithError error: Error)
    func speechRecognizerDidDetectVoice(_ recognizer: SpeechRecognizerProtocol)
    func speechRecognizerDidStopRecording(_ recognizer: SpeechRecognizerProtocol)
}
