//
//  MutuallyExclusiveTaskTests.swift
//  AsyncTaskKitTests
//
//  Created by Michal Zaborowski on 2022-01-02.
//

import XCTest
@testable import AsyncTaskKit

internal class MutuallyExclusiveTaskTests: XCTestCase {

    private var values: [String] = []

    override func setUp() {
        super.setUp()
        values = []
    }

    internal func testSimpleMutuallyExlusiveGenericCondition() throws {
        let task = DelayTask(task: JustTask("1"), delay: 0.05).mutuallyExclusive()
        let task2 = DelayTask(task: JustTask("2"), delay: 0.01).mutuallyExclusive()

        let expectation = self.expectation(description: "Should fullfill")
        expectation.expectedFulfillmentCount = 2

        Task {
            let value = try await task.run()
            values.append(value)
            expectation.fulfill()
        }

        Task {
            let value = try await task2.run()
            values.append(value)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.1)
        XCTAssertEqual(values, ["1", "2"])
    }

    internal func testSimpleMutuallyExlusive() async throws {

        let identifier = UUID().uuidString


        let task = JustTask("1")
        let task1 = JustTask("2").delay(0.1)
        let task2 = JustTask("3")

        async let mutually = MutuallyExclusiveTask(task: task, identifier: identifier)
        async let mutually1 = MutuallyExclusiveTask(task: task1, identifier: identifier)
        async let mutually2 = MutuallyExclusiveTask(task: task2, identifier: identifier)

        let values = [try await mutually.run(), try await mutually1.run(), try await mutually2.run()]
        XCTAssertEqual(values, ["1", "2", "3"])
    }

    internal func testShouldWaitUntilFirstTaskFinish() throws {
        let identifier = UUID().uuidString

        let expectation = self.expectation(description: "Should fullfil")
        expectation.expectedFulfillmentCount = 3

        Task {
            let value = try await JustTask("1")
                .delay(0.1)
                .mutuallyExclusive(with: identifier)
                .run()
            values.append(value)
            expectation.fulfill()
        }

        Task {
            let value = try await JustTask("2")
                .mutuallyExclusive(with: identifier)
                .run()
            values.append(value)
            expectation.fulfill()
        }

        Task.detached {
            let value = try await JustTask("3")
                .mutuallyExclusive(with: identifier)
                .run()
            self.values.append(value)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
        XCTAssertEqual(values, ["1", "2", "3"])
    }

    internal func testCancelShouldUnlockOtherTasks() {
        let identifier = UUID().uuidString

        let expectation = self.expectation(description: "Should fullfil")
        expectation.expectedFulfillmentCount = 2

        Task {
            let value = try await DelayTask(task: JustTask("1"), delay: 0.2)
                .mutuallyExclusive(with: identifier)
                .run()
            values.append(value)
            expectation.fulfill()
        }

        let cancellationTask = Task {
            let value = try await DelayTask(task: JustTask("2"), delay: 0.1)
                .mutuallyExclusive(with: identifier)
                .run()
            values.append(value)
        }

        Task {
            await cancellationTask.result
        }

        Task {
            await Task.sleep(seconds: 0.01)
            cancellationTask.cancel()
        }

        Task {
            let value = try await JustTask("3")
                .mutuallyExclusive(with: identifier)
                .run()
            self.values.append(value)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(values, ["1", "3"])
    }
}

