//
//  TENEXCoreTests.swift
//  TENEX
//

import Testing
@testable import TENEXCore

@Suite("TENEXCore Module Tests")
struct TENEXCoreTests {

    @Test("Module version is defined")
    func moduleVersionIsDefined() {
        #expect(TENEXCore.version == "0.1.0")
    }
}
