//
//  MutuallyExclusiveTask.swift
//  GenevaCore
//
//  Created by Michal Zaborowski on 2022-01-02.
//  Copyright © 2022 Geneva Technologies, Inc. All rights reserved.
//

import Foundation

// MARK: - MutuallyExclusiveTask

public struct MutuallyExclusiveTask<T: TaskRunnable>: TaskRunnable {

    // MARK: MutuallyExclusiveTask (Public Properties)

    public let identifier: String

    // MARK: MutuallyExclusiveTask (Private Properties)

    private var prepareTask: Task<Void, Error>?

    private let inner: Inner<T>

    // MARK: MutuallyExclusiveTask (Public Methods)

    public init(task: T, identifier: String? = nil) {
        self.init(task: task, identifier: identifier, controller: ExclusivityTaskController.shared)
    }

    internal init(task: T,
                  identifier: String?,
                  controller: ExclusivityTaskController) {
        let identifier = identifier ?? String(describing: T.self)
        self.inner = Inner(task: task, identifier: identifier, controller: controller)
        self.identifier = identifier
    }

    public func cancel() async {
        await inner.cancel()
    }

    public func run() async throws -> T.Output {
        try await inner.run()
    }
}

// MARK: MutuallyExclusiveTask > Inner

extension MutuallyExclusiveTask {
    private actor Inner<T: TaskRunnable>: TaskRunnable {

        // MARK: Inner (Public Properties)

        public let identifier: String

        // MARK: Inner (Private Properties)

        private var prepareTask: Task<Void, Error>?

        private let internalTask: T

        private weak var controller: ExclusivityTaskController?

        internal init(task: T,
                      identifier: String,
                      controller: ExclusivityTaskController) {
            self.internalTask = task
            self.identifier = identifier
            self.controller = controller
        }

        public func cancel() async {
            prepareTask?.cancel()
            await internalTask.cancel()
            await controller?.remove(task: self, identifier: identifier)
        }

        public func run() async throws -> T.Output {
            prepareTask = Task<Void, Error> { [weak self] in
                guard let self = self else { return }
                await self.controller?.prepare(task: self, identifier: identifier)
            }

            do {
                _ = try await prepareTask?.value

                try Task.checkCancellation()

                let result = try await internalTask.run()
                await controller?.remove(task: self, identifier: identifier)
                return result
            } catch {
                await controller?.remove(task: self, identifier: identifier)
                throw error
            }
        }
    }
}

// MARK: - MutuallyExclusiveTask > TaskRunnable

extension TaskRunnable {
    public func mutuallyExclusive(with identifier: String? = nil) -> MutuallyExclusiveTask<Self> {
        MutuallyExclusiveTask(task: self, identifier: identifier)
    }
}

// MARK: - ExclusivityTaskController > ExclusivityTask

extension ExclusivityTaskController {
    private class ExclusivityTask {
        public let task: AnyObject
        public let waitingTask: Task<Void, Never>

        public init<T: TaskRunnable>(task: T, waitingTask: Task<Void, Never>) {
            self.task = task as AnyObject
            self.waitingTask = waitingTask
        }
    }
}

// MARK: - ExclusivityTaskController

internal actor ExclusivityTaskController {

    // MARK: ExclusivityTaskController (Private Properties)

    fileprivate static let shared = ExclusivityTaskController()

    private var tasks: [String: [ExclusivityTaskController.ExclusivityTask]] = [:]

    // MARK: ExclusivityTaskController (Internal Methods)

    internal func prepare<T: TaskRunnable & AnyObject>(task newTask: T, identifier: String) async {
        guard let task = tasks[identifier]?.last else {
            add(task: newTask, identifier: identifier)
            return
        }
        assert(task.task !== newTask, "Trying prepare same task twice!")

        guard task.task !== newTask else {
            return
        }
        add(task: newTask, identifier: identifier)
        _ = await task.waitingTask.result
    }

    internal func remove<T: TaskRunnable & AnyObject>(task: T, identifier: String) {
        guard let taskIndex = tasks[identifier]?.firstIndex(where: { $0.task === task }) else {
            return
        }
        guard let internalTask = tasks[identifier]?[taskIndex] else {
            return
        }
        internalTask.waitingTask.cancel()
        tasks[identifier]?.remove(at: taskIndex)
    }

    // MARK: ExclusivityTaskController (Private Methods)

    private func add<T: TaskRunnable & AnyObject>(task: T, identifier: String) {
        let waitingTask = Task<Void, Never> { [weak self] in
            while await self?.tasks[identifier]?.contains(where: { $0.task === task }) ?? false {
                await Task.sleep(seconds: 10)
            }
        }
        let exclusivityTask = ExclusivityTaskController.ExclusivityTask(task: task, waitingTask: waitingTask)
        var tasks = tasks[identifier, default: []]
        tasks.append(exclusivityTask)
        self.tasks[identifier] = tasks
    }
}
