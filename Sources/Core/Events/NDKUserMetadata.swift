//
// NDKUserMetadata.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

/// Represents User Metadata (Nostr kind: 0)
public struct NDKUserMetadata: Sendable {
    // MARK: Lifecycle

    public init?(from event: NDKEvent) {
        guard event.kind == 0 else { return nil }
        self.event = event

        guard let data = event.content.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        self.name = dict["name"] as? String
        self.displayName = dict["display_name"] as? String
        self.about = dict["about"] as? String
        self.picture = dict["picture"] as? String
        self.nip05 = dict["nip05"] as? String
        self.lud16 = dict["lud16"] as? String
        self.website = dict["website"] as? String

        // Custom agent fields in metadata
        self.role = dict["role"] as? String
        self.instructions = dict["instructions"] as? String ?? dict["systemPrompt"] as? String
        self.useCriteria = dict["useCriteria"] as? [String] ?? []
    }

    // MARK: Public

    public let event: NDKEvent

    public let name: String?
    public let displayName: String?
    public let about: String?
    public let picture: String?
    public let nip05: String?
    public let lud16: String?
    public let website: String?

    // Agent-specific fields that might be in metadata
    public let role: String?
    public let instructions: String?
    public let useCriteria: [String]
}
