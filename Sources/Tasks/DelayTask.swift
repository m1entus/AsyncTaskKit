//
//  DelayTask.swift
//  GenevaCoreTestsKit
//
//  Created by Michal Zaborowski on 2022-01-02.
//  Copyright © 2022 Geneva Technologies, Inc. All rights reserved.
//

import Foundation

public struct DelayTask<T: TaskRunnable>: TaskRunnable {

    private let internalTask: T
    private let delayTask: Task<Void, Error>

    public init(task: T, delay: TimeInterval) {
        self.internalTask = task
        self.delayTask = Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    public func cancel() async {
        delayTask.cancel()
    }

    public func run() async throws -> T.Output {
        _ = try await delayTask.value
        return try await internalTask.run()
    }
}

// MARK: - DelayTask > TaskRunnable

extension TaskRunnable {
    public func delay(_ interval: TimeInterval) -> DelayTask<Self> {
        DelayTask(task: self, delay: interval)
    }
}
