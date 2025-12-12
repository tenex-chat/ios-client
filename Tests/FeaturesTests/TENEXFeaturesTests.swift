//
//  TENEXFeaturesTests.swift
//  TENEX
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
