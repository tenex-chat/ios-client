//
// FormattingUtilitiesTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXShared
import Testing

@Suite("Formatting Utilities Tests")
struct FormattingUtilitiesTests {
    // MARK: - Duration Formatting Tests

    @Test("Format microseconds correctly")
    func formatMicroseconds() {
        #expect(FormattingUtilities.formatDuration(0.000001) == "1μs")
        #expect(FormattingUtilities.formatDuration(0.000500) == "500μs")
        #expect(FormattingUtilities.formatDuration(0.000999) == "999μs")
    }

    @Test("Format milliseconds correctly")
    func formatMilliseconds() {
        #expect(FormattingUtilities.formatDuration(0.001) == "1ms")
        #expect(FormattingUtilities.formatDuration(0.050) == "50ms")
        #expect(FormattingUtilities.formatDuration(0.999) == "999ms")
    }

    @Test("Format seconds correctly")
    func formatSeconds() {
        #expect(FormattingUtilities.formatDuration(1.0) == "1.0s")
        #expect(FormattingUtilities.formatDuration(1.5) == "1.5s")
        #expect(FormattingUtilities.formatDuration(45.7) == "45.7s")
        #expect(FormattingUtilities.formatDuration(59.9) == "59.9s")
    }

    @Test("Format minutes and seconds correctly")
    func formatMinutesAndSeconds() {
        #expect(FormattingUtilities.formatDuration(60) == "1m 0s")
        #expect(FormattingUtilities.formatDuration(90) == "1m 30s")
        #expect(FormattingUtilities.formatDuration(150) == "2m 30s")
        #expect(FormattingUtilities.formatDuration(3599) == "59m 59s")
    }

    @Test("Format hours and minutes correctly")
    func formatHoursAndMinutes() {
        #expect(FormattingUtilities.formatDuration(3600) == "1h 0m")
        #expect(FormattingUtilities.formatDuration(3720) == "1h 2m")
        #expect(FormattingUtilities.formatDuration(7380) == "2h 3m")
        #expect(FormattingUtilities.formatDuration(86_400) == "24h 0m")
    }

    @Test("Format zero duration")
    func formatZeroDuration() {
        #expect(FormattingUtilities.formatDuration(0) == "0μs")
    }

    // MARK: - Percentage Formatting Tests

    @Test("Format percentages correctly")
    func formatPercentages() {
        #expect(FormattingUtilities.formatPercentage(0.0) == "0.0%")
        #expect(FormattingUtilities.formatPercentage(0.5) == "50.0%")
        #expect(FormattingUtilities.formatPercentage(0.856) == "85.6%")
        #expect(FormattingUtilities.formatPercentage(1.0) == "100.0%")
    }

    @Test("Format small percentages")
    func formatSmallPercentages() {
        #expect(FormattingUtilities.formatPercentage(0.001) == "0.1%")
        #expect(FormattingUtilities.formatPercentage(0.0001) == "0.0%")
    }

    @Test("Format percentages over 100%")
    func formatPercentagesOver100() {
        #expect(FormattingUtilities.formatPercentage(1.5) == "150.0%")
        #expect(FormattingUtilities.formatPercentage(2.0) == "200.0%")
    }

    // MARK: - Count Formatting Tests

    @Test("Format small numbers without suffix")
    func formatSmallNumbers() {
        #expect(FormattingUtilities.formatCount(0) == "0")
        #expect(FormattingUtilities.formatCount(1) == "1")
        #expect(FormattingUtilities.formatCount(500) == "500")
        #expect(FormattingUtilities.formatCount(999) == "999")
    }

    @Test("Format thousands with K suffix")
    func formatThousands() {
        #expect(FormattingUtilities.formatCount(1000) == "1.0K")
        #expect(FormattingUtilities.formatCount(1500) == "1.5K")
        #expect(FormattingUtilities.formatCount(10_000) == "10.0K")
        #expect(FormattingUtilities.formatCount(999_999) == "1000.0K")
    }

    @Test("Format millions with M suffix")
    func formatMillions() {
        #expect(FormattingUtilities.formatCount(1_000_000) == "1.0M")
        #expect(FormattingUtilities.formatCount(1_500_000) == "1.5M")
        #expect(FormattingUtilities.formatCount(10_000_000) == "10.0M")
        #expect(FormattingUtilities.formatCount(999_999_999) == "1000.0M")
    }

    @Test("Format billions with B suffix")
    func formatBillions() {
        #expect(FormattingUtilities.formatCount(1_000_000_000) == "1.0B")
        #expect(FormattingUtilities.formatCount(2_500_000_000) == "2.5B")
        #expect(FormattingUtilities.formatCount(10_000_000_000) == "10.0B")
    }

    @Test("Format edge case numbers")
    func formatEdgeCases() {
        #expect(FormattingUtilities.formatCount(1001) == "1.0K")
        #expect(FormattingUtilities.formatCount(1_000_001) == "1.0M")
        #expect(FormattingUtilities.formatCount(1_000_000_001) == "1.0B")
    }
}
