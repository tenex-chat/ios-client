//
//  SpeechRecognizer.swift
//  TENEX
//
//  Created by Jules on 2024.
//

import Speech
import AVFoundation

public enum SpeechRecognizerError: Error {
    case permissionDenied
    case deviceNotSupported
    case recognitionFailed
    case audioSessionFailed
}

public protocol SpeechRecognizerDelegate: AnyObject {
    func speechRecognizer(_ recognizer: SpeechRecognizer, didRecognizeText text: String, isFinal: Bool)
    func speechRecognizer(_ recognizer: SpeechRecognizer, didFailWithError error: Error)
    func speechRecognizerDidDetectVoice(_ recognizer: SpeechRecognizer)
    func speechRecognizerDidStopRecording(_ recognizer: SpeechRecognizer)
}

public class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {

    public weak var delegate: SpeechRecognizerDelegate?

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public var isRecording: Bool {
        return audioEngine.isRunning
    }

    public override init() {
        // Default to user's locale
        self.speechRecognizer = SFSpeechRecognizer()
        super.init()
        self.speechRecognizer?.delegate = self
    }

    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    public func startRecording() throws {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognizerError.deviceNotSupported
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        let inputNode = audioEngine.inputNode

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognizerError.recognitionFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        // Keep speech recognition data on device for privacy if possible (iOS 13+)
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                self.delegate?.speechRecognizer(self, didRecognizeText: result.bestTranscription.formattedString, isFinal: result.isFinal)
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                if let error = error {
                     self.delegate?.speechRecognizer(self, didFailWithError: error)
                } else {
                    self.delegate?.speechRecognizerDidStopRecording(self)
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        delegate?.speechRecognizerDidDetectVoice(self)
    }

    public func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
}
