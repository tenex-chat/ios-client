//
// HapticManager.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

#if canImport(UIKit)
    import UIKit

    @MainActor
    final class HapticManager {
        // MARK: Lifecycle

        init() {
            self.prepare()
        }

        // MARK: Internal

        func vadSpeechDetected() {
            self.lightImpact.impactOccurred(intensity: 0.5)
        }

        func recordingStarted() {
            self.mediumImpact.impactOccurred()
        }

        func recordingStopped() {
            self.lightImpact.impactOccurred(intensity: 0.6)
        }

        func tapHoldBegan() {
            self.softImpact.impactOccurred(intensity: 0.4)
        }

        func tapHoldReleased() {
            self.lightImpact.impactOccurred(intensity: 0.5)
        }

        func messageSent() {
            self.notification.notificationOccurred(.success)
        }

        func error() {
            self.notification.notificationOccurred(.error)
        }

        func ttsStarted() {
            self.selection.selectionChanged()
        }

        func ttsInterrupted() {
            self.lightImpact.impactOccurred(intensity: 0.4)
        }

        func settingsToggle() {
            self.selection.selectionChanged()
        }

        // MARK: Private

        private let lightImpact = UIImpactFeedbackGenerator(style: .light)
        private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
        private let softImpact = UIImpactFeedbackGenerator(style: .soft)
        private let notification = UINotificationFeedbackGenerator()
        private let selection = UISelectionFeedbackGenerator()

        private func prepare() {
            self.lightImpact.prepare()
            self.mediumImpact.prepare()
            self.softImpact.prepare()
            self.notification.prepare()
        }
    }
#endif
