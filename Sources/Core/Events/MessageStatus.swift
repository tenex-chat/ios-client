//
// MessageStatus.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

/// Status of a message in the chat
public enum MessageStatus: Sendable, Equatable {
    /// Message is being sent to the relay
    case sending

    /// Message has been successfully published
    case sent

    /// Message failed to send
    case failed(error: String)

    // MARK: Public

    // MARK: Equatable

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.sending, .sending):
            true
        case (.sent, .sent):
            true
        case let (.failed(lhsError), .failed(rhsError)):
            lhsError == rhsError
        default:
            false
        }
    }
}
