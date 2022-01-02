//
//  ConditionEvaluatingTaskTests.swift
//  AsyncTaskKitTests
//
//  Created by Michal Zaborowski on 2022-01-02.
//

import XCTest
import Foundation
@testable import AsyncTaskKit

private struct BlockCondition: ConditionEvaluating {

    private let condition: @Sendable () async throws -> Void

    public init(condition: @escaping @Sendable () async throws -> Void) {
        self.condition = condition
    }

    func evaluate() async throws {
        try await condition()
    }
}

private enum TestError: Error {
    case sample
}

internal class ConditionEvaluatingTaskTests: XCTestCase {

    internal func testShouldEvaluateSingleCondition() async throws {
        let exp = expectation(description: "Should fulfill condition")

        let condition = BlockCondition {
            exp.fulfill()
        }

        let value = try await JustTask("1").conditions([condition]).run()

        wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(value, "1")
    }

    internal func testShouldEvaluateMultipleCondition() async throws {
        let exp = expectation(description: "Should fulfill condition")
        exp.expectedFulfillmentCount = 2

        let condition = BlockCondition {
            exp.fulfill()
        }

        let condition2 = BlockCondition {
            exp.fulfill()
        }

        let value = try await JustTask("1").conditions([condition, condition2]).run()

        wait(for: [exp], timeout: 0.2)
        XCTAssertEqual(value, "1")
    }

    internal func testShouldThrowErrorAndNotEvaluateTask() async {

        let condition = BlockCondition {
            throw TestError.sample
        }

        do {
            _ = try await JustTask("1").conditions([condition]).run()
            XCTFail()
        } catch {
            switch error as? TestError {
            case .sample:
                break
            default:
                XCTFail()
            }
        }
    }
}
