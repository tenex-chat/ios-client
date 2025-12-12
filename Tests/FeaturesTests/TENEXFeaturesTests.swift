//
//  TENEXFeaturesTests.swift
//  TENEX
//

import Testing
@testable import TENEXFeatures

@Suite("TENEXFeatures Module Tests")
struct TENEXFeaturesTests {

    @Test("Module version is defined")
    func moduleVersionIsDefined() {
        #expect(TENEXFeatures.version == "0.1.0")
    }
}
