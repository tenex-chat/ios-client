//
// BranchColorTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
@testable import TENEXFeatures
import Testing

struct BranchColorTests {
    @Test("Generates deterministic colors for branch names")
    func deterministicColors() {
        let branchName = "feature/add-authentication"
        let color1 = BranchColor.color(for: branchName)
        let color2 = BranchColor.color(for: branchName)

        // Same branch name should produce same color
        #expect(color1 == color2)
    }

    @Test("Handles long branch names without overflow")
    func longBranchNames() {
        // Long branch name that could cause overflow with standard arithmetic
        let longBranch = String(repeating: "very-long-branch-name-", count: 100)

        // Should not crash
        let color = BranchColor.color(for: longBranch)

        // Should produce a valid color
        #expect(color != nil)
    }

    @Test("Handles Unicode characters")
    func unicodeCharacters() {
        let branchNames = [
            "feature/добавить-аутентификацию", // Cyrillic
            "feature/認証を追加", // Japanese
            "feature/添加身份验证", // Chinese
            "feature/émojis-🚀-✨", // Emojis
        ]

        for branch in branchNames {
            // Should not crash and should produce valid colors
            let color = BranchColor.color(for: branch)
            #expect(color != nil)
        }
    }

    @Test("Handles empty string")
    func emptyString() {
        let color = BranchColor.color(for: "")
        #expect(color != nil)
    }

    @Test("Different branches produce different colors")
    func differentColors() {
        let branch1 = "feature/login"
        let branch2 = "feature/signup"

        let color1 = BranchColor.color(for: branch1)
        let color2 = BranchColor.color(for: branch2)

        // Different branch names should (likely) produce different colors
        // Note: Hash collisions are possible, but unlikely for these inputs
        #expect(color1 != color2)
    }
}
