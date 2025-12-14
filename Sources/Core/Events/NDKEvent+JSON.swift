//
// NDKEvent+JSON.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore

public extension NDKEvent {
    /// Converts the event to a pretty-printed JSON string
    /// - Returns: A formatted JSON string representation of the event, or nil if serialization fails
    var asJSON: String? {
        let eventDict: [String: Any] = [
            "id": id,
            "pubkey": pubkey,
            "created_at": createdAt,
            "kind": kind,
            "content": content,
            "sig": sig,
            "tags": tags.map { Array($0) },
        ]

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: eventDict,
            options: .prettyPrinted
        ),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return nil
        }

        return jsonString
    }
}
