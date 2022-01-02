//
//  JustTask.swift
//  GenevaCoreTestsKit
//
//  Created by Michal Zaborowski on 2022-01-02.
//  Copyright © 2022 Geneva Technologies, Inc. All rights reserved.
//

import Foundation

// MARK: - JustTask

public struct JustTask<T>: TaskRunnable {

    // MARK: JustTask (Private Properties)

    private let task: Task<T, Error>

    // MARK: JustTask (Public Properties)

    public init(_ value: T) {
        self.init(block: {
            return value
        })
    }

    public init(block: @Sendable @escaping () async throws -> T) {
        self.task = Task {
            try await block()
        }
    }

    public func cancel() async {
        task.cancel()
    }

    public func run() async throws -> T {
        try await task.value
    }
}
