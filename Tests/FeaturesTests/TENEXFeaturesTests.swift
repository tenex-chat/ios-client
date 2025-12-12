//
// TENEXFeaturesTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXFeatures
import Testing

@Suite("TENEXFeatures Module Tests")
struct TENEXFeaturesTests {
    @Test("Module version is defined")
    func moduleVersionIsDefined() {
        #expect(TENEXFeatures.version == "0.1.0")
    }
}
