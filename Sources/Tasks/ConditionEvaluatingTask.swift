//
//  ConditionEvaluatingTask.swift
//  GenevaCore
//
//  Created by Michal Zaborowski on 2022-01-02.
//  Copyright © 2022 Geneva Technologies, Inc. All rights reserved.
//

import Foundation

// MARK: - ConditionEvaluating

public protocol ConditionEvaluating {
    func evaluate() async throws
}

// MARK: - ConditionEvaluatingTask

public struct ConditionEvaluatingTask<T: TaskRunnable>: TaskRunnable {

    // MARK: ConditionEvaluatingTask (Private Properties)

    private let conditions: [ConditionEvaluating]

    private let conditionEvaluatingTask: Task<Void, Error>

    private let internalTask: T

    // MARK: ConditionEvaluatingTask (Public Methods)

    public init(task: T, conditions: [ConditionEvaluating]) {
        self.internalTask = task
        self.conditions = conditions
        self.conditionEvaluatingTask = Task {
            try await withThrowingTaskGroup(of: Void.self, body: { group in
                for condition in conditions {
                    group.addTask {
                        try await condition.evaluate()
                    }
                }
                try await group.waitForAll()
            })
        }
    }

    public func cancel() async {
        conditionEvaluatingTask.cancel()
        await internalTask.cancel()
    }

    public func run() async throws -> T.Output {
        _ = try await conditionEvaluatingTask.value
        return try await internalTask.run()
    }
}

// MARK: - ConditionEvaluatingTask > TaskRunnable

extension TaskRunnable {
    public func conditions(_ conditions: [ConditionEvaluating]) -> ConditionEvaluatingTask<Self> {
        ConditionEvaluatingTask(task: self, conditions: conditions)
    }
}
