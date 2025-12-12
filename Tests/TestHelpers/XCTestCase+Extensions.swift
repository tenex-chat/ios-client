//
// XCTestCase+Extensions.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import XCTest

extension XCTestCase {
    /// A helper to create mock objects.
    func mock<T>() -> T? {
        // In the future, this could use a library like Cuckoo or Mockingbird.
        nil
    }

    /// A helper to easily manage asynchronous expectations.
    func expect(description: String, block: (XCTestExpectation) -> Void) {
        let expectation = expectation(description: description)
        block(expectation)
        waitForExpectations(timeout: 10, handler: nil)
    }
}
