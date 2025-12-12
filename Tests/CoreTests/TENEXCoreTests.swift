//
// TENEXCoreTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

@testable import TENEXCore
import Testing

@Suite("TENEXCore Module Tests")
struct TENEXCoreTests {
    @Test("Module version is defined")
    func moduleVersionIsDefined() {
        #expect(TENEXCore.version == "0.1.0")
    }
}
